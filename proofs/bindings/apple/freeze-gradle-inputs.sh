#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 1
prepared=$1
scripts="$(cd "$(dirname "$0")" && pwd -P)"
destination=/opt/cairn-apple-tools/gradle-dependencies
test ! -e "$destination"
test -d "$prepared/gradle-home/caches/modules-2"
mkdir "$destination"
/usr/bin/rsync -a --exclude='*.lock' --exclude=gc.properties \
  "$prepared/gradle-home/caches/modules-2" "$destination/"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
"$(xcrun --find python3)" -I "$scripts/tool-input-manifest.py" --jobs "$(sysctl -n hw.ncpu)" \
  /opt/cairn-apple-tools gradle-dependencies \
  > "$prepared/gradle-dependencies.sha256"
echo 'PASS: Gradle dependency seed copied read-only without mutable locks'
