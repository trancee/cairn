#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -ne 0
test "$#" -eq 1
prepared=$1
tools=/opt/cairn-apple-tools
fixture="$prepared/plugin-project"
scripts="$(cd "$(dirname "$0")" && pwd -P)"
/bin/bash "$scripts/create-plugin-project.sh" "$tools" "$fixture"
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$tools/rust/bin:$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export GRADLE_USER_HOME="$prepared/gradle-home"
export CARGO_HOME="$prepared/cargo"
export CARGO_TARGET_DIR="$prepared/plugin-cargo-target"
export KONAN_DATA_DIR="$prepared/konan"
mkdir "$prepared/plugin-home"
/usr/bin/env -i HOME="$prepared/plugin-home" TMPDIR="$prepared/plugin-home" \
  LANG=en_US.UTF-8 PATH="$PATH" JAVA_HOME="$JAVA_HOME" \
  GRADLE_USER_HOME="$GRADLE_USER_HOME" CARGO_HOME="$CARGO_HOME" \
  CARGO_TARGET_DIR="$CARGO_TARGET_DIR" KONAN_DATA_DIR="$KONAN_DATA_DIR" \
  "$tools/gradle/bin/gradle" -p "$fixture" --no-daemon --console=plain \
  -PcairnProofPlatform=apple \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  --init-script "$tools/assert-apple-targets.gradle" \
  --init-script "$tools/resolve-apple-inputs.gradle" cairnResolveAppleInputs \
  :sdk:transformNativeMainCInteropDependenciesMetadata
test ! -e "$CARGO_TARGET_DIR"
echo 'PASS: network-enabled pinned-plugin preparation; no Cargo compilation output'
