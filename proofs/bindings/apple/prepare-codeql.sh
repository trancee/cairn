#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$#" -eq 1
prepared=$1
scripts="$(cd "$(dirname "$0")" && pwd -P)"
test -d "$prepared"
test ! -e "$prepared/codeql"
/bin/bash "$scripts/fetch-pinned.sh" \
  https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.27.2/codeql-bundle-osx64.tar.gz \
  bdd42bab471ed16277048b35b9be7264d07bd19b7391c37d30c74e9555e61e92 "$prepared/codeql.tar.gz"
tar -xzf "$prepared/codeql.tar.gz" -C "$prepared"
test -x "$prepared/codeql/codeql"
# Use the pinned bundled pack's real dependency context without altering its lock.
query_pack=$(/usr/bin/find "$prepared/codeql/qlpacks/codeql/java-queries" \
  -mindepth 1 -maxdepth 1 -type d)
if [ ! -f "$query_pack/codeql-suites/java-code-scanning.qls" ]; then
  echo 'FAIL: pinned Java query pack is missing or ambiguous' >&2
  exit 1
fi
cp "$scripts/kotlin-source-inventory.ql" "$query_pack/CairnSourceInventory.ql"
git ls-files -z -- '*.kt' | "$(xcrun --find python3)" -I -c \
  'import json, sys; json.dump(sys.stdin.buffer.read().decode("utf-8").split("\0")[:-1], sys.stdout)' \
  > "$prepared/kotlin-sources.json"
/bin/bash "$scripts/fetch-pinned.sh" \
  https://dl.google.com/android/repository/platform-37.0_r02.zip \
  840b23e827f96e64aea4c89a1194aac3dc5f6bad37edb231c5c795d890330e8d "$prepared/android-api.zip"
unzip -q "$prepared/android-api.zip" -d "$prepared/android-api"
android_jar=$(/usr/bin/find "$prepared/android-api" -name android.jar -type f)
test -f "$android_jar"
cp "$android_jar" "$prepared/android-api.jar"
echo 'PASS: checksum-verified CodeQL and Android API inputs prepared; no Kotlin compilation'
