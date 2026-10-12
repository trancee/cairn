"""Require compiled Kotlin source evidence, not an archived-file inventory."""

import json
from pathlib import Path, PurePosixPath
import sys


class CoverageError(ValueError):
    pass


def verify_sources(report, expected, project):
    if not isinstance(report, dict) or not isinstance(report.get("#select"), dict):
        raise CoverageError("invalid-query-result")
    rows = report["#select"].get("tuples")
    if not isinstance(rows, list):
        raise CoverageError("invalid-query-rows")
    if not isinstance(expected, list) or not expected:
        raise CoverageError("invalid-source-manifest")
    prefix = "proofs/bindings/linux-android/"
    if any(
        not isinstance(path, str) or not path.startswith(prefix)
        or not path.endswith(".kt") or ".." in PurePosixPath(path).parts
        for path in expected
    ) or len(set(expected)) != len(expected):
        raise CoverageError("invalid-source-manifest")
    sources = {}
    roots = ("/opt/cairn-apple-tools/fixture/", str(project) + "/")
    for row in rows:
        if (
            not isinstance(row, list) or len(row) != 2
            or not isinstance(row[0], str) or type(row[1]) is not int
            or row[1] <= 0
        ):
            raise CoverageError("invalid-source-evidence")
        path, lines = row
        for root in roots:
            if path.startswith(root):
                relative = path[len(root):]
                if ".." in PurePosixPath(relative).parts or not relative.endswith(".kt"):
                    raise CoverageError("invalid-source-path")
                sources[prefix + relative] = lines
                break
        else:
            raise CoverageError("unexpected-source-root")
    if set(expected) - sources.keys():
        raise CoverageError("missing-tracked-source")
    if not any(path.startswith(prefix + "sdk/build/uniffi/bindings/") for path in sources):
        raise CoverageError("missing-generated-bindings")
    return sources


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: verify-codeql-sources.py REPORT MANIFEST PROJECT")
    try:
        sources = verify_sources(
            json.loads(Path(sys.argv[1]).read_text()),
            json.loads(Path(sys.argv[2]).read_text()),
            Path(sys.argv[3]),
        )
    except (CoverageError, OSError, UnicodeError, json.JSONDecodeError) as error:
        reason = str(error) if isinstance(error, CoverageError) else type(error).__name__
        raise SystemExit(f"FAIL: Kotlin CodeQL coverage: {reason}") from None
    for path, lines in sorted(sources.items()):
        print(f"KOTLIN-SOURCE: {path} ({lines} lines)")
    print("PASS: compiled Kotlin source coverage verified")


if __name__ == "__main__":
    main()
