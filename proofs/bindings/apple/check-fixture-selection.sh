#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
fixture="$HOME/fixture-selection"
mkdir "$fixture"
cp "$tools/fixture/settings.gradle.kts" "$fixture/settings.gradle.kts"
mkdir "$fixture/sdk" "$fixture/consumer" "$fixture/androidConsumer"
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
