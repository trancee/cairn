"""Verify frozen-input SHA-256 manifests with bounded parallel shasum checks.

Each manifest is split into contiguous line chunks that the unchanged
`shasum -a 256 --check` verifies from the frozen root. Chunk output is
concatenated in manifest order, so every log is byte-identical to one serial
check. Every log is written before a failure is reported.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import tempfile


def chunks(lines, count):
    if not lines:
        return [[]]
    size = -(-len(lines) // count)
    return [lines[start:start + size] for start in range(0, len(lines), size)]


def check(root, chunk):
    return subprocess.run(
        ["/usr/bin/shasum", "-a", "256", "--check", str(chunk)],
        cwd=root, capture_output=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--jobs", type=int, required=True)
    parser.add_argument("--check", nargs=2, action="append", required=True,
                        metavar=("MANIFEST", "LOG"), type=Path)
    arguments = parser.parse_args()
    if arguments.jobs < 1:
        parser.error("--jobs must be positive")

    with tempfile.TemporaryDirectory(prefix="cairn-frozen-inputs-") as temporary:
        plan = []
        for number, (manifest, log) in enumerate(arguments.check):
            paths = []
            lines = manifest.read_bytes().splitlines(keepends=True)
            for index, lines in enumerate(chunks(lines, arguments.jobs)):
                path = Path(temporary) / f"{number}-{index}.sha256"
                path.write_bytes(b"".join(lines))
                paths.append(path)
            plan.append((log, paths))
        with ThreadPoolExecutor(max_workers=arguments.jobs) as pool:
            results = [
                (log, [pool.submit(check, arguments.root, path) for path in paths])
                for log, paths in plan
            ]
            failed = False
            for log, futures in results:
                completed = [future.result() for future in futures]
                log.write_bytes(b"".join(result.stdout for result in completed))
                for result in completed:
                    sys.stderr.buffer.write(result.stderr)
                    failed |= result.returncode != 0
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
