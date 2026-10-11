#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
export PATH="$tools/rust/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CARGO_HOME="$HOME/cargo-offline"
export CARGO_NET_OFFLINE=true
export CARGO_TARGET_DIR="$HOME/bindgen-cargo-target"
"$tools/rust/bin/cargo" --config "$tools/cargo-inputs/vendor.toml" \
  build --locked --offline --manifest-path "$tools/ubique/bindgen/Cargo.toml" \
  --bin uniffi-bindgen-kotlin-multiplatform
test -x "$CARGO_TARGET_DIR/debug/uniffi-bindgen-kotlin-multiplatform"
echo 'PASS: isolated locked offline pinned Ubique bindgen compilation; no generated FFI calls'
