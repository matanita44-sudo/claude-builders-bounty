#!/usr/bin/env bash
set -euo pipefail

web_dir="${1:-build/web}"
pages_dir="${2:-build/pages}"

test -s "${web_dir}/index.html"
test -n "$(find "${web_dir}" -maxdepth 1 -type f -name '*.wasm' -print -quit)"
test -n "$(find "${web_dir}" -maxdepth 1 -type f -name '*.pck' -print -quit)"
test -s "${web_dir}/privacy.html"
test -s "${web_dir}/support.html"
test -s "${web_dir}/terms.html"
test -f "${web_dir}/.nojekyll"

if grep -q '\$GODOT_' "${web_dir}/index.html"; then
  echo "Unresolved Godot custom-shell placeholder in exported index.html" >&2
  exit 1
fi
if ! grep -q '"ensureCrossOriginIsolationHeaders":false' "${web_dir}/index.html"; then
  echo "Web export unexpectedly requires cross-origin isolation headers" >&2
  exit 1
fi

test -f "${pages_dir}/.nojekyll"
test -s "${pages_dir}/infinidive/index.html"
if find "${pages_dir}" -mindepth 1 -maxdepth 1 ! -name infinidive ! -name .nojekyll -print -quit | grep -q .; then
  echo "Pages artifact contains an unexpected repository-root entry" >&2
  exit 1
fi

find "${web_dir}" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort
