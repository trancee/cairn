#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
task=$2
case "$task" in
  :sdk:installBindgen|:sdk:buildBindings|:consumer:interopSmoke|:sdk:tasks) ;;
  :sdk:compileKotlinIosArm64|:sdk:compileKotlinIosSimulatorArm64|:sdk:compileNativeMainKotlinMetadata) ;;
  :sdk:linkDebugFrameworkIosArm64|:sdk:linkDebugFrameworkIosSimulatorArm64) ;;
  :sdk:linkDebugExecutableIosSimulatorArm64) ;;
  *) echo "FAIL: unsupported binding proof task: $task" >&2; exit 2 ;;
esac
fixture="$HOME/fixture-targets"
test -d "$fixture"
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$tools/generator-tools:$tools/rust/bin:$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CARGO_HOME="$HOME/cargo-offline"
export CARGO_TARGET_DIR="$HOME/fixture-cargo-target"
export CARGO_NET_OFFLINE=true
if [ -L "$CARGO_HOME/config.toml" ]; then
  test "$(readlink "$CARGO_HOME/config.toml")" = "$tools/cargo-inputs/vendor.toml"
else
  test ! -e "$CARGO_HOME/config.toml"
  ln -s "$tools/cargo-inputs/vendor.toml" "$CARGO_HOME/config.toml"
fi
export GRADLE_USER_HOME="$HOME/gradle"
export GRADLE_RO_DEP_CACHE="$tools/gradle-dependencies"
export GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2
export KONAN_DATA_DIR="$HOME/native-cinterop-data"
native_home="$HOME/native-distribution"
if [ ! -d "$native_home" ]; then
  mkdir "$native_home" "$native_home/klib"
  for input in "$tools/kotlin-native/"*; do
    if [ "$(basename "$input")" != klib ]; then
      ln -s "$input" "$native_home/$(basename "$input")"
    fi
  done
  for input in "$tools/kotlin-native/klib/"*; do
    if [ "$(basename "$input")" != commonized ]; then
      ln -s "$input" "$native_home/klib/$(basename "$input")"
    fi
  done
  mkdir "$native_home/klib/commonized"
fi
export KONAN_HOME="$native_home"
export IPHONEOS_DEPLOYMENT_TARGET=15.0
if [ "$task" = :consumer:interopSmoke ]; then
  test ! -e "$fixture/consumer/src"
  ln -s "$tools/fixture/consumer/src" "$fixture/consumer/src"
fi
if [ "$task" = :sdk:linkDebugExecutableIosSimulatorArm64 ]; then
  test ! -e "$fixture/sdk/simulator-smoke"
  ln -s "$tools/fixture/consumer/src/jvmMain/kotlin" "$fixture/sdk/simulator-smoke"
fi
set --
if [ "$task" = :sdk:tasks ]; then set -- --all; fi
"$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain --stacktrace \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=apple \
  -Pkotlin.native.home="$native_home" \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  "$task" "$@"
echo "PASS: isolated offline shared-fixture owning Gradle task $task"
case "$task" in
  :sdk:linkDebugFrameworkIosArm64)
    binary="$fixture/sdk/build/bin/iosArm64/debugFramework/CairnBindingSmoke.framework/CairnBindingSmoke"
    platform=IOS ;;
  :sdk:linkDebugFrameworkIosSimulatorArm64)
    binary="$fixture/sdk/build/bin/iosSimulatorArm64/debugFramework/CairnBindingSmoke.framework/CairnBindingSmoke"
    platform=IOSSIMULATOR ;;
  *) exit 0 ;;
esac
vtool=$(/usr/bin/xcrun --find vtool)
"$vtool" -show-build "$binary" > "$HOME/fixture-build-version.txt"
cat "$HOME/fixture-build-version.txt"
if ! awk -v platform="$platform" '
  $1 == "platform" && $2 == platform { platform_matches++ }
  $1 == "minos" && $2 == "15.0" { floor_matches++ }
  END { exit !(platform_matches == 1 && floor_matches == 1) }
' "$HOME/fixture-build-version.txt"; then
  echo 'FAIL: fixture framework platform/deployment floor mismatch' >&2
  exit 1
fi
echo "PASS: generated fixture linked framework $platform deployment floor 15.0"
