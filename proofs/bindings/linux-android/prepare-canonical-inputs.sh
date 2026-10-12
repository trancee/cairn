#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo 'Run trusted canonical-input preparation as root' >&2
  exit 2
fi
saved=/opt/cairn-binding-seeds/final-image-inputs-e75437d
canonical="$saved/canonical-inputs"
test ! -e "$canonical"
(cd "$saved" && sha256sum --check SHA256SUMS)
umask 022
install -d -o root -g root -m 0755 \
  "$canonical/fixture" "$canonical/cargo" "$canonical/gradle"
tar -xzf "$saved/fixture-source.tar.gz" -C "$canonical/fixture"
tar -xzf "$saved/cargo-registry.tar.gz" -C "$canonical/cargo"
tar -xzf "$saved/gradle-modules.tar.gz" -C "$canonical/gradle"
chown -R root:root "$canonical"
(cd "$canonical" &&
  LC_ALL=C find fixture cargo gradle -type f -print0 |
  LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
chmod -R a-w "$canonical"
echo 'PASS: canonical source and dependency contents prepared root-owned'
