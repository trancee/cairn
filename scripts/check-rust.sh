#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../core"

cargo fmt --all --check
cargo fmt --manifest-path fuzz/Cargo.toml --all --check
cargo fmt --manifest-path ct/Cargo.toml --all --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
for backend in aws-lc reference; do
  cargo clippy -p cairn-crypto --all-targets --no-default-features --features "$backend" --locked -- -D warnings
  cargo test -p cairn-crypto --no-default-features --features "$backend" --locked
done
cargo deny check
cargo deny --manifest-path fuzz/Cargo.toml --config deny.toml check
cargo deny --manifest-path ct/Cargo.toml --config deny.toml check
