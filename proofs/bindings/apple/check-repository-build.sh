#!/usr/bin/env bash
set -euo pipefail
# Builds the root Gradle build offline from frozen inputs in bounded scratch.
test "$#" -eq 2
tools=$1
mode=$2
test "$tools" = /opt/cairn-apple-tools
inputs="$tools/repository-inputs"
project="$HOME/repository-build"
case "$mode" in
  bindings) tasks=(:sdk:buildBindings) ;;
  compile)
    tasks=(:sdk:compileKotlinJvm :sdk:compileTestKotlinJvm :sdk:compileAndroidMain
      :app:compileAndroidMain :androidApp:compileDebugKotlin) ;;
  *) echo "FAIL: unsupported root build mode: $mode" >&2; exit 2 ;;
esac
if [ "$mode" = bindings ]; then
  test ! -e "$project"
  mkdir "$project"
  cp "$inputs/source/settings.gradle.kts" "$inputs/source/build.gradle.kts" \
    "$inputs/source/gradle.properties" "$project/"
  cp -R "$inputs/source/gradle" "$project/gradle"
  for module in sdk app androidApp; do
    mkdir "$project/$module"
    cp "$inputs/source/$module/build.gradle.kts" "$project/$module/"
    ln -s "$inputs/source/$module/src" "$project/$module/src"
  done
  ln -s "$inputs/source/core" "$project/core"
fi
test -d "$project"
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$inputs/generator-tools:$inputs/rust/bin:$JAVA_HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CARGO_HOME="$HOME/repository-cargo"
export CARGO_TARGET_DIR="$HOME/repository-cargo-target"
export CARGO_NET_OFFLINE=true
if [ -L "$CARGO_HOME/config.toml" ]; then
  test "$(readlink "$CARGO_HOME/config.toml")" = "$inputs/cargo-inputs/vendor.toml"
else
  test ! -e "$CARGO_HOME"
  mkdir "$CARGO_HOME"
  ln -s "$inputs/cargo-inputs/vendor.toml" "$CARGO_HOME/config.toml"
fi
export GRADLE_USER_HOME="$HOME/repository-gradle"
export GRADLE_RO_DEP_CACHE="$inputs/gradle-dependencies"
export GRADLE_DAEMON_BIND_ADDRESS=127.0.0.2
export ANDROID_HOME="$inputs/android-sdk"
export ANDROID_USER_HOME="$HOME/repository-android"
"$tools/gradle/bin/gradle" -p "$project" --offline --no-daemon --max-workers=1 \
  --console=plain --stacktrace -Djava.net.preferIPv4Stack=true \
  -Pcairn.uniffi.bindgen="$inputs/ubique/bindgen" \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  -Pkotlin.compiler.execution.strategy=in-process \
  "${tasks[@]}"
echo "PASS: isolated offline root Gradle build $mode"
