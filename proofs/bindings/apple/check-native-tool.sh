#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
native="$tools/kotlin-native"
if [ ! -x "$native/bin/konanc" ]; then
  echo 'FAIL: immutable Kotlin Native compiler is missing' >&2
  exit 1
fi
export JAVA_HOME="$tools/daemon-jdk"
export KONAN_DATA_DIR="$HOME/konan"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin"
"$native/bin/konanc" -version
echo 'PASS: pinned Kotlin Native compiler startup; no fixture compilation'
