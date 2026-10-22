#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 2
prepared=$1
rust=$2
scripts="$(cd "$(dirname "$0")" && pwd -P)"
destination=/opt/cairn-apple-tools/repository-inputs
test -d /opt/cairn-apple-tools/codeql
test ! -e "$destination"
test "$("$rust/bin/rustc" --version | cut -d' ' -f2)" = 1.99.0
ditto --clone "$prepared/repository-inputs" "$destination"
ditto --clone "$rust" "$destination/rust"
mkdir "$destination/generator-tools"
# The fixture's generator adapter, bound to the root build's pinned toolchain and generator.
sed -e 's|/opt/cairn-apple-tools/rust/bin/cargo|/opt/cairn-apple-tools/repository-inputs/rust/bin/cargo|' \
  -e 's|/opt/cairn-apple-tools/ubique/bindgen|/opt/cairn-apple-tools/repository-inputs/ubique/bindgen|' \
  "$scripts/generator-cargo.sh" > "$destination/generator-tools/cargo"
grep -Fq "$destination/rust/bin/cargo install --debug" "$destination/generator-tools/cargo"
grep -Fq "\"$destination/ubique/bindgen\"" "$destination/generator-tools/cargo"
chmod 0755 "$destination/generator-tools/cargo"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
"$(xcrun --find python3)" -I "$scripts/tool-input-manifest.py" --jobs "$(sysctl -n hw.ncpu)" \
  /opt/cairn-apple-tools repository-inputs \
  > "$prepared/repository-inputs.sha256"
echo 'PASS: root Gradle build inputs are root-owned read-only'
