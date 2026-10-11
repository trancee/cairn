#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
fixture="$HOME/fixture-targets"
/bin/bash "$tools/create-plugin-project.sh" "$tools" "$fixture"
export PATH="$tools/rust/bin:$PATH"
export CARGO_HOME="$HOME/cargo"
export CARGO_TARGET_DIR="$HOME/cargo-target"
export KONAN_DATA_DIR="$HOME/konan"
export GRADLE_RO_DEP_CACHE="$tools/gradle-dependencies"
test -d "$GRADLE_RO_DEP_CACHE/modules-2"
result=0
"$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain --stacktrace \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=apple \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  --init-script "$tools/assert-apple-targets.gradle" help \
  > "$HOME/fixture-targets.log" 2>&1 || result=$?
cat "$HOME/fixture-targets.log"
if [ "$result" -ne 0 ]; then exit "$result"; fi
grep -F 'PASS: effective Apple SDK targets' "$HOME/fixture-targets.log"
echo 'PASS: offline Apple plugin configuration; no binding build tasks requested'
