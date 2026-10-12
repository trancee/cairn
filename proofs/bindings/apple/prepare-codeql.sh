#!/usr/bin/env bash
set -euo pipefail
test "${GITHUB_ACTIONS:-}" = true
test "$#" -eq 1
prepared=$1
test -d "$prepared"
test ! -e "$prepared/codeql"
curl --fail --silent --show-error --location \
  https://github.com/github/codeql-action/releases/download/codeql-bundle-v2.27.2/codeql-bundle-osx64.tar.gz \
  -o "$prepared/codeql.tar.gz"
printf '%s  %s\n' bdd42bab471ed16277048b35b9be7264d07bd19b7391c37d30c74e9555e61e92 \
  "$prepared/codeql.tar.gz" | shasum -a 256 --check
tar -xzf "$prepared/codeql.tar.gz" -C "$prepared"
test -x "$prepared/codeql/codeql"
curl --fail --silent --show-error --location \
  https://dl.google.com/android/repository/platform-37.0_r02.zip \
  -o "$prepared/android-api.zip"
printf '%s  %s\n' 840b23e827f96e64aea4c89a1194aac3dc5f6bad37edb231c5c795d890330e8d \
  "$prepared/android-api.zip" | shasum -a 256 --check
unzip -q "$prepared/android-api.zip" -d "$prepared/android-api"
android_jar=$(/usr/bin/find "$prepared/android-api" -name android.jar -type f)
test -f "$android_jar"
cp "$android_jar" "$prepared/android-api.jar"
echo 'PASS: checksum-verified CodeQL and Android API inputs prepared; no Kotlin compilation'
