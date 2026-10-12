#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$#" -eq 1
prepared=$1
tools=/opt/cairn-apple-tools
mkdir "$prepared/native-home"
/usr/bin/env -i HOME="$prepared/native-home" TMPDIR="$prepared/native-home" \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin LANG=en_US.UTF-8 \
  /bin/bash "$tools/check-native-cinterop.sh" "$tools"
echo 'PASS: trusted Native dependency preparation through actual cinterop'
