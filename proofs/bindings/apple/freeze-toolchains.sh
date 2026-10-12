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
cp "$scripts/check-native-compilation.sh" "$destination/check-native-compilation.sh"
cp "$scripts/check-native-cinterop.sh" "$destination/check-native-cinterop.sh"
cp "$scripts/check-native-linkage.sh" "$destination/check-native-linkage.sh"
cp "$scripts/inspect-allocator-inputs.py" "$destination/inspect-allocator-inputs.py"
cp "$scripts/check-fixture-rust.sh" "$destination/check-fixture-rust.sh"
cp "$scripts/inspect-fixture-artifacts.py" "$destination/inspect-fixture-artifacts.py"
cp "$scripts/check-fixture-bindings.sh" "$destination/check-fixture-bindings.sh"
if [ -d "$prepared/codeql" ]; then
  ditto "$prepared/codeql" "$destination/codeql"
  cp "$prepared/android-api.jar" "$destination/android-api.jar"
  cp "$scripts/codeql-consumer.gradle" "$destination/codeql-consumer.gradle"
  cp "$scripts/check-codeql-bindings.sh" "$destination/check-codeql-bindings.sh"
  cp "$scripts/check-codeql-startup.sh" "$destination/check-codeql-startup.sh"
fi
mkdir "$destination/generator-tools"
cp "$scripts/generator-cargo.sh" "$destination/generator-tools/cargo"
chmod 0755 "$destination/generator-tools/cargo"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
ls -ld "$destination" "$destination/rust" "$destination/rust/bin" "$destination/rust/bin/rustc"
(cd "$destination" && /usr/bin/find . -type f -print0 \
  | LC_ALL=C /usr/bin/sort -z | /usr/bin/xargs -0 shasum -a 256) \
  > "$prepared/toolchains.sha256"
echo 'PASS: trusted tool copies are root-owned read-only; fixture/cache freezing is not implied'
