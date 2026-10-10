#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run this trusted bootstrap as root in the networkless disposable guest' >&2
  exit 2
fi
python3 - <<'NETWORK'
from pathlib import Path

assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
NETWORK
saved=/opt/cairn-binding-seeds/final-image-inputs-e75437d
scratch=/srv/cairn-generator-scratch
(cd "$saved" && sha256sum --check SHA256SUMS)
if mountpoint -q "$scratch"; then
  echo 'Scratch already mounted; refusing retained-state replay' >&2
  exit 2
fi
install -d -o cairn-build -g cairn-build -m 0700 "$scratch"
mount -t tmpfs -o size=6G,nosuid,nodev,mode=0700,uid=cairn-build,gid=cairn-build \
  cairn-proof-scratch "$scratch"
install -d -o cairn-build -g cairn-build -m 0755 \
  "$scratch/android-interop" "$scratch/fixture-cargo" "$scratch/kmp-gradle-cache"
tar -xzf "$saved/fixture-source.tar.gz" -C "$scratch/android-interop"
tar -xzf "$saved/cargo-registry.tar.gz" -C "$scratch/fixture-cargo"
tar -xzf "$saved/gradle-modules.tar.gz" -C "$scratch/kmp-gradle-cache"
chown -R cairn-build:cairn-build "$scratch"
bash "$scratch/android-interop/build-offline.sh"
bash "$saved/run-isolated-android.sh"
echo 'PASS: cold disposable guest build and fresh Android runtime'
