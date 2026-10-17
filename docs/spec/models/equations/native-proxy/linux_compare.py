"""Diagnostic-only comparison of two frozen native revisions on one Linux host."""

from contextlib import chdir, ExitStack
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import tempfile
import time

from equations.maude_runner import GuardError, unique_fields
from replay import run


ROOT = Path(__file__).resolve().parents[5]
NATIVE = Path("docs/spec/models/equations/native-proxy")
REVISIONS = {
    "baseline": (
        "fb1abf44d4901aa7b401a2ed68c1fd64588eeec6",
        "96295e1ecba13e26eac68929ff5dbff673651f5e0eb61a8fe16ae847f2ccf0a8",
    ),
    "candidate": (
        "d4bbeac744aa57869f58bb72b8f993494eea732f",
        "99ba29461c243eeaf179531923c61918f8b6e4f78f31fbe16316813d0766345a",
    ),
}
COMMON_INPUTS = (
    Path("rust-toolchain.toml"),
    Path("docs/spec/models/ratchet.spthy"),
    Path("docs/spec/models/replay.py"),
    *(NATIVE / name for name in (
        "experiment.py", "linux_profile.py", "Cargo.toml", "Cargo.lock",
        "build.rs", "inventory.py",
    )),
    *(NATIVE.parent / name for name in (
        "signature.py", "maude_module.py", "maude_native.py", "maude_runner.py",
    )),
)
ENVIRONMENT_FIELDS = (
    "platform", "python", "architecture", "logical_cpus",
    "physical_memory_bytes", "compiler",
)


def git(*arguments: str) -> str:
    return run(["git", "-C", str(ROOT), *arguments], 30)


def observed_cpu(report: dict) -> float:
    profiles = report.get("native_process_profiles")
    if not isinstance(profiles, dict) or set(profiles) != {"baseline", "compiled_guard"}:
        raise GuardError("native Linux comparison is missing process observations")
    for observations in profiles.values():
        if not isinstance(observations, list) or len(observations) != 1:
            raise GuardError("native Linux comparison requires one process observation per label")
    observation = profiles["compiled_guard"][0]
    if not isinstance(observation, dict):
        raise GuardError("malformed native Linux comparison process observation")
    rate = observation.get("clock_ticks_per_second")
    processes = observation.get("processes")
    if type(rate) is not int or rate <= 0 or not isinstance(processes, list) or not processes:
        raise GuardError("native Linux comparison did not observe its guard")
    ticks = 0
    for process in processes:
        if not isinstance(process, dict):
            raise GuardError("malformed native Linux comparison process")
        for field in ("last_observed_user_clock_ticks", "last_observed_system_clock_ticks"):
            value = process.get(field)
            if type(value) is not int or value < 0:
                raise GuardError("invalid native Linux comparison CPU observation")
            ticks += value
    if ticks == 0:
        raise GuardError("native Linux comparison did not observe guard CPU activity")
    return ticks / rate


def validate(report: object, revision: str, identity: str, view: Path, proxy: Path) -> dict:
    if not isinstance(report, dict):
        raise GuardError("malformed native Linux comparison report")
    if (
        report.get("baseline_revision") != revision or report.get("source_id") != identity
        or report.get("proxy_sha256") != hashlib.sha256(proxy.read_bytes()).hexdigest()
        or report.get("model_sha256") != hashlib.sha256(
            (view / "docs/spec/models/ratchet.spthy").read_bytes(),
        ).hexdigest()
        or report.get("export_sha256") !=
        "1b66b2a76902af6c98de7b22edbe6f4d8fddc27cd2adb580db6d5eff639dbd48"
        or report.get("workload_name") != "full-export"
        or report.get("method") != "one screening pair, not acceptance"
        or report.get("budget_checked") is not False or report.get("budget_passed") is not False
    ):
        raise GuardError("incompatible native Linux comparison source, workload or method")
    samples = report.get("seconds")
    if not isinstance(samples, dict) or set(samples) != {"baseline", "compiled_guard"}:
        raise GuardError("malformed native Linux comparison timings")
    for values in samples.values():
        if (
            not isinstance(values, list) or len(values) != 1
            or type(values[0]) not in (int, float)
            or not math.isfinite(values[0]) or values[0] <= 0
        ):
            raise GuardError("invalid native Linux comparison elapsed time")
    for field in ENVIRONMENT_FIELDS:
        value = report.get(field)
        valid = (
            type(value) is int and value > 0
            if field in ("logical_cpus", "physical_memory_bytes")
            else isinstance(value, str) and bool(value)
        )
        if not valid:
            raise GuardError("missing native Linux comparison environment")
    expected = 100 * (samples["compiled_guard"][0] / samples["baseline"][0] - 1)
    change = report.get("change_percent")
    if (
        type(change) not in (int, float) or not math.isfinite(change)
        or not math.isclose(change, expected, rel_tol=1e-12, abs_tol=1e-9)
    ):
        raise GuardError("invalid native Linux comparison overhead")
    observed_cpu(report)
    return report


def compare() -> dict:
    if "CAIRN_MAUDE_BINARY" in os.environ:
        raise GuardError("native Linux comparison rejects a backend override")
    before = git("worktree", "list", "--porcelain")
    reports = {}
    spans = {}
    with tempfile.TemporaryDirectory(prefix="cairn-native-compare-") as temporary:
        directory = Path(temporary)
        with ExitStack() as cleanup:
            views = {}
            for label, (revision, _) in REVISIONS.items():
                view = directory / label
                git("worktree", "add", "--detach", str(view), revision)
                cleanup.callback(git, "worktree", "remove", str(view))
                if run(["git", "-C", str(view), "rev-parse", "HEAD"], 30).strip() != revision:
                    raise GuardError("native Linux comparison checkout identity mismatch")
                views[label] = view
            shared = hashlib.sha256()
            for path in COMMON_INPUTS:
                data = (views["baseline"] / path).read_bytes()
                if (views["candidate"] / path).read_bytes() != data:
                    raise GuardError("native Linux comparison changes a shared measurement input")
                shared.update(path.as_posix().encode() + b"\0" + data + b"\0")
            for label, view in views.items():
                with chdir(view):
                    run([
                        "cargo", "build", "--locked", "--release",
                        "--manifest-path", str(NATIVE / "Cargo.toml"),
                        "--target-dir", str(directory / f"{label}-target"),
                    ], 120)
            for label, (revision, identity) in REVISIONS.items():
                view = views[label]
                proxy = directory / f"{label}-target/release/cairn-maude-proxy"
                with chdir(view):
                    started = time.monotonic()
                    output = run([
                        sys.executable, "-B", str(NATIVE / "experiment.py"),
                        "--proxy", str(proxy), "--workload", "full-export",
                        "--rounds", "1", "--profile-linux",
                    ], 270)
                    spans[label] = time.monotonic() - started
                reports[label] = validate(
                    json.loads(output, object_pairs_hook=unique_fields),
                    revision, identity, view, proxy,
                )
            for field in ENVIRONMENT_FIELDS:
                if reports["baseline"].get(field) != reports["candidate"].get(field):
                    raise GuardError("native Linux comparison environment changed between revisions")
        if git("worktree", "list", "--porcelain") != before:
            raise GuardError("native Linux comparison worktree cleanup did not reconcile")
    return {
        "scope": "same-run frozen-revision screening; not causation, budget or default acceptance",
        "method": "baseline then candidate; one profiled direct/guarded pair per revision",
        "budget_checked": False,
        "budget_passed": False,
        "shared_inputs_sha256": shared.hexdigest(),
        "measurement_span_seconds": spans,
        "observed_guard_cpu_seconds": {
            label: observed_cpu(report) for label, report in reports.items()
        },
        "native_linux_comparison": reports,
        "worktree_cleanup": "verified; both owned views removed and original inventory restored",
    }
