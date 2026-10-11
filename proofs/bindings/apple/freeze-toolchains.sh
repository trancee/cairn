#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 4
prepared=$1
rust=$2
daemon=$3
compiler=$4
destination=/opt/cairn-apple-tools
scripts="$(cd "$(dirname "$0")" && pwd -P)"
test ! -e "$destination"
umask 022
mkdir "$destination"
ditto "$prepared/gradle-9.7.0" "$destination/gradle"
ditto "$rust" "$destination/rust"
ditto "$daemon" "$destination/daemon-jdk"
ditto "$compiler" "$destination/compiler-jdk"
ditto "$prepared/kotlin-native" "$destination/kotlin-native"
ditto "$scripts/../linux-android" "$destination/fixture"
ditto "$prepared/ubique" "$destination/ubique"
cp "$scripts/assert-platform-rejection.gradle" "$destination/assert-platform-rejection.gradle"
cp "$scripts/assert-platform-selection.gradle" "$destination/assert-platform-selection.gradle"
cp "$scripts/check-fixture-selection.sh" "$destination/check-fixture-selection.sh"
cp "$scripts/assert-apple-targets.gradle" "$destination/assert-apple-targets.gradle"
cp "$scripts/check-fixture-targets.sh" "$destination/check-fixture-targets.sh"
cp "$scripts/create-plugin-project.sh" "$destination/create-plugin-project.sh"
cp "$scripts/resolve-apple-inputs.gradle" "$destination/resolve-apple-inputs.gradle"
cp "$scripts/check-cargo-inputs.sh" "$destination/check-cargo-inputs.sh"
cp "$scripts/check-native-tool.sh" "$destination/check-native-tool.sh"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
ls -ld "$destination" "$destination/rust" "$destination/rust/bin" "$destination/rust/bin/rustc"
(cd "$destination" && /usr/bin/find . -type f -print0 \
  | LC_ALL=C /usr/bin/sort -z | /usr/bin/xargs -0 shasum -a 256) \
  > "$prepared/toolchains.sha256"
echo 'PASS: trusted tool copies are root-owned read-only; fixture/cache freezing is not implied'
