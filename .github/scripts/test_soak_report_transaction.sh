#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 GODOT_BINARY TEMP_ROOT" >&2
  exit 2
fi

godot_binary="$(realpath "$1")"
temp_root="$2"
workspace_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
transaction_root="$(mktemp -d "${temp_root%/}/infinidive-soak-transaction.XXXXXX")"
project_dir="${transaction_root}/infinidive-game"
stem="soak-transaction-ci"
diagnostic_stem="soak-source-change-ci"
artifact_dir="${project_dir}/artifacts"
json_path="${artifact_dir}/${stem}.json"
markdown_path="${artifact_dir}/${stem}.md"

cleanup() {
  rm -rf -- "${transaction_root}"
}
trap cleanup EXIT

mkdir -p "${project_dir}"
cp -a "${workspace_root}/infinidive-game/." "${project_dir}/"
mkdir -p "${artifact_dir}"
find "${artifact_dir}" -maxdepth 1 -type f -name "${stem}*" -delete
find "${artifact_dir}" -maxdepth 1 -type f -name "${diagnostic_stem}*" -delete

run_soak() {
  local label="$1"
  local hook="${2:-}"
  local selected_stem="${3:-${stem}}"
  local data_dir="${transaction_root}/xdg-${label}"
  local log_path="${transaction_root}/${label}.log"
  mkdir -p "${data_dir}"
  local -a environment=(
    "INFINIDIVE_SOAK_ISOLATED=1"
    "XDG_DATA_HOME=${data_dir}"
  )
  if [[ -n "${hook}" ]]; then
    environment+=(
      "INFINIDIVE_SOAK_SELF_TEST=1"
      "INFINIDIVE_SOAK_REPORT_SELF_TEST=${hook}"
    )
  fi
  set +e
  env "${environment[@]}" timeout --signal=TERM --kill-after=15s 45s "${godot_binary}" \
    --headless --path "${project_dir}" \
    --scene res://tests/soak/SoakTest.tscn -- \
    --duration-seconds=1.5 --seed=203541 --report-stem="${selected_stem}" \
    >"${log_path}" 2>&1
  local status=$?
  set -e
  printf '%s\n' "${status}"
}

assert_no_engine_errors() {
  local log_path="$1"
  if grep -E 'SCRIPT ERROR|Parse Error|ERROR' "${log_path}" >/dev/null; then
    echo "Unexpected engine error in ${log_path}" >&2
    sed -n '1,240p' "${log_path}" >&2
    exit 1
  fi
}

assert_no_transaction_residue() {
  local residue
  residue="$(find "${artifact_dir}" -maxdepth 1 -type f \
    \( -name "${stem}*.next" -o -name "${stem}*.previous" \) -print)"
  if [[ -n "${residue}" ]]; then
    echo "Transaction residue remained:" >&2
    printf '%s\n' "${residue}" >&2
    exit 1
  fi
}

assert_pair_unchanged() {
  local actual_json_hash actual_markdown_hash
  actual_json_hash="$(sha256sum "${json_path}" | awk '{print $1}')"
  actual_markdown_hash="$(sha256sum "${markdown_path}" | awk '{print $1}')"
  [[ "${actual_json_hash}" == "${baseline_json_hash}" ]]
  [[ "${actual_markdown_hash}" == "${baseline_markdown_hash}" ]]
  assert_no_transaction_residue
}

run_expected_failure() {
  local label="$1"
  local hook="$2"
  local expected_failure="$3"
  local status
  status="$(run_soak "${label}" "${hook}")"
  if [[ "${status}" -ne 1 ]]; then
    echo "${hook} returned ${status}; expected exactly 1" >&2
    sed -n '1,240p' "${transaction_root}/${label}.log" >&2
    exit 1
  fi
  assert_no_engine_errors "${transaction_root}/${label}.log"
  if [[ "$(grep -c '^SOAK FAILURE ' "${transaction_root}/${label}.log")" -ne 1 ]] || \
    ! grep -F "SOAK FAILURE ${expected_failure}:" "${transaction_root}/${label}.log" >/dev/null; then
    echo "${hook} did not emit exactly its expected controlled failure" >&2
    sed -n '1,240p' "${transaction_root}/${label}.log" >&2
    exit 1
  fi
  grep -F 'SOAK RESULT passed=false' "${transaction_root}/${label}.log" >/dev/null
  assert_pair_unchanged
}

baseline_status="$(run_soak baseline)"
if [[ "${baseline_status}" -ne 0 ]]; then
  echo "Baseline soak failed with ${baseline_status}" >&2
  sed -n '1,240p' "${transaction_root}/baseline.log" >&2
  exit 1
fi
assert_no_engine_errors "${transaction_root}/baseline.log"
if grep -F 'SOAK FAILURE ' "${transaction_root}/baseline.log" >/dev/null; then
  echo "Baseline emitted a soak failure" >&2
  exit 1
fi
python3 "${workspace_root}/.github/scripts/validate_soak_report.py" \
  "${json_path}" --minimum-duration=1.5
test -s "${markdown_path}"
baseline_json_hash="$(sha256sum "${json_path}" | awk '{print $1}')"
baseline_markdown_hash="$(sha256sum "${markdown_path}" | awk '{print $1}')"
assert_no_transaction_residue

# A report that was valid when produced must become invalid as soon as any
# fingerprinted production source changes. The mutation is confined to this
# disposable project copy and restored byte-for-byte before continuing.
fingerprint_probe_source="${project_dir}/project.godot"
fingerprint_probe_backup="${transaction_root}/project.godot.fingerprint-original"
cp "${fingerprint_probe_source}" "${fingerprint_probe_backup}"
printf '\n; soak-validator-stale-source-probe\n' >> "${fingerprint_probe_source}"
set +e
python3 "${workspace_root}/.github/scripts/validate_soak_report.py" \
  "${json_path}" --minimum-duration=1.5 >"${transaction_root}/stale_source_validator.log" 2>&1
stale_source_status=$?
set -e
mv "${fingerprint_probe_backup}" "${fingerprint_probe_source}"
if [[ "${stale_source_status}" -ne 1 ]] || \
  ! grep -F 'source_fingerprint_end does not match the current production source fingerprint' \
    "${transaction_root}/stale_source_validator.log" >/dev/null; then
  echo "Validator did not reject a stale report after production source mutation" >&2
  sed -n '1,240p' "${transaction_root}/stale_source_validator.log" >&2
  exit 1
fi
python3 "${workspace_root}/.github/scripts/validate_soak_report.py" \
  "${json_path}" --minimum-duration=1.5
assert_pair_unchanged

# A parseable but structurally truncated final pair must not outrank the last
# complete backups during recovery.
baseline_transaction_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["report_transaction_id"])' "${json_path}")"
cp "${json_path}" "${json_path}.previous"
cp "${markdown_path}" "${markdown_path}.previous"
printf '{"schema":1,"passed":true,"failures":[],"report_transaction_id":"%s"}\n' \
  "${baseline_transaction_id}" > "${json_path}"
printf '# INFINIDIVE Headless Soak Report\n\n- Result: **PASS**\n- Report transaction: `%s`\n' \
  "${baseline_transaction_id}" > "${markdown_path}"
run_expected_failure minimal_pair json_open report_json_open

# A complete, correctly hashed schema with zero core activity must likewise
# lose to the last valid backups during recovery.
cp "${json_path}" "${json_path}.previous"
cp "${markdown_path}" "${markdown_path}.previous"
python3 - "${json_path}" "${markdown_path}" <<'PY'
import hashlib
import json
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
markdown_path = pathlib.Path(sys.argv[2])
report = json.loads(json_path.read_text(encoding="utf-8"))
markdown = markdown_path.read_text(encoding="utf-8")
for field in (
    "iterations",
    "projectile_cycles",
    "boss_restarts",
    "dive_transitions",
    "player_projectiles_spawned",
    "enemy_projectiles_spawned",
    "save_writes",
    "offline_events_queued",
    "offline_queue_reloads",
):
    report["counts"][field] = 0
for map_name in (
    "projectile_model_steps",
    "projectile_models_requested",
    "projectile_models_executed",
):
    report["counts"][map_name] = {model: 0 for model in report["counts"][map_name]}
markdown = markdown.replace(
    "| Projectile travel models exercised | 7 / 7 |",
    "| Projectile travel models exercised | 0 / 7 |",
)
markdown_path.write_text(markdown, encoding="utf-8")
report["report_markdown_sha256"] = hashlib.sha256(markdown_path.read_bytes()).hexdigest()
json_path.write_text(json.dumps(report, indent="\t", sort_keys=True) + "\n", encoding="utf-8")
PY
run_expected_failure rich_zero_core json_open report_json_open

# Crash after moving only JSON to its backup: backup JSON + final Markdown.
mv "${json_path}" "${json_path}.previous"
run_expected_failure hybrid_json_backup markdown_open report_markdown_open

# Symmetric rollback crash: final JSON + backup Markdown.
mv "${markdown_path}" "${markdown_path}.previous"
run_expected_failure hybrid_markdown_backup json_open report_json_open

run_expected_failure first_commit first_commit report_first_commit
run_expected_failure second_commit second_commit report_second_commit
run_expected_failure json_write json_write report_json_write
run_expected_failure markdown_write markdown_write report_markdown_write
run_expected_failure pair_verify pair_verify report_pair_verify

python3 "${workspace_root}/.github/scripts/validate_soak_report.py" \
  "${json_path}" --minimum-duration=1.5
assert_pair_unchanged

cleanup_status="$(run_soak cleanup_failure cleanup_failure)"
if [[ "${cleanup_status}" -ne 1 ]]; then
  echo "cleanup_failure returned ${cleanup_status}; expected exactly 1" >&2
  sed -n '1,240p' "${transaction_root}/cleanup_failure.log" >&2
  exit 1
fi
assert_no_engine_errors "${transaction_root}/cleanup_failure.log"
if [[ "$(grep -c '^SOAK FAILURE ' "${transaction_root}/cleanup_failure.log")" -ne 1 ]] || \
  ! grep -F 'SOAK FAILURE report_cleanup_failure:' "${transaction_root}/cleanup_failure.log" >/dev/null; then
  echo "cleanup_failure did not emit exactly its expected controlled failure" >&2
  sed -n '1,240p' "${transaction_root}/cleanup_failure.log" >&2
  exit 1
fi
grep -F 'SOAK RESULT passed=false' "${transaction_root}/cleanup_failure.log" >/dev/null
set +e
python3 "${workspace_root}/.github/scripts/validate_soak_report.py" \
  "${json_path}" --minimum-duration=1.5 >"${transaction_root}/cleanup_validator.log" 2>&1
cleanup_validator_status=$?
set -e
if [[ "${cleanup_validator_status}" -ne 1 ]] || \
  ! grep -F 'report_transaction_complete must be true' "${transaction_root}/cleanup_validator.log" >/dev/null; then
  echo "Post-commit cleanup failure left a validator-green report" >&2
  sed -n '1,240p' "${transaction_root}/cleanup_validator.log" >&2
  exit 1
fi
cleanup_transaction_id="$(python3 -c 'import json,sys; report=json.load(open(sys.argv[1], encoding="utf-8")); assert report["passed"] is True; assert report["failures"] == []; assert report["report_transaction_complete"] is False; print(report["report_transaction_id"])' "${json_path}")"
cleanup_json_hash="$(sha256sum "${json_path}" | awk '{print $1}')"
cleanup_markdown_hash="$(sha256sum "${markdown_path}" | awk '{print $1}')"
[[ "${cleanup_transaction_id}" != "${baseline_transaction_id}" ]]
[[ "${cleanup_json_hash}" != "${baseline_json_hash}" ]]
[[ "${cleanup_markdown_hash}" != "${baseline_markdown_hash}" ]]
if [[ -e "${json_path}.previous" ]] || [[ ! -s "${markdown_path}.previous" ]]; then
  echo "Post-commit cleanup fault did not leave exactly the injected Markdown backup residue" >&2
  exit 1
fi
[[ "$(sha256sum "${markdown_path}.previous" | awk '{print $1}')" == "${baseline_markdown_hash}" ]]
rm -- "${markdown_path}.previous"

diagnostic_json_path="${artifact_dir}/${diagnostic_stem}.json"
diagnostic_markdown_path="${artifact_dir}/${diagnostic_stem}.md"
diagnostic_status="$(run_soak diagnostic_source_change source_change "${diagnostic_stem}")"
if [[ "${diagnostic_status}" -ne 1 ]]; then
  echo "source_change returned ${diagnostic_status}; expected exactly 1" >&2
  sed -n '1,240p' "${transaction_root}/diagnostic_source_change.log" >&2
  exit 1
fi
assert_no_engine_errors "${transaction_root}/diagnostic_source_change.log"
if [[ "$(grep -c '^SOAK FAILURE ' "${transaction_root}/diagnostic_source_change.log")" -ne 1 ]] || \
  ! grep -F 'SOAK FAILURE source_changed_during_run:' "${transaction_root}/diagnostic_source_change.log" >/dev/null; then
  echo "source_change did not emit exactly its expected diagnostic failure" >&2
  sed -n '1,240p' "${transaction_root}/diagnostic_source_change.log" >&2
  exit 1
fi
grep -F 'SOAK RESULT passed=false' "${transaction_root}/diagnostic_source_change.log" >/dev/null
# The in-engine hook synthesizes the end digest without modifying source. Turn
# that controlled failure into a standalone-validator diagnostic fixture by
# treating its synthetic digest as the prior source and the genuine start
# digest as the current end. Markdown remains bound to the same transaction.
python3 - "${diagnostic_json_path}" "${diagnostic_markdown_path}" <<'PY'
import hashlib
import json
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
markdown_path = pathlib.Path(sys.argv[2])
report = json.loads(json_path.read_text(encoding="utf-8"))
markdown = markdown_path.read_text(encoding="utf-8")
current_fingerprint = report["source_fingerprint_start"]
prior_fingerprint = report["source_fingerprint_end"]
report["source_fingerprint_start"] = prior_fingerprint
report["source_fingerprint_end"] = current_fingerprint
markdown = markdown.replace(
    f"- Source fingerprint: `{current_fingerprint}`",
    f"- Source fingerprint: `{prior_fingerprint}`",
)
markdown_path.write_text(markdown, encoding="utf-8")
report["report_markdown_sha256"] = hashlib.sha256(markdown_path.read_bytes()).hexdigest()
json_path.write_text(json.dumps(report, indent="\t", sort_keys=True) + "\n", encoding="utf-8")
PY
python3 "${workspace_root}/.github/scripts/validate_soak_report.py" \
  "${diagnostic_json_path}" --minimum-duration=1.5 --expected-result=fail
test -s "${diagnostic_markdown_path}"
if find "${artifact_dir}" -maxdepth 1 -type f \
  \( -name "${diagnostic_stem}*.next" -o -name "${diagnostic_stem}*.previous" \) -print | grep -q .; then
  echo "Diagnostic transaction residue remained" >&2
  exit 1
fi
diagnostic_transaction_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["report_transaction_id"])' "${diagnostic_json_path}")"
diagnostic_json_hash="$(sha256sum "${diagnostic_json_path}" | awk '{print $1}')"
diagnostic_markdown_hash="$(sha256sum "${diagnostic_markdown_path}" | awk '{print $1}')"
echo "SOAK TRANSACTION BASELINE tx=${baseline_transaction_id} json=${baseline_json_hash} markdown=${baseline_markdown_hash}"
echo "SOAK TRANSACTION CLEANUP_PENDING tx=${cleanup_transaction_id} json=${cleanup_json_hash} markdown=${cleanup_markdown_hash}"
echo "SOAK TRANSACTION DIAGNOSTIC tx=${diagnostic_transaction_id} json=${diagnostic_json_hash} markdown=${diagnostic_markdown_hash}"
echo "SOAK TRANSACTION SELF-TEST PASS"
