import argparse
import hashlib
import os
from pathlib import Path
import stat
import sys


class ManifestError(ValueError):
    pass


def walk_error(error: OSError) -> None:
    raise error


def create_manifest(root: Path, scope: str = ".") -> bytes:
    if not root.is_dir() or root.is_symlink():
        raise ManifestError("invalid-root")
    relative = Path(scope)
    if (
        relative.is_absolute() or ".." in relative.parts
        or str(relative) != scope or scope.startswith("-")
    ):
        raise ManifestError("invalid-scope")
    directory = root
    for part in relative.parts:
        directory /= part
        if not directory.is_dir() or directory.is_symlink():
            raise ManifestError("invalid-scope")
    paths = []
    for current, _, filenames in os.walk(directory, onerror=walk_error, followlinks=False):
        for filename in filenames:
            path = Path(current) / filename
            if stat.S_ISREG(path.lstat().st_mode):
                paths.append(path)
    if not paths:
        raise ManifestError("no-regular-inputs")
    paths.sort(key=lambda path: os.fsencode(path.relative_to(root)))
    records = []
    for path in paths:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        name = os.fsencode(path.relative_to(root))
        if scope == ".":
            name = b"./" + name
        escaped = b"\\" in name or b"\n" in name
        name = name.replace(b"\\", b"\\\\").replace(b"\n", b"\\n")
        records.append(
            (b"\\" if escaped else b"") + digest.hexdigest().encode("ascii")
            + b"  " + name + b"\n"
        )
    return b"".join(records)


def main() -> int:
    parser = argparse.ArgumentParser(description="Create frozen-input SHA-256 manifests")
    parser.add_argument("root", type=Path)
    parser.add_argument("scope", nargs="?", default=".")
    args = parser.parse_args()
    try:
        manifest = create_manifest(args.root, args.scope)
    except (ManifestError, OSError) as error:
        reason = str(error) if isinstance(error, ManifestError) else type(error).__name__
        print(f"FAIL: tool-input manifest: {reason}", file=sys.stderr)
        return 1
    sys.stdout.buffer.write(manifest)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
