#!/usr/bin/env bash
set -euo pipefail

apk_path="${1:?APK path is required}"
test -s "${apk_path}"

if zipalign -h 2>&1 | grep -q -- '-P'; then
  zipalign -c -P 16 4 "${apk_path}"
else
  zipalign -c -p 4 "${apk_path}"
fi
signature_report="$(apksigner verify --verbose --print-certs "${apk_path}")"
printf '%s\n' "${signature_report}"
grep -Fq 'Verified using v2 scheme (APK Signature Scheme v2): true' <<< "${signature_report}"
grep -Fq 'Signer #1 certificate DN: CN=Android Debug' <<< "${signature_report}"

allowed_godot_warning="warn: resource com.godot.game:mipmap/themed_icon for config 'anydpi-v26' is a file reference to 'res/mipmap-anydpi-v26/themed_icon.xml' but no such path exists."

validate_aapt_diagnostics() {
  local report="$1"
  local unexpected
  unexpected="$(grep -E '^(warn|error):' <<< "${report}" | grep -Fvx "${allowed_godot_warning}" || true)"
  if [[ -n "${unexpected}" ]]; then
    printf '%s\n' "Unexpected aapt2 diagnostic:" "${unexpected}" >&2
    exit 1
  fi
}

# Build-tools 36 reports Godot 4.7.2's unreferenced themed_icon table entry as
# a non-zero warning. The installed icon is @mipmap/icon; validate every
# required field from the report and reject every diagnostic except that exact
# upstream-template warning instead of treating the warning as proof of failure.
badging="$(aapt2 dump badging "${apk_path}" 2>&1 || true)"
validate_aapt_diagnostics "${badging}"
grep -Fq "package: name='com.matan.infinidive' versionCode='1' versionName='0.1.0'" <<< "${badging}"
grep -Fq "application-label:'INFINIDIVE'" <<< "${badging}"
grep -Fq "sdkVersion:'24'" <<< "${badging}"
grep -Fq "targetSdkVersion:'36'" <<< "${badging}"

adaptive_icon_report="$(aapt2 dump xmltree --file res/mipmap-anydpi-v26/icon.xml "${apk_path}" 2>&1 || true)"
validate_aapt_diagnostics "${adaptive_icon_report}"
grep -Fq 'E: adaptive-icon' <<< "${adaptive_icon_report}"
grep -Fq 'E: background' <<< "${adaptive_icon_report}"
grep -Fq 'E: foreground' <<< "${adaptive_icon_report}"
grep -Fq 'E: monochrome' <<< "${adaptive_icon_report}"

mapfile -t native_abis < <(unzip -Z1 "${apk_path}" | sed -n 's#^lib/\([^/]*\)/.*#\1#p' | sort -u)
if [[ "${native_abis[*]}" != "arm64-v8a" ]]; then
  printf 'Unexpected native ABI set: %s\n' "${native_abis[*]:-(none)}" >&2
  exit 1
fi

permissions_report="$(aapt2 dump permissions "${apk_path}" 2>&1 || true)"
validate_aapt_diagnostics "${permissions_report}"
mapfile -t requested_permissions < <(
  sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" <<< "${permissions_report}" | sort -u
)
if [[ "${requested_permissions[*]}" != "android.permission.VIBRATE" ]]; then
  echo "Debug APK must request exactly android.permission.VIBRATE for optional haptics" >&2
  printf '%s\n' "${permissions_report}" >&2
  exit 1
fi

sha256sum "${apk_path}"
