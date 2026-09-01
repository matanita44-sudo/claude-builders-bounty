#!/usr/bin/env bash
set -euo pipefail

: "${ANDROID_HOME:?ANDROID_HOME is required on the runner}"
: "${JAVA_HOME:?JAVA_HOME is required on the runner}"
: "${GITHUB_PATH:?GITHUB_PATH is required on the runner}"
command -v keytool >/dev/null

sdkmanager_bin="$(command -v sdkmanager || true)"
if [[ -z "${sdkmanager_bin}" ]]; then
	for candidate in \
		"${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" \
		"${ANDROID_HOME}/cmdline-tools/bin/sdkmanager"; do
		if [[ -x "${candidate}" ]]; then
			sdkmanager_bin="${candidate}"
			break
		fi
	done
fi
if [[ -z "${sdkmanager_bin}" ]]; then
	sdkmanager_bin="$(find "${ANDROID_HOME}/cmdline-tools" -type f -path '*/bin/sdkmanager' -perm -u+x -print 2>/dev/null | sort -V | tail -n 1)"
fi
if [[ -z "${sdkmanager_bin}" || ! -x "${sdkmanager_bin}" ]]; then
	printf '%s\n' "Android sdkmanager was not found below ANDROID_HOME=${ANDROID_HOME}" >&2
	exit 1
fi

android_build_tools="36.0.0"
"${sdkmanager_bin}" --install \
  "build-tools;${android_build_tools}" \
  "platforms;android-36" \
  "platform-tools"

keystore_dir="${HOME}/.local/share/godot/keystores"
keystore_path="${keystore_dir}/debug.keystore"
mkdir -p "${keystore_dir}" "${HOME}/.config/godot"

if [[ ! -f "${keystore_path}" ]]; then
  keytool -genkeypair -noprompt \
    -keystore "${keystore_path}" \
    -storepass android \
    -alias androiddebugkey \
    -keypass android \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US"
fi

cat > "${HOME}/.config/godot/editor_settings-4.7.tres" <<EOF
[gd_resource format=3]

[resource]
export/android/debug_keystore = "${keystore_path}"
export/android/debug_keystore_pass = "android"
export/android/java_sdk_path = "${JAVA_HOME}"
export/android/android_sdk_path = "${ANDROID_HOME}"
EOF

build_tools_path="${ANDROID_HOME}/build-tools/${android_build_tools}"
test -x "${build_tools_path}/aapt2"
test -x "${build_tools_path}/apksigner"
test -x "${build_tools_path}/zipalign"
printf '%s\n' "${build_tools_path}" >> "${GITHUB_PATH}"
