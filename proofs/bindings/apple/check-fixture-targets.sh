#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
fixture="$HOME/fixture-targets"
mkdir "$fixture" "$fixture/sdk" "$fixture/consumer"
cp "$tools/fixture/settings.gradle.kts" "$tools/fixture/build.gradle.kts" "$fixture/"
cp "$tools/fixture/sdk/apple.gradle.kts" "$fixture/sdk/"
cp "$tools/fixture/consumer/build.gradle.kts" "$fixture/consumer/"
ln -s "$tools/fixture/sdk/rust" "$fixture/sdk/rust"
export PATH="$tools/rust/bin:$PATH"
export CARGO_HOME="$HOME/cargo"
export CARGO_TARGET_DIR="$HOME/cargo-target"
export KONAN_DATA_DIR="$HOME/konan"
result=0
"$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=apple \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  --init-script "$tools/assert-apple-targets.gradle" help \
  > "$HOME/fixture-targets.log" 2>&1 || result=$?
cat "$HOME/fixture-targets.log"
if [ "$result" -ne 0 ]; then exit "$result"; fi
grep -F 'PASS: effective Apple SDK targets' "$HOME/fixture-targets.log"
echo 'PASS: offline Apple plugin configuration; no binding build tasks requested'
