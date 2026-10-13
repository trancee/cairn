import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import ssl
import statistics
import subprocess
import sys
import time


def timed(command, root):
    started = time.monotonic()
    result = subprocess.run(command, cwd=root, check=True, capture_output=True, timeout=120)
    return time.monotonic() - started, result.stdout


def main():
    parser = argparse.ArgumentParser(description="Compare manifests with the committed pipeline")
    parser.add_argument("root", type=Path)
    parser.add_argument("--repetitions", type=int, default=3)
    args = parser.parse_args()
    if args.repetitions < 3 or not args.root.is_dir() or args.root.is_symlink():
        parser.error("requires a real input directory and at least three repetitions")
    args.root = args.root.resolve()
    scripts = Path(__file__).resolve().parent
    repository = scripts.parents[2]
    baseline_commit = "a6b076793ceb33a20bf518ff7edf5c6857c2c3a2"
    baseline_source = subprocess.run([
        "git", "-C", str(repository), "show",
        baseline_commit + ":proofs/bindings/apple/freeze-toolchains.sh",
    ], check=True, capture_output=True).stdout
    baseline_command = [
        "/bin/bash", "-o", "pipefail", "-c",
        "/usr/bin/find . -type f -print0 | LC_ALL=C /usr/bin/sort -z"
        " | /usr/bin/xargs -0 shasum -a 256",
    ]
    candidate_command = [sys.executable, "-I", str(scripts / "tool-input-manifest.py"), str(args.root)]
    baseline_times = []
    candidate_times = []
    expected = None
    for repetition in range(args.repetitions):
        commands = [("baseline", baseline_command), ("candidate", candidate_command)]
        if repetition % 2:
            commands.reverse()
        outputs = {}
        for name, command in commands:
            elapsed, output = timed(command, args.root)
            (baseline_times if name == "baseline" else candidate_times).append(elapsed)
            outputs[name] = output
        if outputs["baseline"] != outputs["candidate"]:
            raise SystemExit("FAIL: benchmark manifests differ")
        if expected is not None and outputs["baseline"] != expected:
            raise SystemExit("FAIL: benchmark inputs changed between repetitions")
        expected = outputs["baseline"]
    ratio = statistics.median(candidate_times) / statistics.median(baseline_times)
    print(json.dumps({
        "baseline_commit": baseline_commit,
        "baseline_source_sha256": hashlib.sha256(baseline_source).hexdigest(),
        "candidate_source_sha256": hashlib.sha256(
            (scripts / "tool-input-manifest.py").read_bytes()
        ).hexdigest(),
        "environment": {
            "platform": platform.platform(), "python": sys.version,
            "openssl": ssl.OPENSSL_VERSION, "cpu_count": os.cpu_count(),
        },
        "file_count": outputs["baseline"].count(b"\n"),
        "byte_count": sum(
            path.stat().st_size for path in args.root.rglob("*")
            if path.is_file() and not path.is_symlink()
        ),
        "manifest_sha256": hashlib.sha256(outputs["baseline"]).hexdigest(),
        "baseline_seconds": baseline_times, "candidate_seconds": candidate_times,
        "median_ratio": ratio, "maximum_ratio": 0.9,
        "manifests_identical": True,
    }, indent=2))
    if ratio > 0.9:
        raise SystemExit("FAIL: manifest generation has not improved by at least 10%")
    print("PASS: identical manifests; generation improved by at least 10%")


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f"FAIL: manifest benchmark: {type(error).__name__}")
