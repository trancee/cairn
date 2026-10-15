"""Paired native-guard performance measurement, not default cutover."""

import argparse
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from equations.maude_runner import GuardError, run_guarded_tamarin, unique_fields
from equations.maude_candidate import source_identity
from replay import ReplayError, run


MODELS = Path(__file__).resolve().parents[2]
WORKLOADS = {
    "full-export": (
        MODELS / "ratchet.spthy",
        (
            "aaaf873a9b7baff6fbf209f1cf87088581552498ade6f9a5e471ee2b5ea6fb5d",
            "1b66b2a76902af6c98de7b22edbe6f4d8fddc27cd2adb580db6d5eff639dbd48",
        ),
    ),
    "startup": (
        Path(__file__).with_name("derivation.spthy"),
        ("ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64",),
    ),
}


def check_budget(report: object, workload: str) -> None:
    if not isinstance(report, dict):
        raise GuardError("malformed native guard performance report")
    for field in ("platform", "architecture", "compiler", "baseline"):
        if not isinstance(report.get(field), str) or not report[field]:
            raise GuardError("missing native guard comparison environment")
    for field in ("logical_cpus", "physical_memory_bytes"):
        if type(report.get(field)) is not int or report[field] <= 0:
            raise GuardError("invalid native guard comparison hardware")
    for field, width in (("baseline_revision", 40), ("proxy_sha256", 64)):
        value = report.get(field)
        if not isinstance(value, str) or re.fullmatch(f"[0-9a-f]{{{width}}}", value) is None:
            raise GuardError("invalid native guard comparison identity")
    model, expected_exports = WORKLOADS[workload]
    if (
        report.get("workload_name") != workload
        or report.get("method") != "three alternating paired runs"
        or report.get("source_id") != source_identity()
        or report.get("model_sha256") != hashlib.sha256(model.read_bytes()).hexdigest()
        or report.get("export_sha256") not in expected_exports
    ):
        raise GuardError("incompatible native guard workload, method or source evidence")
    samples = report.get("seconds")
    if not isinstance(samples, dict) or set(samples) != {"baseline", "compiled_guard"}:
        raise GuardError("malformed native guard timing samples")
    medians: dict[str, Decimal] = {}
    for label, values in samples.items():
        if not isinstance(values, list) or len(values) != 3:
            raise GuardError("native guard acceptance requires three paired samples")
        elapsed = []
        for value in values:
            if type(value) not in (int, float):
                raise GuardError("invalid native guard elapsed time")
            number = Decimal(str(value))
            if not number.is_finite() or number <= 0:
                raise GuardError("invalid native guard elapsed time")
            elapsed.append(number)
        medians[label] = statistics.median(elapsed)
    baseline = medians["baseline"]
    maximum = baseline * Decimal("1.10") if workload == "full-export" else baseline + Decimal("0.050")
    if medians["compiled_guard"] > maximum:
        threshold = "10% full-export" if workload == "full-export" else "50 ms startup-only"
        raise GuardError(f"native guard exceeds approved {threshold} budget")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--proxy", type=Path)
    mode.add_argument("--check-report", type=Path)
    parser.add_argument("--workload", choices=tuple(WORKLOADS), default="full-export")
    parser.add_argument("--rounds", type=int, choices=(1, 3), default=3)
    arguments = parser.parse_args()
    if arguments.check_report is not None:
        try:
            report = json.loads(arguments.check_report.read_text(), object_pairs_hook=unique_fields)
        except (ValueError, RecursionError) as error:
            raise GuardError("malformed native guard performance report") from error
        check_budget(report, arguments.workload)
        print(f"PASS: native guard {arguments.workload} median meets its approved budget")
        return 0
    proxy = arguments.proxy.resolve(strict=True)
    model, expected_exports = WORKLOADS[arguments.workload]
    identity = source_identity()
    proxy_digest = hashlib.sha256(proxy.read_bytes()).hexdigest()
    subprocess.run(["git", "diff", "--quiet", "HEAD", "--", "docs/spec/models/replay.py"], check=True)
    command = [
        "tamarin-prover", str(model), "--quit-on-warning",
        "--derivcheck-timeout=60", "--output-module=msr",
    ]
    timings: dict[str, list[float]] = {"baseline": [], "compiled_guard": []}
    digest = None
    for index in range(arguments.rounds):
        order = ("baseline", "compiled_guard") if index % 2 == 0 else ("compiled_guard", "baseline")
        for label in order:
            started = time.monotonic()
            output = (
                run(command, 120) if label == "baseline"
                else run_guarded_tamarin(command, 120, candidate=proxy)
            )
            timings[label].append(time.monotonic() - started)
            actual = hashlib.sha256(output.encode()).hexdigest()
            if actual not in expected_exports:
                raise GuardError(
                    f"unreviewed {label} export: expected {', '.join(expected_exports)}, observed {actual}",
                )
            if digest is not None and actual != digest:
                raise GuardError("native guard and committed-baseline exports differ")
            digest = actual
    if source_identity() != identity or hashlib.sha256(proxy.read_bytes()).hexdigest() != proxy_digest:
        raise GuardError("native guard source or executable changed during measurement")
    medians = {label: statistics.median(values) for label, values in timings.items()}
    report = {
        "scope": "native guard performance evidence, not default cutover or native FVP acceptance",
        "workload_name": arguments.workload,
        "workload": [command[0], str(model.relative_to(MODELS)), *command[2:]],
        "platform": platform.platform(),
        "python": platform.python_version(),
        "architecture": platform.machine(),
        "logical_cpus": os.cpu_count(),
        "physical_memory_bytes": os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE"),
        "baseline_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "baseline": "unchanged committed replay.run, direct pinned Tamarin/Maude",
        "method": "three alternating paired runs" if arguments.rounds == 3 else "one screening pair, not acceptance",
        "seconds": timings,
        "median_seconds": medians,
        "change_percent": 100 * (medians["compiled_guard"] / medians["baseline"] - 1),
        "additional_milliseconds": 1000 * (medians["compiled_guard"] - medians["baseline"]),
        "source_id": identity,
        "model_sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
        "export_sha256": digest,
        "proxy_sha256": proxy_digest,
        "compiler": subprocess.check_output(["rustc", "--version"], text=True).strip(),
        "budget_checked": arguments.rounds == 3,
        "budget_passed": False,
    }
    if arguments.rounds == 3:
        try:
            check_budget(report, arguments.workload)
        except GuardError:
            print(json.dumps(report, indent=2))
            raise
        report["budget_passed"] = True
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (GuardError, ReplayError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, subprocess.CalledProcessError):
        print("FAIL: native guard benchmark tool, source, report or baseline unavailable", file=sys.stderr)
        sys.exit(1)
