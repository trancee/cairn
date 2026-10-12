#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
export PATH="$tools/rust/bin:/usr/bin:/bin"
export CARGO_HOME="$HOME/cargo-offline"
export CARGO_NET_OFFLINE=true
export CARGO_TARGET_DIR="$HOME/cargo-metadata-target"
config="$tools/cargo-inputs/vendor.toml"
if [ ! -f "$config" ]; then
  echo 'FAIL: immutable Cargo vendor configuration is missing' >&2
  exit 1
fi
for manifest in "$tools/fixture/sdk/rust/Cargo.toml" \
  "$tools/ubique/bindgen/Cargo.toml" "$tools/ubique/runtime/Cargo.toml"; do
  for target in aarch64-apple-darwin aarch64-apple-ios aarch64-apple-ios-sim; do
    "$tools/rust/bin/cargo" --config "$config" metadata --format-version 1 \
      --locked --offline --filter-platform "$target" --manifest-path "$manifest" \
      > "$HOME/cargo-metadata.json"
    echo "PASS: locked offline Cargo metadata $(basename "$(dirname "$manifest")") $target"
  done
done
echo 'PASS: all Apple Cargo inputs resolve from the immutable vendor seed'
