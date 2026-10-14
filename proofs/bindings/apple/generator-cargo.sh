#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = install ]; then
  shift
  source_matches=0
  previous=
  for argument in "$@"; do
    if [ "$previous" = --path ] && [ "$argument" = /opt/cairn-apple-tools/ubique/bindgen ]; then
      source_matches=$((source_matches + 1))
    fi
    case "$argument" in
      --debug|--profile|--profile=*)
        echo 'FAIL: generator profile must be owned by the approved adapter' >&2
        exit 2 ;;
      --target|--target=*|--target-dir|--target-dir=*)
        echo 'FAIL: generator compilation context must be owned by the proof' >&2
        exit 2 ;;
    esac
    previous=$argument
  done
  if [ "$source_matches" -ne 1 ]; then
    echo 'FAIL: debug installation is restricted to the pinned generator source' >&2
    exit 2
  fi
  echo 'INFO: approved debug-profile generator installation; SDK profiles unchanged'
  exec /opt/cairn-apple-tools/rust/bin/cargo install --debug --target aarch64-apple-darwin "$@"
fi
exec /opt/cairn-apple-tools/rust/bin/cargo "$@"
