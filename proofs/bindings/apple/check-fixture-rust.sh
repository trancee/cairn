#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
target=$2
case "$target" in
  aarch64-apple-darwin|aarch64-apple-ios|aarch64-apple-ios-sim) ;;
  *) echo "FAIL: unsupported fixture Rust target: $target" >&2; exit 2 ;;
esac
export PATH="$tools/rust/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export CARGO_HOME="$HOME/cargo-offline"
export CARGO_NET_OFFLINE=true
export CARGO_TARGET_DIR="$HOME/fixture-cargo-target"
export IPHONEOS_DEPLOYMENT_TARGET=15.0
"$tools/rust/bin/cargo" --config "$tools/cargo-inputs/vendor.toml" \
  build --locked --offline --manifest-path "$tools/fixture/sdk/rust/Cargo.toml" \
  --lib --target "$target"
test -s "$CARGO_TARGET_DIR/$target/debug/libcairn_binding_smoke.a"
echo "PASS: isolated locked offline shared-fixture Rust compilation $target; no FFI calls"
