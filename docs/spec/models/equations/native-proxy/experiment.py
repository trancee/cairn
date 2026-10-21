"""Paired native-guard performance measurement against direct pinned execution."""

import argparse
from contextlib import nullcontext
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import resource
import statistics
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from equations.maude_runner import GuardError, run_guarded_tamarin, unique_fields
from equations.maude_native import source_identity
from replay import ReplayError, run
from linux_profile import LinuxProcessProfile
from native_profile import NativePhaseProfile
from tamarin_profile import TamarinRuntimeProfile


MODELS = Path(__file__).resolve().parents[2]
ROOT = MODELS.parents[2]
COMMITTED_BASELINE = "unchanged committed replay.run, direct pinned Tamarin/Maude"
WORKING_TREE_BASELINE = "uncommitted working-tree replay.run, direct pinned Tamarin/Maude"
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
        (
            "ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64",
            "59548c48458d4bdf8e7fee57ba0257642f0a21bfd94c2004a4fb990781659fae",
        ),
    ),
}


class BudgetExceeded(GuardError):
    """A structurally valid current-source report exceeds its approved budget."""


def committed_baseline(root: Path, timeout: float | None = None) -> bool:
    # Outside a repository, git diff silently switches to --no-index mode.
    toplevel = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
        text=True, capture_output=True, timeout=timeout,
    )
    if toplevel.returncode != 0 or Path(toplevel.stdout.strip()).resolve() != root.resolve():
        raise GuardError("native guard committed replay baseline unavailable")
    result = subprocess.run(
        ["git", "-C", str(root), "diff", "--quiet", "HEAD", "--", "docs/spec/models/replay.py"],
        capture_output=True, timeout=timeout,
    )
    if result.returncode not in (0, 1):
        raise GuardError("native guard committed replay baseline unavailable")
    return result.returncode == 0


def baseline_label(rounds: int, *, committed: bool) -> str:
    if committed:
        return COMMITTED_BASELINE
    if rounds != 1:
        raise GuardError("native guard acceptance requires a committed replay baseline")
    return WORKING_TREE_BASELINE


def check_budget(report: object, workload: str) -> None:
    if not isinstance(report, dict):
        raise GuardError("malformed native guard performance report")
    if "native_process_profiles" in report:
        raise GuardError("native process profiling is diagnostic only")
    if "native_linux_comparison" in report:
        raise GuardError("native Linux comparison is diagnostic only")
    if "tamarin_runtime_profiles" in report:
        raise GuardError("Tamarin RTS profiling is diagnostic only")
    if "native_phase_profiles" in report:
        raise GuardError("native phase profiling is diagnostic only")
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
        or report.get("baseline") != COMMITTED_BASELINE
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
    if "waited_child_resources" in report:
        resources = report["waited_child_resources"]
        if not isinstance(resources, dict) or set(resources) != set(samples):
            raise GuardError("malformed native guard child-resource diagnostics")
        for entries in resources.values():
            if not isinstance(entries, list) or len(entries) != 3:
                raise GuardError("malformed native guard child-resource diagnostics")
            for entry in entries:
                if not isinstance(entry, dict) or set(entry) != {
                    "user_seconds", "system_seconds",
                    "voluntary_context_switches", "involuntary_context_switches",
                }:
                    raise GuardError("malformed native guard child-resource diagnostics")
                for field, value in entry.items():
                    if field in ("user_seconds", "system_seconds"):
                        valid = (
                            type(value) in (int, float)
                            and Decimal(str(value)).is_finite() and value >= 0
                        )
                    else:
                        valid = type(value) is int and value >= 0
                    if not valid:
                        raise GuardError("malformed native guard child-resource diagnostics")
    baseline = medians["baseline"]
    maximum = baseline * Decimal("1.10") if workload == "full-export" else baseline + Decimal("0.050")
    if medians["compiled_guard"] > maximum:
        threshold = "10% full-export" if workload == "full-export" else "50 ms startup-only"
        raise BudgetExceeded(f"native guard exceeds approved {threshold} budget")


def measure(
    proxy: Path, workload: str, rounds: int, *,
    profile_linux: bool = False, profile_tamarin: bool = False, profile_native: bool = False,
) -> dict[str, object]:
    if workload not in WORKLOADS or rounds not in (1, 3):
        raise GuardError("unsupported native guard measurement")
    if (profile_linux or profile_tamarin or profile_native) and (rounds != 1 or workload != "full-export"):
        raise GuardError("native profiling requires one full-export screening pair")
    if profile_linux and sys.platform != "linux":
        raise GuardError("native process profiling requires native Linux")
    if profile_native and (sys.platform != "linux" or sys.maxsize <= 2**32):
        raise GuardError("native CPU profiling requires 64-bit native Linux")
    if os.environ.get("CAIRN_MAUDE_PHASE_REPORT"):
        raise GuardError("native CPU profiling requires an owned explicit report")
    proxy = proxy.resolve(strict=True)
    model, expected_exports = WORKLOADS[workload]
    identity = source_identity()
    proxy_digest = hashlib.sha256(proxy.read_bytes()).hexdigest()
    metadata_timeout = 5 if profile_tamarin or profile_native else None
    baseline = baseline_label(rounds, committed=committed_baseline(ROOT, metadata_timeout))
    command = [
        "tamarin-prover", str(model), "--quit-on-warning",
        "--derivcheck-timeout=60", "--output-module=msr",
    ]
    timings: dict[str, list[float]] = {"baseline": [], "compiled_guard": []}
    child_resources: dict[str, list[dict[str, float | int]]] = {
        "baseline": [], "compiled_guard": [],
    }
    profiles: dict[str, list[dict[str, object]]] = {"baseline": [], "compiled_guard": []}
    runtime_profiles: dict[str, list[dict[str, object]]] = {"baseline": [], "compiled_guard": []}
    phase_profiles: dict[str, list[dict[str, object]]] = {"baseline": [], "compiled_guard": []}
    digest = None
    for index in range(rounds):
        order = ("baseline", "compiled_guard") if index % 2 == 0 else ("compiled_guard", "baseline")
        for label in order:
            profiler = LinuxProcessProfile(proxy) if profile_linux else nullcontext()
            runtime_profiler = (
                TamarinRuntimeProfile(proxy if label == "compiled_guard" else None)
                if profile_tamarin else nullcontext()
            )
            phase_profiler = NativePhaseProfile(label == "compiled_guard") if profile_native else nullcontext()
            with profiler as profile, runtime_profiler as runtime_profile, phase_profiler as phase_profile:
                measured_command = command if runtime_profile is None else runtime_profile.command(command)
                before = resource.getrusage(resource.RUSAGE_CHILDREN)
                driver_started = time.thread_time_ns() if phase_profile is not None else 0
                started = time.monotonic()
                output = (
                    run(measured_command, 120) if label == "baseline"
                    else run_guarded_tamarin(
                        measured_command, 120, proxy=proxy,
                        phase_report=None if phase_profile is None else phase_profile.path,
                    )
                )
                timings[label].append(time.monotonic() - started)
                driver_cpu = time.thread_time_ns() - driver_started if phase_profile is not None else 0
                after = resource.getrusage(resource.RUSAGE_CHILDREN)
                if phase_profile is not None:
                    phase_profiles[label].append(phase_profile.report(driver_cpu))
                if runtime_profile is not None:
                    runtime_profiles[label].append(runtime_profile.report())
            if profile is not None:
                observation = profile.report()
                if label == "compiled_guard" and not observation["processes"]:
                    raise GuardError("native Linux process profile did not observe an interactive guard")
                profiles[label].append(observation)
            child_resources[label].append({
                "user_seconds": after.ru_utime - before.ru_utime,
                "system_seconds": after.ru_stime - before.ru_stime,
                "voluntary_context_switches": after.ru_nvcsw - before.ru_nvcsw,
                "involuntary_context_switches": after.ru_nivcsw - before.ru_nivcsw,
            })
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
    if profile_tamarin and (
        runtime_profiles["baseline"][0]["executable_sha256"]
        != runtime_profiles["compiled_guard"][0]["executable_sha256"]
    ):
        raise GuardError("Tamarin RTS profiling executable changed between samples")
    medians = {label: statistics.median(values) for label, values in timings.items()}
    report = {
        "scope": "native guard performance evidence, not default cutover or native FVP acceptance",
        "workload_name": workload,
        "workload": [command[0], str(model.relative_to(MODELS)), *command[2:]],
        "platform": platform.platform(),
        "python": platform.python_version(),
        "architecture": platform.machine(),
        "logical_cpus": os.cpu_count(),
        "physical_memory_bytes": os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE"),
        "baseline_revision": subprocess.check_output(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True, timeout=metadata_timeout,
        ).strip(),
        "baseline": baseline,
        "method": "three alternating paired runs" if rounds == 3 else "one screening pair, not acceptance",
        "seconds": timings,
        "waited_child_resources": child_resources,
        "median_seconds": medians,
        "change_percent": 100 * (medians["compiled_guard"] / medians["baseline"] - 1),
        "additional_milliseconds": 1000 * (medians["compiled_guard"] - medians["baseline"]),
        "source_id": identity,
        "model_sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
        "export_sha256": digest,
        "proxy_sha256": proxy_digest,
        "compiler": subprocess.check_output(
            ["rustc", "--version"], text=True, timeout=metadata_timeout,
        ).strip(),
        "budget_checked": rounds == 3,
        "budget_passed": False,
    }
    if profile_linux:
        report["native_process_profiles"] = profiles
    if profile_tamarin:
        report["tamarin_runtime_profiles"] = runtime_profiles
    if profile_native:
        report["native_phase_profiles"] = phase_profiles
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--proxy", type=Path)
    mode.add_argument("--check-report", type=Path)
    parser.add_argument("--workload", choices=tuple(WORKLOADS), default="full-export")
    parser.add_argument("--rounds", type=int, choices=(1, 3), default=3)
    parser.add_argument("--profile-linux", action="store_true")
    parser.add_argument("--profile-tamarin", action="store_true")
    parser.add_argument("--profile-native", action="store_true")
    arguments = parser.parse_args()
    for enabled, name in (
        (arguments.profile_linux, "native process"),
        (arguments.profile_tamarin, "Tamarin RTS"),
        (arguments.profile_native, "native phase"),
    ):
        if enabled and (
            arguments.proxy is None or arguments.rounds != 1 or arguments.workload != "full-export"
        ):
            raise GuardError(f"{name} profiling requires one full-export screening pair")
    if arguments.check_report is not None:
        try:
            report = json.loads(arguments.check_report.read_text(), object_pairs_hook=unique_fields)
        except (ValueError, RecursionError) as error:
            raise GuardError("malformed native guard performance report") from error
        check_budget(report, arguments.workload)
        print(f"PASS: native guard {arguments.workload} median meets its approved budget")
        return 0
    report = measure(
        arguments.proxy, arguments.workload, arguments.rounds,
        profile_linux=arguments.profile_linux, profile_tamarin=arguments.profile_tamarin,
        profile_native=arguments.profile_native,
    )
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
    except (OSError, ValueError, subprocess.SubprocessError):
        print("FAIL: native guard benchmark tool, source, report or baseline unavailable", file=sys.stderr)
        sys.exit(1)
