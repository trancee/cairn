#!/usr/bin/env bash
set -euo pipefail

profile=evidence
if [ "${1:-}" = --profile ] && [ "$#" -ge 2 ]; then
  profile=$2
  shift 2
fi
case "$profile" in
  evidence) capacity=1073741824 ;;
  appliance) capacity=4294967296 ;;
  store) capacity=8589934592 ;;
  *) echo 'FAIL: unknown evidence volume profile' >&2; exit 2 ;;
esac
if [ "$(id -u)" -ne 0 ] || [ "$#" -lt 2 ]; then
  echo 'Usage: sudo bash bounded-evidence.sh [--profile evidence|appliance|store] OUTPUT COMMAND [ARG...]' >&2
  exit 2
fi
output=$1
shift
image="$output.ext4"
status="$output.status"
if [ "${output:0:1}" != / ] || [ -e "$output" ] || [ -L "$output" ] ||
   [ -e "$image" ] || [ -L "$image" ] || [ -e "$status" ] || [ -L "$status" ]; then
  echo 'FAIL: evidence output must be an unused absolute path' >&2
  exit 2
fi
umask 077
set -o noclobber
: > "$status"
printf 'INCOMPLETE\n' >| "$status"
: > "$image"
fallocate -l "$capacity" "$image"
mkfs.ext4 -q -m 0 "$image"
mkdir -m 0700 -- "$output"
mounted=0
finish() {
  result=$?
  trap - EXIT
  if [ "$mounted" = 1 ]; then
    if ! umount "$output"; then
      printf 'INCOMPLETE: unmount failed\n' >| "$status"
      echo "FAIL: evidence volume still mounted: $output" >&2
      exit 1
    fi
  fi
  if [ "$result" -eq 0 ]; then
    printf 'COMPLETE\n' >| "$status"
    echo "PASS: bounded evidence retained at $image"
  else
    printf 'INCOMPLETE: command failed (%s)\n' "$result" >| "$status"
    echo "FAIL: incomplete evidence retained at $image" >&2
  fi
  exit "$result"
}
trap finish EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
mount -o loop,nosuid,nodev,noexec "$image" "$output"
mounted=1
chmod 0700 "$output"
(
  cd "$output"
  "$@"
)
