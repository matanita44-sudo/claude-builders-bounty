#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "usage: $0 COMPILED_DEBUG_APP OUTPUT_DIRECTORY" >&2
  exit 2
fi

app="$1"
output="$2"
bundle_id="com.matan.infinidive"
device_type_id="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max"
activation_token="ios-simulator-ci-v1"
ready_filename="native-store-capture-ready.json"
# Hosted iOS 26 Simulators can spend well over 30 seconds servicing a fresh
# install while the display/audio services finish first-boot work. The app
# marker is still a fail-closed state proof; this bound only prevents runner
# contention from being mistaken for a gameplay-state failure.
marker_timeout_seconds=120
stages=(
  nest
  titan-exterior
  breach-open
  organ-chamber
  mutation-choice
  post-organ-titan
)

: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"
: "${INFINIDIVE_XCODE_VERSION:?INFINIDIVE_XCODE_VERSION is required}"
: "${INFINIDIVE_SIMULATOR_SDK:?INFINIDIVE_SIMULATOR_SDK is required}"

if [[ ! -d "${app}" || "${app}" != *.app ]]; then
  echo "compiled Debug app is missing or not an .app directory: ${app}" >&2
  exit 1
fi
if [[ -e "${output}" ]]; then
  echo "refusing to overwrite capture output: ${output}" >&2
  exit 1
fi
mkdir -p "${output}"

runtimes_json="${output}/simulator-runtimes.json"
device_types_json="${output}/simulator-device-types.json"
xcrun simctl list runtimes --json > "${runtimes_json}"
xcrun simctl list devicetypes --json > "${device_types_json}"

runtime_id="$(python3 - "${runtimes_json}" <<'PY'
import json
import pathlib
import re
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
candidates = []
for runtime in data.get("runtimes", []):
    identifier = str(runtime.get("identifier", ""))
    version = str(runtime.get("version", ""))
    if runtime.get("isAvailable") is not True:
        continue
    if not identifier.startswith("com.apple.CoreSimulator.SimRuntime.iOS-26-"):
        continue
    if re.fullmatch(r"26(?:\.\d+)+", version) is None:
        continue
    candidates.append((tuple(int(part) for part in version.split(".")), identifier))
if not candidates:
    raise SystemExit("no available iOS 26.x Simulator runtime")
print(max(candidates)[1])
PY
)"

python3 - "${device_types_json}" "${device_type_id}" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
expected = sys.argv[2]
identifiers = {str(item.get("identifier", "")) for item in data.get("devicetypes", [])}
if expected not in identifiers:
    raise SystemExit(f"required Simulator device type is unavailable: {expected}")
PY

simulator_udid=""
capture_log_start=""
cleanup_simulator() {
  local exit_status="$?"
  if [[ -n "${simulator_udid}" ]]; then
    if [[ ! -s "${output}/simulator-app.log" ]]; then
      if [[ -n "${capture_log_start}" ]]; then
        xcrun simctl spawn "${simulator_udid}" log show \
          --style compact --start "${capture_log_start}" \
          --predicate 'process == "INFINIDIVE" OR senderImagePath CONTAINS "INFINIDIVE"' \
          > "${output}/simulator-app.log" 2>&1 || true
      else
        xcrun simctl spawn "${simulator_udid}" log show \
          --style compact --last 15m \
          --predicate 'process == "INFINIDIVE" OR senderImagePath CONTAINS "INFINIDIVE"' \
          > "${output}/simulator-app.log" 2>&1 || true
      fi
    fi
    xcrun simctl shutdown "${simulator_udid}" >/dev/null 2>&1 || true
    xcrun simctl delete "${simulator_udid}" >/dev/null 2>&1 || true
  fi
  return "${exit_status}"
}
trap cleanup_simulator EXIT

simulator_name="INFINIDIVE-STORE-QA-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
simulator_udid="$(
  xcrun simctl create "${simulator_name}" "${device_type_id}" "${runtime_id}"
)"
if [[ -z "${simulator_udid}" ]]; then
  echo "simctl did not return a Simulator UDID" >&2
  exit 1
fi
xcrun simctl boot "${simulator_udid}"
xcrun simctl bootstatus "${simulator_udid}" -b
xcrun simctl spawn "${simulator_udid}" defaults write NSGlobalDomain \
  AppleLanguages -array en
xcrun simctl spawn "${simulator_udid}" defaults write NSGlobalDomain \
  AppleLocale -string en_US
xcrun simctl shutdown "${simulator_udid}"
xcrun simctl boot "${simulator_udid}"
xcrun simctl bootstatus "${simulator_udid}" -b
capture_log_start="$(date '+%Y-%m-%d %H:%M:%S')"

launch_log="${output}/simulator-launches.txt"
: > "${launch_log}"
launched_pids=()

assert_bundle_install_state() {
  local expected_state="$1"
  local evidence_stem="$2"
  local listing="${output}/.${evidence_stem}-installed-apps.json"

  # `simctl listapps` has a stable plist contract across Xcode releases;
  # normalize it with macOS' bundled plutil instead of relying on a newer,
  # less-portable `--json` flag.
  xcrun simctl listapps "${simulator_udid}" \
    | plutil -convert json -o "${listing}" -- -
  python3 - "${listing}" "${bundle_id}" "${expected_state}" <<'PY'
import json
import pathlib
import sys

payload = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(payload, dict):
    raise SystemExit("simctl listapps returned a non-object payload")
installed = sys.argv[2] in payload
expected = sys.argv[3]
if expected not in {"present", "absent"}:
    raise SystemExit(f"invalid expected app state: {expected}")
if installed != (expected == "present"):
    raise SystemExit(
        f"bundle {sys.argv[2]} is {'present' if installed else 'absent'}; "
        f"expected {expected}"
    )
PY
  rm -f -- "${listing}"
}

for stage_index in "${!stages[@]}"; do
  stage="${stages[${stage_index}]}"
  stem="$(printf '%02d-%s' "${stage_index}" "${stage}")"

  # Reinstall for every canonical stage so gameplay saves, mutation discovery,
  # and the readiness marker cannot leak from an earlier capture.
  if (( stage_index == 0 )); then
    # This is a newly created Simulator. Prove the bundle is absent instead of
    # accepting an ambiguous uninstall failure.
    assert_bundle_install_state absent "${stem}-before-first-install"
  else
    # Every later stage must start from the app installed by the prior stage,
    # successfully remove it, and prove its data container registration is gone.
    assert_bundle_install_state present "${stem}-before-uninstall"
    xcrun simctl uninstall "${simulator_udid}" "${bundle_id}"
    assert_bundle_install_state absent "${stem}-after-uninstall"
  fi
  xcrun simctl install "${simulator_udid}" "${app}"
  data_container="$(
    xcrun simctl get_app_container "${simulator_udid}" "${bundle_id}" data
  )"
  if [[ -z "${data_container}" || ! -d "${data_container}" ]]; then
    echo "could not resolve the installed app data container" >&2
    exit 1
  fi

  launch_started="$(date +%s)"
  set +e
  launch_output="$(
    SIMCTL_CHILD_CI=true \
    SIMCTL_CHILD_INFINIDIVE_NATIVE_STORE_CAPTURE="${activation_token}" \
      xcrun simctl launch --terminate-running-process \
        "${simulator_udid}" "${bundle_id}" -- \
        "--infinidive-native-store-capture=${activation_token}" \
        "--infinidive-capture-stage=${stage}" 2>&1
  )"
  launch_status="$?"
  set -e
  {
    printf 'stage=%s status=%s\n' "${stage}" "${launch_status}"
    printf '%s\n' "${launch_output}"
  } >> "${launch_log}"
  if [[ "${launch_status}" -ne 0 ]]; then
    printf '%s\n' "${launch_output}" >&2
    exit "${launch_status}"
  fi
  stage_pid="$(printf '%s\n' "${launch_output}" | awk -F ': ' 'END { print $NF }')"
  case "${stage_pid}" in
    ''|*[!0-9]*)
      echo "Could not parse a numeric app PID for ${stage}: ${launch_output}" >&2
      exit 1
      ;;
  esac
  # macOS still ships Bash 3.2, where expanding an empty array under `set -u`
  # aborts. The numeric stage guard keeps the first expansion non-empty-safe.
  if (( stage_index > 0 )); then
    for existing_pid in "${launched_pids[@]}"; do
      if [[ "${existing_pid}" = "${stage_pid}" ]]; then
        echo "Simulator unexpectedly reused app PID ${stage_pid} across isolated stages" >&2
        exit 1
      fi
    done
  fi
  launched_pids+=("${stage_pid}")

  marker_wait_started="$(date +%s)"
  marker_path=""
  marker_listing="${output}/${stem}-marker-candidates.txt"
  while (( $(date +%s) - marker_wait_started < marker_timeout_seconds )); do
    find "${data_container}" -type f -name "${ready_filename}" -print \
      | sort > "${marker_listing}"
    marker_count="$(wc -l < "${marker_listing}" | tr -d '[:space:]')"
    marker_candidate="$(sed -n '1p' "${marker_listing}")"
    if [[ "${marker_count}" = "1" ]] && \
      python3 - "${marker_candidate}" "${stage}" "${stage_index}" "${stage_pid}" <<'PY'
import json
import pathlib
import sys

try:
    marker = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)
if marker.get("stage") != sys.argv[2] or marker.get("stage_index") != int(sys.argv[3]):
    raise SystemExit(1)
if marker.get("schema") != "infinidive.native-ios-store-capture.v1":
    raise SystemExit(1)
if marker.get("process_id") != int(sys.argv[4]):
    raise SystemExit(1)
PY
    then
      marker_path="${marker_candidate}"
      break
    fi
    sleep 1
  done
  if [[ -z "${marker_path}" ]]; then
    # Preserve bounded, explicitly diagnostic evidence for a genuine timeout;
    # these files are never accepted by the six-stage store-capture validator.
    timeout_screenshot="${output}/${stem}-marker-timeout-diagnostic.png"
    python3 -c \
      'import subprocess,sys; subprocess.run(["xcrun","simctl","io",sys.argv[1],"screenshot","--type=png",sys.argv[2]],check=False,timeout=45)' \
      "${simulator_udid}" "${timeout_screenshot}" || true
    sample "${stage_pid}" 5 \
      -file "${output}/${stem}-marker-timeout-process-sample.txt" || true
    echo "Debug app did not publish the ${stage} readiness marker within ${marker_timeout_seconds} seconds" >&2
    exit 1
  fi
  marker_ready_seconds="$(( $(date +%s) - marker_wait_started + 1 ))"
  printf 'stage=%s marker_ready_seconds_upper_bound=%s marker_timeout_seconds=%s\n' \
    "${stage}" "${marker_ready_seconds}" "${marker_timeout_seconds}" >> "${launch_log}"

  cp "${marker_path}" "${output}/${stem}.json"
  rm -f -- "${marker_listing}"
  # The app publishes readiness only after state-specific UI settles and all
  # gameplay/decorative clocks are frozen. One compositor turn avoids capturing
  # between the final Godot draw and CoreSimulator's display handoff.
  sleep 1
  raw_screenshot=""
  screenshot_captured=false
  for screenshot_attempt in 1 2; do
    screenshot_candidate="${output}/${stem}-simctl-rgba-attempt-${screenshot_attempt}.png"
    if python3 -c \
      'import subprocess,sys; subprocess.run(["xcrun","simctl","io",sys.argv[1],"screenshot","--type=png",sys.argv[2]],check=True,timeout=45)' \
      "${simulator_udid}" "${screenshot_candidate}"; then
      raw_screenshot="${screenshot_candidate}"
      screenshot_captured=true
      break
    fi
    printf 'stage=%s screenshot_attempt=%s transport_failed_or_timed_out=true\n' \
      "${stage}" "${screenshot_attempt}" >> "${launch_log}"
    rm -f -- "${screenshot_candidate}"
    sleep 1
  done
  if [[ "${screenshot_captured}" != true || -z "${raw_screenshot}" ]]; then
    echo "Simulator screenshot transport failed twice for ${stage}" >&2
    exit 1
  fi
  python3 .github/scripts/validate_ios_simulator_screenshot.py \
    "${raw_screenshot}" --normalize-rgb "${output}/${stem}.png"
  rm -f -- "${raw_screenshot}"
  xcrun simctl terminate "${simulator_udid}" "${bundle_id}"
done

# Give unified logging a bounded flush window after the final terminated stage.
sleep 2
xcrun simctl spawn "${simulator_udid}" log show \
  --style compact --start "${capture_log_start}" \
  --predicate 'process == "INFINIDIVE" OR senderImagePath CONTAINS "INFINIDIVE"' \
  > "${output}/simulator-app.log" 2>&1

python3 - \
  "${output}/capture-context.json" \
  "${GITHUB_SHA}" "${GITHUB_REPOSITORY}" \
  "${GITHUB_RUN_ID}" "${GITHUB_RUN_ATTEMPT}" \
  "${INFINIDIVE_XCODE_VERSION}" "${INFINIDIVE_SIMULATOR_SDK}" \
  "${runtime_id}" "${device_type_id}" <<'PY'
import json
import pathlib
import sys

context = {
    "schema": "infinidive.native-ios-store-capture-context.v1",
    "qa_only": True,
    "release_eligible": False,
    "source_commit": sys.argv[2],
    "source_repository": sys.argv[3],
    "run_id": int(sys.argv[4]),
    "run_attempt": int(sys.argv[5]),
    "xcode_configuration": "Debug",
    "xcode_version": sys.argv[6],
    "simulator_sdk_version": sys.argv[7],
    "runtime_identifier": sys.argv[8],
    "device_type_identifier": sys.argv[9],
    "bundle_identifier": "com.matan.infinidive",
    "code_signing_allowed": False,
    "capture_transport": "xcrun simctl io screenshot --type=png",
}
pathlib.Path(sys.argv[1]).write_text(
    json.dumps(context, indent=2, sort_keys=True) + "\n", encoding="utf-8"
)
PY

# Godot 4.7.2 asks iOS' touch-only DisplayServer for an initial mouse position
# once per process while wiring the root GUI. It returns Point2i() and gameplay
# continues; permit only that exact engine line, and never more than one for
# each isolated stage launch. Every other Error/Fault record fails closed;
# only exact, per-process-bounded Simulator platform noise is also permitted.
expected_pid_args=()
for stage_pid in "${launched_pids[@]}"; do
  expected_pid_args+=(--expected-pid "${stage_pid}")
done
python3 .github/scripts/validate_ios_simulator_log.py \
  "${output}/simulator-app.log" \
  --maximum-known-mouse-warnings "${#stages[@]}" \
  --maximum-known-mouse-warnings-per-process 1 \
  "${expected_pid_args[@]}"

# Write a top-level PASS report only after both image/state and app-log checks
# succeed, because the workflow deliberately uploads diagnostics on failure.
python3 .github/scripts/validate_ios_debug_store_capture.py "${output}" \
  --expected-commit "${GITHUB_SHA}" \
  --expected-repository "${GITHUB_REPOSITORY}" \
  --expected-run-id "${GITHUB_RUN_ID}" \
  --expected-run-attempt "${GITHUB_RUN_ATTEMPT}" \
  --xcode-version "${INFINIDIVE_XCODE_VERSION}" \
  --simulator-sdk-version "${INFINIDIVE_SIMULATOR_SDK}" \
  --write-report "${output}/qa-only-native-store-capture.json"

(
  cd "${output}"
  for evidence_file in *; do
    if [[ -f "${evidence_file}" && "${evidence_file}" != "SHA256SUMS" ]]; then
      shasum -a 256 "${evidence_file}"
    fi
  done
) | LC_ALL=C sort -k 2 > "${output}/SHA256SUMS"

echo "Native iOS Debug store-capture lane: PASS (six QA-only Simulator stages)"
