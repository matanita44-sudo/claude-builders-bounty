#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --suite SUITE_ID [--manifest PATH] -- GODOT [ARGS...]" >&2
  exit 2
}

suite_id=""
manifest_path=".github/scripts/test_suites.tsv"
while (($# > 0)); do
  case "$1" in
    --suite)
      (($# >= 2)) || usage
      suite_id="$2"
      shift 2
      ;;
    --manifest)
      (($# >= 2)) || usage
      manifest_path="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      usage
      ;;
  esac
done

[[ -n "${suite_id}" && $# -gt 0 ]] || usage
[[ -f "${manifest_path}" ]] || {
  echo "Test manifest not found: ${manifest_path}" >&2
  exit 2
}

manifest_row="$(awk -F '|' -v suite="${suite_id}" '$1 == suite { print; matches += 1 } END { if (matches != 1) exit 1 }' "${manifest_path}")" || {
  echo "Suite '${suite_id}' must occur exactly once in ${manifest_path}" >&2
  exit 2
}
IFS='|' read -r manifest_id role scene timeout_seconds expected_passed sentinel allowed_error_count allowed_error_regex <<< "${manifest_row}"

case "${role}" in
  import|suite|soak) ;;
  *)
    echo "Manifest role '${role}' cannot be run directly" >&2
    exit 2
    ;;
esac
[[ "${timeout_seconds}" =~ ^[1-9][0-9]*$ ]] || {
  echo "Invalid timeout for suite '${suite_id}': ${timeout_seconds}" >&2
  exit 2
}
if [[ "${role}" == "suite" ]]; then
  [[ "${expected_passed}" =~ ^[0-9]+$ && "${sentinel}" != "-" ]] || {
    echo "Suite '${suite_id}' has invalid expected count or sentinel" >&2
    exit 2
  }
fi
[[ "${allowed_error_count}" =~ ^[0-9]+$ ]] || {
  echo "Invalid allowed error count for suite '${suite_id}'" >&2
  exit 2
}
if ((allowed_error_count > 0)) && [[ "${allowed_error_regex}" == "-" ]]; then
  echo "Suite '${suite_id}' allows errors without an exact regex" >&2
  exit 2
fi

scene_flag_count=0
exact_scene_count=0
command_arguments=("$@")
for ((argument_index = 0; argument_index < ${#command_arguments[@]}; argument_index += 1)); do
  if [[ "${command_arguments[argument_index]}" != "--scene" ]]; then
    continue
  fi
  ((scene_flag_count += 1))
  if ((argument_index + 1 < ${#command_arguments[@]})) && [[ "${command_arguments[argument_index + 1]}" == "${scene}" ]]; then
    ((exact_scene_count += 1))
  fi
done
if [[ "${scene}" != "-" ]]; then
  if ((scene_flag_count != 1 || exact_scene_count != 1)); then
    echo "Suite '${suite_id}' command must contain exactly one '--scene ${scene}' pair" >&2
    exit 2
  fi
elif ((scene_flag_count != 0)); then
  echo "Suite '${suite_id}' must not provide --scene" >&2
  exit 2
fi

temp_root="${RUNNER_TEMP:-/tmp}"
log_dir="${temp_root}/infinidive-test-logs"
mkdir -p "${log_dir}"
log_path="$(mktemp "${log_dir}/${suite_id}.XXXXXX.log")"
xdg_dir="$(mktemp -d "${temp_root%/}/infinidive-${suite_id}-xdg.XXXXXX")"
cleanup() {
  rm -rf -- "${xdg_dir}"
}
trap cleanup EXIT

echo "Running ${suite_id} with isolated XDG_DATA_HOME; log=${log_path}"
set +e
if [[ "${role}" == "soak" ]]; then
  INFINIDIVE_SOAK_ISOLATED=1 XDG_DATA_HOME="${xdg_dir}" \
    timeout --signal=TERM --kill-after=15s "${timeout_seconds}s" "$@" 2>&1 | tee "${log_path}"
else
  INFINIDIVE_TEST_ISOLATED=1 XDG_DATA_HOME="${xdg_dir}" \
    timeout --signal=TERM --kill-after=15s "${timeout_seconds}s" "$@" 2>&1 | tee "${log_path}"
fi
pipeline_status=("${PIPESTATUS[@]}")
command_status=${pipeline_status[0]}
tee_status=${pipeline_status[1]}
set -e

if ((tee_status != 0)); then
  echo "tee failed for suite '${suite_id}' with exit ${tee_status}" >&2
  exit "${tee_status}"
fi
if ((command_status != 0)); then
  echo "Godot suite '${suite_id}' failed or timed out with exit ${command_status}" >&2
  exit "${command_status}"
fi

validation_failed=0
allowed_seen=0
while IFS= read -r error_line; do
  [[ -n "${error_line}" ]] || continue
  if [[ "${error_line}" == *"SCRIPT ERROR"* || "${error_line}" == *"Parse Error"* ]]; then
    echo "Fatal script/parse output in '${suite_id}': ${error_line}" >&2
    validation_failed=1
  elif ((allowed_error_count > 0)) && [[ "${error_line}" =~ ${allowed_error_regex} ]]; then
    ((allowed_seen += 1))
  else
    echo "Unexpected Godot ERROR output in '${suite_id}': ${error_line}" >&2
    validation_failed=1
  fi
done < <(grep -E 'SCRIPT ERROR|Parse Error|ERROR' "${log_path}" || true)

if ((allowed_seen != allowed_error_count)); then
  echo "Suite '${suite_id}' expected exactly ${allowed_error_count} allowed ERROR line(s), observed ${allowed_seen}" >&2
  validation_failed=1
fi

if [[ "${role}" == "suite" ]]; then
  expected_line="${sentinel}: ${expected_passed} passed, 0 failed"
  sentinel_count="$(grep -Fxc -- "${expected_line}" "${log_path}" || true)"
  if [[ "${sentinel_count}" != "1" ]]; then
    echo "Suite '${suite_id}' expected exactly one sentinel '${expected_line}', observed ${sentinel_count}" >&2
    validation_failed=1
  fi
elif [[ "${role}" == "soak" ]]; then
  sentinel_count="$(grep -Ec '^SOAK RESULT passed=true .* failures=0 report=artifacts/[A-Za-z0-9._-]+\.json$' "${log_path}" || true)"
  if [[ "${sentinel_count}" != "1" ]]; then
    echo "Soak expected exactly one passing SOAK RESULT sentinel, observed ${sentinel_count}" >&2
    validation_failed=1
  fi
fi

if ((validation_failed != 0)); then
  exit 1
fi
echo "Checked Godot run '${suite_id}' passed output validation."
