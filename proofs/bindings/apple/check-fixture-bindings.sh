#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
task=$2
case "$task" in
  :sdk:installBindgen|:sdk:buildBindings|:consumer:interopSmoke|:sdk:tasks) ;;
  :sdk:compileKotlinIosArm64|:sdk:compileKotlinIosSimulatorArm64|:sdk:compileNativeMainKotlinMetadata) ;;
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
export KONAN_HOME="$tools/kotlin-native"
export IPHONEOS_DEPLOYMENT_TARGET=15.0
if [ "$task" = :consumer:interopSmoke ]; then
  test ! -e "$fixture/consumer/src"
  ln -s "$tools/fixture/consumer/src" "$fixture/consumer/src"
fi
set --
if [ "$task" = :sdk:tasks ]; then set -- --all; fi
"$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain --stacktrace \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=apple \
  -Pkotlin.native.home="$tools/kotlin-native" \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  "$task" "$@"
echo "PASS: isolated offline shared-fixture owning Gradle task $task"
