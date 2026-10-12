#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 1
tools=$1
test "$tools" = /opt/cairn-apple-tools
export JAVA_HOME="$tools/compiler-jdk"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin"
work="$HOME/codeql-startup"
mkdir "$work"
printf 'public class Fixture { public static int value() { return 1; } }\n' \
  > "$work/Fixture.java"
codeql="$tools/codeql/codeql"
"$codeql" database init "$work/database" --language=java --build-mode=manual \
  --source-root="$tools/fixture"
"$codeql" database trace-command "$work/database" -- \
  "$JAVA_HOME/bin/javac" -d "$work" "$work/Fixture.java"
"$codeql" database finalize "$work/database" --threads=2 --ram=2048
echo 'PASS: trusted minimal CodeQL compiler/import startup; not Kotlin coverage proof'
