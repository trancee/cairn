"""Require compiled Kotlin source evidence, not an archived-file inventory."""

import json
from pathlib import Path
import sys


class CoverageError(ValueError):
    pass


FIXTURE = "proofs/bindings/linux-android/"
BINDINGS = "sdk/build/uniffi/bindings/"


def source_roots(project, repository):
    # Frozen read-only sources and writable build projects of both Gradle builds.
    return (
        ("/opt/cairn-apple-tools/fixture/", FIXTURE),
        (str(project) + "/", FIXTURE),
        ("/opt/cairn-apple-tools/repository-inputs/source/", ""),
        (str(repository) + "/", ""),
    )


def repository_path(path):
    return (
        isinstance(path, str) and path.endswith(".kt")
        and all(part not in ("", ".", "..") for part in path.split("/"))
    )


def verify_sources(report, expected, project, repository):
    if not isinstance(report, dict) or not isinstance(report.get("#select"), dict):
        raise CoverageError("invalid-query-result")
    rows = report["#select"].get("tuples")
    if not isinstance(rows, list):
        raise CoverageError("invalid-query-rows")
    if not isinstance(expected, list) or not expected:
        raise CoverageError("invalid-source-manifest")
    if not all(repository_path(path) for path in expected) or len(set(expected)) != len(expected):
        raise CoverageError("invalid-source-manifest")
    sources = {}
    roots = source_roots(project, repository)
    for row in rows:
        if (
            not isinstance(row, list) or len(row) != 2
            or not isinstance(row[0], str) or type(row[1]) is not int
            or row[1] <= 0
        ):
            raise CoverageError("invalid-source-evidence")
        path, lines = row
        for root, prefix in roots:
            if path.startswith(root):
                relative = path[len(root):]
                if not repository_path(relative):
                    raise CoverageError("invalid-source-path")
                sources[prefix + relative] = lines
                break
        else:
            raise CoverageError("unexpected-source-root")
    if set(expected) - sources.keys():
        raise CoverageError("missing-tracked-source")
    for prefix in (FIXTURE, ""):
        if not any(path.startswith(prefix + BINDINGS) for path in sources):
            raise CoverageError("missing-generated-bindings")
    return sources


def main():
    if len(sys.argv) != 5:
        raise SystemExit("Usage: verify-codeql-sources.py REPORT MANIFEST PROJECT REPOSITORY")
    try:
        sources = verify_sources(
            json.loads(Path(sys.argv[1]).read_text()),
            json.loads(Path(sys.argv[2]).read_text()),
            Path(sys.argv[3]),
            Path(sys.argv[4]),
        )
    except (CoverageError, OSError, UnicodeError, json.JSONDecodeError) as error:
        reason = str(error) if isinstance(error, CoverageError) else type(error).__name__
        raise SystemExit(f"FAIL: Kotlin CodeQL coverage: {reason}") from None
    for path, lines in sorted(sources.items()):
        print(f"KOTLIN-SOURCE: {path} ({lines} lines)")
    print("PASS: compiled Kotlin source coverage verified")


if __name__ == "__main__":
    main()
