#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export KONAN_DATA_DIR="$HOME/native-cinterop-data"
mkdir "$HOME/native-cinterop"
cd "$HOME/native-cinterop"
printf '#include <stdint.h>\nstatic inline int32_t proof_add(int32_t a, int32_t b) { return a + b; }\n' \
  > probe.h
printf 'headers = probe.h\npackage = cairn.probe\n' > probe.def
for target in ios_arm64 ios_simulator_arm64; do
  "$tools/kotlin-native/bin/cinterop" -def probe.def -compiler-option "-I$PWD" \
    -target "$target" -o "$PWD/$target"
  test -s "$target.klib"
  echo "PASS: trusted Native header cinterop $target; no fixture bindings"
done
