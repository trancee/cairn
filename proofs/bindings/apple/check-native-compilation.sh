#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin"
export KONAN_DATA_DIR="$HOME/native-compile-data"
mkdir "$HOME/native-compile"
printf 'fun proofAdd(left: Int, right: Int): Int = left + right\n' \
  > "$HOME/native-compile/Probe.kt"
for target in ios_arm64 ios_simulator_arm64; do
  "$tools/kotlin-native/bin/konanc" "$HOME/native-compile/Probe.kt" \
    -target "$target" -produce library -o "$HOME/native-compile/$target" \
    -Xkonan-data-dir="$KONAN_DATA_DIR"
  test -s "$HOME/native-compile/$target.klib"
  echo "PASS: isolated trusted Kotlin Native KLIB compilation $target; no fixture bindings"
done
