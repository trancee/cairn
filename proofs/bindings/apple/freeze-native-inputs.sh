#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 1
prepared=$1
destination=/opt/cairn-apple-tools/native-dependencies
test ! -e "$destination"
mkdir "$destination"
/usr/bin/rsync -a --exclude=cache --exclude='*.lock' \
  "$prepared/native-home/native-cinterop-data/dependencies/" "$destination/"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
(cd /opt/cairn-apple-tools && /usr/bin/find native-dependencies -type f -print0 \
  | LC_ALL=C /usr/bin/sort -z | /usr/bin/xargs -0 shasum -a 256) \
  > "$prepared/native-inputs.sha256"
echo 'PASS: extracted Native dependencies frozen read-only'
