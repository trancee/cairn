#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../core"

cargo build --manifest-path ct/Cargo.toml --release --locked
binary="${CARGO_TARGET_DIR:-ct/target}/release/cairn-ct"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for control in negative-control negative-index; do
  set +e
  valgrind --tool=memcheck --error-exitcode=42 --log-file="$log" \
    "$binary" "$control"
  status=$?
  set -e
  if [[ "$status" != 42 ]] || ! grep -Eq \
    'Conditional jump or move depends on uninitialised value|Use of uninitialised value' "$log"; then
    cat "$log"
    echo "$control was not detected" >&2
    exit 1
  fi
done

for backend in aws-lc reference; do
  valgrind --tool=memcheck --error-exitcode=42 "$binary" "$backend"
done
