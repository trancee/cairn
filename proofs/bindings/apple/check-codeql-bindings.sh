#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
test "$tools" = /opt/cairn-apple-tools
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin"
codeql="$tools/codeql/codeql"
database="$HOME/codeql-java"
test ! -e "$database"
"$codeql" database init "$database" --language=java --build-mode=manual \
  --source-root="$tools/fixture"
"$codeql" database trace-command "$database" -- \
  /bin/bash "$tools/check-fixture-bindings.sh" "$tools" :consumer:interopSmoke --codeql
echo 'PASS: fixture build traced into the strict offline Kotlin CodeQL database'
