#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$(id -u)" -eq 0
test "$#" -eq 4
prepared=$1
rust=$2
daemon=$3
compiler=$4
destination=/opt/cairn-apple-tools
test ! -e "$destination"
umask 022
mkdir "$destination"
ditto "$prepared/gradle-9.7.0" "$destination/gradle"
ditto "$rust" "$destination/rust"
ditto "$daemon" "$destination/daemon-jdk"
ditto "$compiler" "$destination/compiler-jdk"
chown -R root:wheel "$destination"
chmod -R a+rX,a-w "$destination"
ls -ld "$destination" "$destination/rust" "$destination/rust/bin" "$destination/rust/bin/rustc"
(cd "$destination" && /usr/bin/find . -type f -print0 \
  | LC_ALL=C /usr/bin/sort -z | /usr/bin/xargs -0 shasum -a 256) \
  > "$prepared/toolchains.sha256"
echo 'PASS: trusted tool copies are root-owned read-only; fixture/cache freezing is not implied'
