#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 1
prepared=$1
scripts="$(cd "$(dirname "$0")" && pwd -P)"
destination=/opt/cairn-apple-tools/cargo-inputs
test ! -e "$destination"
ditto "$prepared/cargo-inputs" "$destination"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
"$(xcrun --find python3)" -I "$scripts/tool-input-manifest.py" \
  /opt/cairn-apple-tools cargo-inputs \
  > "$prepared/cargo-inputs.sha256"
echo 'PASS: Cargo vendor source and configuration are root-owned read-only'
