#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 1
prepared=$1
destination=/opt/cairn-apple-tools/cargo-inputs
test ! -e "$destination"
ditto "$prepared/cargo-inputs" "$destination"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
(cd /opt/cairn-apple-tools && /usr/bin/find cargo-inputs -type f -print0 \
  | LC_ALL=C /usr/bin/sort -z | /usr/bin/xargs -0 shasum -a 256) \
  > "$prepared/cargo-inputs.sha256"
echo 'PASS: Cargo vendor source and configuration are root-owned read-only'
