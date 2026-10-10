#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$#" -eq 1
output=$1
test ! -e "$output"
umask 077
mkdir "$output"
output="$(cd "$output" && pwd -P)"
scripts="$(cd "$(dirname "$0")" && pwd -P)"
rust=1.97.1
if ! rustup run "$rust" rustc --version; then
  rustup toolchain install "$rust" --profile minimal \
    --target aarch64-apple-ios --target aarch64-apple-ios-sim
else
  rustup target add --toolchain "$rust" aarch64-apple-ios aarch64-apple-ios-sim
fi
gradle_hash=84fbba45c7f4c64abc77460e1c00f541e9f960e3c7ed2538f1ede19eacd873ae
curl --fail --silent --show-error --location \
  https://services.gradle.org/distributions/gradle-9.7.0-bin.zip \
  -o "$output/gradle.zip"
printf '%s  %s\n' "$gradle_hash" "$output/gradle.zip" | shasum -a 256 --check
unzip -q "$output/gradle.zip" -d "$output"
export JAVA_HOME="$CAIRN_DAEMON_JAVA_HOME"
{
  rustup run "$rust" rustc --version --verbose
  rustup target list --toolchain "$rust" --installed
  "$JAVA_HOME/bin/java" -version
  "$output/gradle-9.7.0/bin/gradle" --version
  xcodebuild -version
} > "$output/versions.txt" 2>&1
cat "$output/versions.txt"
export CARGO_HOME="$output/cargo"
rustup run "$rust" cargo fetch --locked \
  --manifest-path "$scripts/../linux-android/sdk/rust/Cargo.toml"
git clone --quiet --no-checkout \
  https://github.com/UbiqueInnovation/uniffi-kotlin-multiplatform-bindings.git \
  "$output/ubique"
git -C "$output/ubique" checkout --quiet b819fb4ea33d0ddeb3f1970e5b0d7367c3c7d300
test "$(git -C "$output/ubique" rev-parse HEAD)" = b819fb4ea33d0ddeb3f1970e5b0d7367c3c7d300
rustup run "$rust" cargo fetch --locked --manifest-path "$output/ubique/bindgen/Cargo.toml"
shasum -a 256 "$output/gradle.zip" \
  "$scripts/../linux-android/sdk/rust/Cargo.lock" \
  "$output/ubique/Cargo.lock" > "$output/inputs.sha256"
echo 'PASS: pinned Apple toolchain and Cargo downloads prepared; no fixture build or isolation acceptance'
