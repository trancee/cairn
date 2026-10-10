#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ] || [ "$#" -gt 1 ]; then
  echo 'Usage: sudo bash preserve-journal.sh [canonical|bounded|retention|retention-v2|retention-v3|retention-v4]' >&2
  exit 2
fi
case "${1:-}" in
  '') name=cairn-proof-offline; filename=protected-replay-journal-volume ;;
  canonical) name=cairn-proof-canonical; filename=canonical-replay-journal-volume ;;
  bounded) name=cairn-proof-bounded; filename=bounded-replay-journal-live-verified-volume ;;
  retention) name=cairn-proof-retention; filename=retention-replay-volume ;;
  retention-v2) name=cairn-proof-retention-v2; filename=retention-v2-replay-volume ;;
  retention-v3) name=cairn-proof-retention-v3; filename=retention-v3-replay-volume ;;
  retention-v4) name=cairn-proof-retention-v4; filename=retention-v4-replay-volume ;;
  *) echo 'Unknown proof selection' >&2; exit 2 ;;
esac
test "$(virsh -c qemu:///system domstate "$name")" = 'shut off'
script_directory="$(cd "$(dirname "$0")" && pwd)"
worker=extract-journal.sh
if [[ "${1:-}" = retention* ]]; then
  worker=extract-retention-logs.sh
fi
output="/var/lib/cairn-proof-evidence/bounded-store/$filename"
bash "$script_directory/with-evidence-store.sh" \
  /bin/bash "$script_directory/extract-with-scratch.sh" "$output" \
  /bin/bash "$script_directory/$worker" "$@"
