#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
fixture=$2
test ! -e "$fixture"
mkdir "$fixture" "$fixture/sdk" "$fixture/consumer"
cp "$tools/fixture/settings.gradle.kts" "$tools/fixture/build.gradle.kts" \
  "$tools/fixture/gradle.properties" "$fixture/"
cp "$tools/fixture/sdk/apple.gradle.kts" "$fixture/sdk/"
cp "$tools/fixture/consumer/build.gradle.kts" "$fixture/consumer/"
ln -s "$tools/fixture/sdk/rust" "$fixture/sdk/rust"
