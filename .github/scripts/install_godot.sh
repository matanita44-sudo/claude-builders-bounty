#!/usr/bin/env bash
set -euo pipefail

: "${GODOT_VERSION:?GODOT_VERSION is required}"
: "${GODOT_STATUS:?GODOT_STATUS is required}"
: "${GODOT_LINUX_SHA256:?GODOT_LINUX_SHA256 is required}"
: "${GODOT_TEMPLATES_SHA256:?GODOT_TEMPLATES_SHA256 is required}"

release_base="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-${GODOT_STATUS}"
editor_archive="Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64.zip"
templates_archive="Godot_v${GODOT_VERSION}-${GODOT_STATUS}_export_templates.tpz"
template_dir="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_STATUS}"
templates_unpacked="$(mktemp -d)"
trap 'rm -rf -- "${templates_unpacked}"' EXIT

curl -L --fail --retry 3 --retry-all-errors -o godot.zip "${release_base}/${editor_archive}"
echo "${GODOT_LINUX_SHA256}  godot.zip" | sha256sum --check --strict
unzip -q godot.zip
mv "Godot_v${GODOT_VERSION}-${GODOT_STATUS}_linux.x86_64" godot
chmod +x godot
./godot --version | grep -F "${GODOT_VERSION}.${GODOT_STATUS}"

curl -L --fail --retry 3 --retry-all-errors -o export_templates.tpz "${release_base}/${templates_archive}"
echo "${GODOT_TEMPLATES_SHA256}  export_templates.tpz" | sha256sum --check --strict
unzip -q export_templates.tpz \
  templates/version.txt \
  templates/web_nothreads_release.zip \
  templates/android_debug.apk \
  templates/android_source.zip \
  -d "${templates_unpacked}"
test -f "${templates_unpacked}/templates/version.txt"
mkdir -p "${template_dir}"
cp -a "${templates_unpacked}/templates/." "${template_dir}/"
test -s "${template_dir}/web_nothreads_release.zip"
test -s "${template_dir}/android_debug.apk"
test -s "${template_dir}/android_source.zip"
