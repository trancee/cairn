#!/usr/bin/env bash
set -euo pipefail
# Prepares the root Gradle build's downloaded inputs for the strict CodeQL cell.
# Network-enabled and unprivileged; compiles no repository code.
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -ne 0
test "$#" -eq 1
prepared=$1
scripts="$(cd "$(dirname "$0")" && pwd -P)"
repository="$(cd "$scripts/../../.." && pwd -P)"
tools=/opt/cairn-apple-tools
output="$prepared/repository-inputs"
test ! -e "$output"
test -d "$prepared/android-api/android-37.0"
mkdir "$output"
rust=1.99.0
if ! rustup run "$rust" rustc --version; then
  rustup toolchain install "$rust" --profile minimal
fi
rust_home="$(dirname "$(dirname "$(rustup which --toolchain "$rust" rustc)")")"
test "$("$rust_home/bin/rustc" --version | cut -d' ' -f2)" = "$rust"

mkdir "$output/source"
git -C "$repository" ls-files -z -- settings.gradle.kts build.gradle.kts gradle.properties \
  gradle sdk app androidApp core ':(exclude)core/fuzz' ':(exclude)core/ct' \
  | (cd "$repository" && tar --null -T - -cf -) | tar -xf - -C "$output/source"
test -f "$output/source/core/Cargo.lock"
test ! -e "$output/source/core/target"

ubique_commit=0a901a3da37fd9d8cc71f76613e4183306ee811a
git clone --quiet --no-checkout \
  https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings.git "$output/ubique"
git -C "$output/ubique" checkout --quiet "$ubique_commit"
test "$(git -C "$output/ubique" rev-parse HEAD)" = "$ubique_commit"
rm -rf "$output/ubique/.git"

/bin/bash "$scripts/fetch-pinned.sh" \
  https://dl.google.com/android/repository/build-tools_r36_macosx.zip \
  04e7f3a72044de4926fa038fa0e251a37bba1e1c3fb8beab6f8401bfd9eb4bf3 "$prepared/build-tools.zip"
sdk="$output/android-sdk"
mkdir -p "$sdk/platforms" "$sdk/build-tools" "$prepared/build-tools"
ditto "$prepared/android-api/android-37.0" "$sdk/platforms/android-37.0"
unzip -q "$prepared/build-tools.zip" -d "$prepared/build-tools"
mv "$prepared/build-tools/android-16" "$sdk/build-tools/36.0.0"
# Archives carry no SDK manager metadata; AGP locates packages by package.xml.
cp "$scripts/android-sdk/platform-37.0.package.xml" "$sdk/platforms/android-37.0/package.xml"
cp "$scripts/android-sdk/build-tools-36.0.0.package.xml" "$sdk/build-tools/36.0.0/package.xml"

export CARGO_HOME="$prepared/repository-cargo"
mkdir "$output/cargo-inputs"
"$rust_home/bin/cargo" vendor --locked \
  --manifest-path "$output/source/core/Cargo.toml" \
  --sync "$output/ubique/bindgen/Cargo.toml" \
  --sync "$output/ubique/runtime/Cargo.toml" \
  "$output/cargo-inputs/vendor" > "$output/cargo-inputs/vendor.toml"
sed -i '' "s|^directory = .*|directory = \"$tools/repository-inputs/cargo-inputs/vendor\"|" \
  "$output/cargo-inputs/vendor.toml"
grep -Fx "directory = \"$tools/repository-inputs/cargo-inputs/vendor\"" \
  "$output/cargo-inputs/vendor.toml"

resolve="$prepared/repository-resolve"
mkdir "$resolve" "$prepared/repository-home"
(cd "$output/source" && tar -cf - .) | tar -xf - -C "$resolve"
/usr/bin/env -i HOME="$prepared/repository-home" TMPDIR="$prepared/repository-home" \
  LANG=en_US.UTF-8 PATH="$rust_home/bin:$tools/daemon-jdk/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
  JAVA_HOME="$tools/daemon-jdk" GRADLE_USER_HOME="$prepared/repository-gradle-home" \
  CARGO_HOME="$CARGO_HOME" CARGO_TARGET_DIR="$prepared/repository-cargo-target" \
  ANDROID_HOME="$sdk" ANDROID_USER_HOME="$prepared/repository-home/android" \
  "$tools/gradle/bin/gradle" -p "$resolve" --no-daemon --console=plain \
  -Pcairn.uniffi.bindgen="$output/ubique/bindgen" \
  -Porg.gradle.java.installations.paths="$tools/compiler-jdk" \
  -Porg.gradle.java.installations.auto-download=false \
  --init-script "$repository/proofs/bindings/linux-android/resolve-repository-inputs.gradle" \
  cairnResolveRepositoryInputs
test ! -e "$prepared/repository-cargo-target"
mkdir "$output/gradle-dependencies"
/usr/bin/rsync -a --exclude='*.lock' --exclude=gc.properties \
  "$prepared/repository-gradle-home/caches/modules-2" "$output/gradle-dependencies/"
echo 'PASS: root Gradle build inputs prepared; no repository compilation output'
