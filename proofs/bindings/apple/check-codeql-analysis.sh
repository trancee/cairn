#!/usr/bin/env bash
set -euo pipefail
test "$#" -eq 2
tools=$1
python=$2
test "$tools" = /opt/cairn-apple-tools
export JAVA_HOME="$tools/daemon-jdk"
export PATH="$JAVA_HOME/bin:/usr/bin:/bin"
codeql="$tools/codeql/codeql"
database="$HOME/codeql-java"
inventory=$(/usr/bin/find "$tools/codeql/qlpacks/codeql/java-queries" \
  -name CairnSourceInventory.ql -type f)
test -f "$inventory"
options=(--threads=2 --ram=4096 --common-caches="$HOME/codeql-common" \
  --compilation-cache="$HOME/codeql-compilation" --no-default-compilation-cache)
"$codeql" query run "${options[@]}" --database="$database" \
  --output="$HOME/kotlin-sources.bqrs" "$inventory"
mkdir "$HOME/codeql-analysis"
"$codeql" bqrs decode --format=json --output="$HOME/codeql-analysis/kotlin-sources.json" \
  "$HOME/kotlin-sources.bqrs"
"$python" -I "$tools/verify-codeql-sources.py" \
  "$HOME/codeql-analysis/kotlin-sources.json" "$tools/kotlin-sources.json" \
  "$HOME/fixture-targets" "$HOME/repository-build"
"$codeql" database analyze "${options[@]}" --no-download \
  --format=sarifv2.1.0 --output="$HOME/codeql-analysis/java-kotlin-raw.sarif" \
  --sarif-category=cairn/java-kotlin --sublanguage-file-coverage \
  "$database" codeql/java-queries:codeql-suites/java-code-scanning.qls
"$python" -I "$tools/normalize-codeql-sarif.py" \
  "$HOME/codeql-analysis/java-kotlin-raw.sarif" "$HOME/codeql-analysis/java-kotlin.sarif" \
  "$HOME/fixture-targets" "$HOME/repository-build"
echo 'PASS: bundled Java/Kotlin CodeQL security suite completed offline'
