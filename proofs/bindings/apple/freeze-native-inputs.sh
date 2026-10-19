#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 1
prepared=$1
scripts="$(cd "$(dirname "$0")" && pwd -P)"
destination=/opt/cairn-apple-tools/native-dependencies
test ! -e "$destination"
mkdir "$destination"
/usr/bin/rsync -a --exclude=cache --exclude='*.lock' \
  "$prepared/native-home/native-cinterop-data/dependencies/" "$destination/"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
"$(xcrun --find python3)" -I "$scripts/tool-input-manifest.py" --jobs "$(sysctl -n hw.ncpu)" \
  /opt/cairn-apple-tools native-dependencies \
  > "$prepared/native-inputs.sha256"
echo 'PASS: extracted Native dependencies frozen read-only'
