#!/usr/bin/env bash
# Runs as the probe UID: copies the root-owned, read-only warm Gradle cache
# seed into the probe's own home without replacing entries it already wrote.
set -euo pipefail
test "$#" -eq 2
seed=$1
home=$2
test -d "$seed"
test -d "$home"
mkdir -p "$home/caches"
/usr/bin/rsync -rlpt --ignore-existing "$seed/" "$home/caches/"
/bin/chmod -R u+w "$home/caches"
echo 'PASS: warm Gradle home seeded from frozen read-only transforms'
