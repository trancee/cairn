#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$#" -eq 1
prepared=$1
tools=/opt/cairn-apple-tools
export CARGO_HOME="$prepared/cargo"
mkdir "$prepared/cargo-inputs"
"$tools/rust/bin/cargo" vendor --locked \
  --manifest-path "$tools/fixture/sdk/rust/Cargo.toml" \
  --sync "$tools/ubique/bindgen/Cargo.toml" \
  --sync "$tools/ubique/runtime/Cargo.toml" \
  "$prepared/cargo-inputs/vendor" \
  > "$prepared/cargo-inputs/vendor.toml"
sed -i '' 's|^directory = .*|directory = "/opt/cairn-apple-tools/cargo-inputs/vendor"|' \
  "$prepared/cargo-inputs/vendor.toml"
echo 'PASS: Cargo vendor prepared from locked fixture and Ubique manifests'
