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
warm=/opt/cairn-apple-tools/gradle-warm-home
test ! -e "$warm"
mkdir -p "$warm/9.7.0"
for cache in transforms kotlin-dsl groovy-dsl; do
  test -d "$prepared/gradle-home/caches/9.7.0/$cache"
done
/usr/bin/rsync -a --exclude='*.lock' --exclude=gc.properties \
  "$prepared/gradle-home/caches/9.7.0/transforms" \
  "$prepared/gradle-home/caches/9.7.0/kotlin-dsl" \
  "$prepared/gradle-home/caches/9.7.0/groovy-dsl" "$warm/9.7.0/"
/usr/bin/rsync -a --exclude='*.lock' --exclude=gc.properties \
  "$prepared/gradle-home/caches/jars-9" "$warm/"
chown -R root:wheel "$warm"
chmod -R a+rX,a-w "$warm"
"$(xcrun --find python3)" -I "$scripts/tool-input-manifest.py" --jobs "$(sysctl -n hw.ncpu)" \
  /opt/cairn-apple-tools gradle-warm-home \
  > "$prepared/gradle-warm-home.sha256"
echo 'PASS: Gradle dependency and warm-home seeds copied read-only without mutable locks'
