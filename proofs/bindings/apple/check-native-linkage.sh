#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
target=$2
case "$target" in
  ios_arm64) platform=IOS ;;
  ios_simulator_arm64) platform=IOSSIMULATOR ;;
  *) echo "FAIL: unsupported trusted linkage target: $target" >&2; exit 2 ;;
esac
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export KONAN_DATA_DIR="$HOME/native-cinterop-data"
test -d "$tools/native-dependencies"
test -d "$KONAN_DATA_DIR/dependencies"
work="$HOME/native-linkage-$target"
mkdir "$work"
printf 'fun proofAdd(left: Int, right: Int): Int = left + right\n' > "$work/Probe.kt"
"$tools/kotlin-native/bin/konanc" "$work/Probe.kt" \
  -target "$target" -produce framework -o "$work/Probe" \
  -Xoverride-konan-properties=airplaneMode=true
binary="$work/Probe.framework/Probe"
test -s "$binary"
test -s "$work/Probe.framework/Headers/Probe.h"
vtool=$(/usr/bin/xcrun --find vtool)
"$vtool" -show-build "$binary" > "$work/build-version.txt"
cat "$work/build-version.txt"
if ! awk -v platform="$platform" '
  $1 == "platform" && $2 == platform { platform_matches++ }
  $1 == "minos" && $2 == "15.0" { floor_matches++ }
  END { exit !(platform_matches == 1 && floor_matches == 1) }
' "$work/build-version.txt"; then
  echo "FAIL: linked $target framework lacks expected $platform deployment floor 15.0" >&2
  exit 1
fi
echo "PASS: isolated trusted Native framework linkage $target; deployment floor 15.0; no fixture bindings"
