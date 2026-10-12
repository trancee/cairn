"""Map frozen and generated fixture locations to their owning repository paths."""

import copy
import json
from pathlib import Path
import posixpath
import re
import sys
from urllib.parse import quote, unquote, urljoin, urlsplit


class MappingError(ValueError):
    pass


def normalize_sarif(document, project):
    if (
        not isinstance(document, dict) or document.get("version") != "2.1.0"
        or not isinstance(document.get("runs"), list) or not document["runs"]
    ):
        raise MappingError("invalid-sarif-document")
    mapped = copy.deepcopy(document)
    roots = ("/opt/cairn-apple-tools/fixture/", str(project) + "/")
    prefix = "proofs/bindings/linux-android/"
    for run in mapped["runs"]:
        if (
            not isinstance(run, dict) or not isinstance(run.get("tool"), dict)
            or not isinstance(run["tool"].get("driver"), dict)
            or run["tool"]["driver"].get("name") != "CodeQL"
            or not isinstance(run.get("results"), list)
        ):
            raise MappingError("invalid-codeql-run")
        bases = run.get("originalUriBaseIds", {})
        if not isinstance(bases, dict):
            raise MappingError("invalid-uri-bases")

        def map_location(location):
            uri = location.get("uri")
            if not isinstance(uri, str) or re.search(r"%(?![0-9a-fA-F]{2})", uri):
                raise MappingError("invalid-artifact-uri")
            base_id = location.get("uriBaseId")
            if base_id is not None and not isinstance(base_id, str):
                raise MappingError("invalid-uri-base")
            base = bases.get(base_id, {})
            if "uriBaseId" in location and (
                not isinstance(base, dict) or not isinstance(base.get("uri"), str)
            ):
                raise MappingError("unknown-uri-base")
            resolved = urlsplit(urljoin(base.get("uri", "file://" + roots[0]), uri))
            if (
                resolved.scheme != "file" or resolved.netloc
                or resolved.query or resolved.fragment
            ):
                raise MappingError("unsupported-artifact-uri")
            path = posixpath.normpath(unquote(resolved.path, errors="strict"))
            for root in roots:
                if path == root.rstrip("/") or path.startswith(root):
                    relative = path[len(root):] if path.startswith(root) else ""
                    location["uri"] = quote(prefix + relative, safe="/")
                    location.pop("uriBaseId", None)
                    return
            raise MappingError("unmapped-artifact-path")

        def visit(value, key=""):
            if isinstance(value, dict):
                if key == "originalUriBaseIds":
                    return
                if "uri" in value and (
                    "uriBaseId" in value or key in (
                        "artifactLocation", "location", "workingDirectory",
                        "logFileLocation", "logFileDirectory",
                    )
                ):
                    map_location(value)
                for child_key, child in value.items():
                    visit(child, child_key)
            elif isinstance(value, list):
                for child in value:
                    visit(child, key)

        visit(run)
        run.pop("originalUriBaseIds", None)
    return mapped


def main():
    if len(sys.argv) != 4:
        raise SystemExit("Usage: normalize-codeql-sarif.py INPUT OUTPUT PROJECT")
    try:
        result = normalize_sarif(
            json.loads(Path(sys.argv[1]).read_text()), Path(sys.argv[3]),
        )
        Path(sys.argv[2]).write_text(json.dumps(result))
    except (MappingError, OSError, UnicodeError, json.JSONDecodeError, RecursionError) as error:
        reason = str(error) if isinstance(error, MappingError) else type(error).__name__
        raise SystemExit(f"FAIL: Kotlin CodeQL SARIF mapping: {reason}") from None
    print("PASS: Kotlin CodeQL SARIF locations mapped to owning repository paths")


if __name__ == "__main__":
    main()
