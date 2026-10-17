"""One failure-only RTS/CPU screening pair, never a budget retry or acceptance."""

import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import stat
import subprocess
import sys
import time

from experiment import BudgetExceeded, WORKLOADS, check_budget, measure
from equations.maude_runner import GuardError, unique_fields
from replay import ReplayError
from tamarin_profile import MAXIMUM_STATISTICS_BYTES, RuntimeProfileError


JOB_SECONDS = 900
DIAGNOSTIC_SECONDS = 300
RETENTION_RESERVE_SECONDS = 60


def remaining_seconds(started: float, now: float) -> float:
    if (
        type(started) not in (int, float) or type(now) not in (int, float)
        or not math.isfinite(started) or not math.isfinite(now)
        or not 0 < started <= now
    ):
        raise GuardError("invalid native diagnostic monotonic job clock")
    return started + JOB_SECONDS - RETENTION_RESERVE_SECONDS - now


def read_report_bytes(path: Path) -> bytes:
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK), "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise GuardError("native diagnostic requires a regular failed report")
        data = stream.read(MAXIMUM_STATISTICS_BYTES + 1)
    if not 0 < len(data) <= MAXIMUM_STATISTICS_BYTES:
        raise GuardError("missing or oversized failed native budget report")
    return data


def read_failed_report(path: Path, workload: str, proxy: Path) -> tuple[bytes, BudgetExceeded]:
    data = read_report_bytes(path)
    try:
        report = json.loads(data, object_pairs_hook=unique_fields)
    except (ValueError, UnicodeError, RecursionError) as error:
        raise GuardError("malformed failed native budget report") from error
    try:
        check_budget(report, workload)
    except BudgetExceeded as failure:
        if (
            report.get("budget_checked") is not True or report.get("budget_passed") is not False
            or report["proxy_sha256"] != hashlib.sha256(proxy.read_bytes()).hexdigest()
        ):
            raise GuardError("incompatible failed native budget evidence") from failure
        return data, failure
    raise GuardError("native diagnostic requires an actual failed budget report")


def capture_failure(
    report_path: Path, workload: str, proxy: Path, output: Path, started: float,
) -> dict[str, object]:
    result: dict[str, object] = {
        "scope": "diagnostic only; original failed budget remains a failure",
        "failed_workload": workload, "budget_checked": False, "budget_passed": False,
        "status": "started",
    }
    with (output / "failure-capture.json").open("x", encoding="ascii") as status:
        json.dump(result, status, indent=2, allow_nan=False)
        status.flush()
        try:
            original, failure = read_failed_report(report_path, workload, proxy)
            remaining = remaining_seconds(started, time.monotonic())
            result["failed_report_sha256"] = hashlib.sha256(original).hexdigest()
            result["original_budget_error"] = str(failure)
            result["remaining_seconds_after_retention_reserve"] = remaining
            if remaining < DIAGNOSTIC_SECONDS:
                result.update(status="skipped", reason="insufficient remaining job time")
            else:
                if (output / "diagnostic-full-export.json").exists():
                    raise GuardError("native diagnostic evidence already exists")
                result["status"] = "running"
                diagnostic = measure(proxy, "full-export", 1, profile_tamarin=True)
                retained, _ = read_failed_report(report_path, workload, proxy)
                if retained != original:
                    raise GuardError("original failed budget report changed during diagnostic")
                if remaining_seconds(started, time.monotonic()) <= 0:
                    raise GuardError("native diagnostic exhausted its job-time allowance")
                with (output / "diagnostic-full-export.json").open("x", encoding="ascii") as stream:
                    json.dump(diagnostic, stream, indent=2, allow_nan=False)
                    stream.write("\n")
                result.update(status="captured", reason="one RTS/CPU screening pair completed")
        except (GuardError, ReplayError, OSError, ValueError, subprocess.SubprocessError) as error:
            result.update(
                status="failed", reason="native failure capture could not complete",
                error_kind=type(error).__name__,
            )
            if isinstance(error, RuntimeProfileError):
                result["runtime_error"] = str(error)
        status.seek(0)
        json.dump(result, status, indent=2, allow_nan=False)
        status.write("\n")
        status.truncate()
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--workload", choices=tuple(WORKLOADS), required=True)
    parser.add_argument("--proxy", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--job-started-at", type=float, required=True)
    arguments = parser.parse_args()
    result = capture_failure(
        arguments.report, arguments.workload, arguments.proxy, arguments.output,
        arguments.job_started_at,
    )
    print(json.dumps(result, indent=2, allow_nan=False))
    return 0 if result["status"] in ("captured", "skipped") else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError):
        print("FAIL: native diagnostic evidence unavailable; capture not repeated", file=sys.stderr)
        sys.exit(1)
