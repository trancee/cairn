#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../core"

cargo fmt --all --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
for backend in aws-lc reference; do
  cargo clippy -p cairn-crypto --all-targets --no-default-features --features "$backend" --locked -- -D warnings
  cargo test -p cairn-crypto --no-default-features --features "$backend" --locked
done
cargo deny check
