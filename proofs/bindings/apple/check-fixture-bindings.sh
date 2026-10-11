#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
fixture="$HOME/fixture-targets"
test -d "$fixture"
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$tools/rust/bin:$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CARGO_HOME="$HOME/cargo-offline"
export CARGO_TARGET_DIR="$HOME/fixture-cargo-target"
export CARGO_NET_OFFLINE=true
test ! -e "$CARGO_HOME/config.toml"
ln -s "$tools/cargo-inputs/vendor.toml" "$CARGO_HOME/config.toml"
export GRADLE_USER_HOME="$HOME/gradle"
export GRADLE_RO_DEP_CACHE="$tools/gradle-dependencies"
export GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2
export KONAN_DATA_DIR="$HOME/native-cinterop-data"
export IPHONEOS_DEPLOYMENT_TARGET=15.0
"$tools/gradle/bin/gradle" -p "$fixture" --offline --no-daemon --console=plain --stacktrace \
  -Djava.net.preferIPv4Stack=true -PcairnProofPlatform=apple \
  -Pkotlin.native.home="$tools/kotlin-native" \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  :sdk:buildBindings
echo 'PASS: isolated offline shared-fixture binding generation through owning Gradle task'
