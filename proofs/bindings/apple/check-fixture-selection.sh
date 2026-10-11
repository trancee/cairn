#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
fixture="$HOME/fixture-selection"
mkdir "$fixture"
cp "$tools/fixture/settings.gradle.kts" "$fixture/settings.gradle.kts"
mkdir "$fixture/sdk" "$fixture/consumer" "$fixture/androidConsumer"
for build_file in sdk/build.gradle.kts sdk/apple.gradle.kts \
  consumer/build.gradle.kts androidConsumer/build.gradle.kts; do
  test -f "$tools/fixture/$build_file"
  : > "$fixture/$build_file"
done
if "$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=invalid \
  --init-script "$tools/assert-platform-rejection.gradle" help \
  > "$HOME/fixture-invalid.log" 2>&1; then
  cat "$HOME/fixture-invalid.log"
  echo 'FAIL: unsupported fixture platform succeeded' >&2
  exit 1
fi
cat "$HOME/fixture-invalid.log"
grep -F 'Unsupported cairnProofPlatform: invalid' "$HOME/fixture-invalid.log"
echo 'PASS: fixture rejects invalid selection before project plugins or build logic'
for selection in default linux-android apple; do
  set --
  if [ "$selection" != default ]; then
    set -- "-PcairnProofPlatform=$selection"
  fi
  result=0
  "$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain \
    -Djava.net.preferIPv4Stack=true "$@" \
    --init-script "$tools/assert-platform-selection.gradle" help \
    > "$HOME/fixture-$selection.log" 2>&1 || result=$?
  cat "$HOME/fixture-$selection.log"
  if [ "$result" -ne 0 ]; then exit "$result"; fi
  expected=$selection
  if [ "$selection" = default ]; then expected=linux-android; fi
  grep -F "PASS: $expected settings select" "$HOME/fixture-$selection.log"
done
echo 'PASS: default and explicit platform settings with empty project shells; no fixture plugins loaded'
