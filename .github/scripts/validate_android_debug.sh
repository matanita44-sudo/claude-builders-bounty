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

command -v aapt > /dev/null
badging="$(aapt dump badging "${apk_path}")"
grep -Fq "package: name='com.matan.infinidive' versionCode='1' versionName='0.1.0'" <<< "${badging}"
grep -Fq "application-label:'INFINIDIVE'" <<< "${badging}"
grep -Fq "sdkVersion:'24'" <<< "${badging}"
grep -Fq "targetSdkVersion:'36'" <<< "${badging}"

adaptive_icon_report="$(aapt dump xmltree "${apk_path}" res/mipmap-anydpi-v26/icon.xml)"
grep -Fq 'E: adaptive-icon' <<< "${adaptive_icon_report}"
grep -Fq 'E: background' <<< "${adaptive_icon_report}"
grep -Fq 'E: foreground' <<< "${adaptive_icon_report}"
grep -Fq 'E: monochrome' <<< "${adaptive_icon_report}"

mapfile -t native_abis < <(unzip -Z1 "${apk_path}" | sed -n 's#^lib/\([^/]*\)/.*#\1#p' | sort -u)
if [[ "${native_abis[*]}" != "arm64-v8a" ]]; then
  printf 'Unexpected native ABI set: %s\n' "${native_abis[*]:-(none)}" >&2
  exit 1
fi

permissions_report="$(aapt dump permissions "${apk_path}")"
mapfile -t requested_permissions < <(
  sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" <<< "${permissions_report}" | sort -u
)
if [[ "${requested_permissions[*]}" != "android.permission.VIBRATE" ]]; then
  echo "Debug APK must request exactly android.permission.VIBRATE for optional haptics" >&2
  printf '%s\n' "${permissions_report}" >&2
  exit 1
fi

sha256sum "${apk_path}"
