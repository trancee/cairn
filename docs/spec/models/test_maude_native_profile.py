"""Native phase schema, owned reports and driver-clock measurement boundaries."""

import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from equations.maude_native import NATIVE_DIRECTORY
from equations.maude_runner import GuardError, run_guarded_tamarin

sys.path.insert(0, str(NATIVE_DIRECTORY))

import experiment
from native_profile import (
    MAXIMUM_PROFILE_BYTES, PHASES, NativePhaseProfile, NativeProfileError, phase_records,
)
from tamarin_profile import TamarinRuntimeProfile


def record(identifier=123):
    return {
        "pid": identifier, "interactive_cpu_nanoseconds": 1000,
        "interactive_wall_nanoseconds": 2000,
        "phases": {
            phase: {
                "calls": 4 if phase == "journal" else 2,
                "cpu_nanoseconds": 10, "wall_nanoseconds": 20,
            }
            for phase in PHASES
        },
        "io_phases": {
            "input_wait": {"calls": 2, "cpu_nanoseconds": 3, "wall_nanoseconds": 5},
            "input_read": {"calls": 2, "cpu_nanoseconds": 4, "wall_nanoseconds": 7},
            "native_write": {"calls": 6, "cpu_nanoseconds": 10, "wall_nanoseconds": 20},
            "native_wait": {"calls": 7, "cpu_nanoseconds": 10, "wall_nanoseconds": 20},
            "native_stdout_read": {"calls": 7, "cpu_nanoseconds": 10, "wall_nanoseconds": 20},
            "native_stderr_read": {"calls": 0, "cpu_nanoseconds": 0, "wall_nanoseconds": 0},
        },
    }


def encoded(records):
    return b"".join(json.dumps(item).encode() + b"\n" for item in records)


class NativePhaseStatisticsTests(unittest.TestCase):
    def test_complete_numeric_records_preserve_all_processes_and_phases(self):
        records = [record(123), record(124)]

        result = phase_records(encoded(records))

        self.assertEqual(result, records)

    def test_empty_truncated_non_ascii_duplicate_and_oversized_records_reject(self):
        cases = (
            b"", b"{\n", b"[]\n", b"{}\n", b"\xff\n", b'{"pid":1,"pid":2}\n',
            b"[" * 2000 + b"\n", b"x" * MAXIMUM_PROFILE_BYTES + b"\n",
            encoded([record()]).rstrip(b"\n"),
            encoded([record()] * 2), encoded([record(index + 1) for index in range(9)]),
        )
        for data in cases:
            with self.subTest(prefix=data[:20]):
                with self.assertRaises(NativeProfileError):
                    phase_records(data)

    def test_invalid_fields_clocks_identifiers_and_counts_are_redacted(self):
        changes = [
            ("pid", value) for value in (True, 0, -1, 2**32, "omitted fixture payload")
        ] + [
            (field, value)
            for field in ("interactive_cpu_nanoseconds", "interactive_wall_nanoseconds")
            for value in (True, -1, 0.5, 2**64, None, float("nan"))
        ]
        for field, value in changes:
            entry = dict(record(), **{field: value})
            with self.subTest(field=field, value=value):
                with self.assertRaises(NativeProfileError) as raised:
                    phase_records(encoded([entry]))
                self.assertNotIn("omitted fixture payload", str(raised.exception))
        malformed = []
        for phase in PHASES:
            entry = record()
            del entry["phases"][phase]
            malformed.append(entry)
        entry = record()
        entry["extra"] = 0
        malformed.append(entry)
        entry = record()
        entry["phases"]["unknown"] = entry["phases"]["input"]
        malformed.append(entry)
        for field in ("calls", "cpu_nanoseconds", "wall_nanoseconds"):
            for value in (True, -1, 0.5, None, 2**64):
                entry = record()
                entry["phases"]["journal"][field] = value
                malformed.append(entry)
        for counters in (None, [], {}, dict(record()["phases"]["input"], extra=0)):
            entry = record()
            entry["phases"]["input"] = counters
            malformed.append(entry)
        for entry in malformed:
            with self.subTest(entry=entry):
                with self.assertRaises(NativeProfileError):
                    phase_records(encoded([entry]))

    def test_cli_cannot_enable_native_profiling_for_acceptance_or_other_workloads(self):
        cases = (
            ["--proxy", "/absent/guard"],
            ["--proxy", "/absent/guard", "--rounds", "1", "--workload", "startup"],
            ["--check-report", "/absent/report", "--rounds", "1"],
        )
        for arguments in cases:
            with self.subTest(arguments=arguments):
                result = subprocess.run(
                    [sys.executable, str(NATIVE_DIRECTORY / "experiment.py"),
                     *arguments, "--profile-native"],
                    text=True, capture_output=True, timeout=5,
                )

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("requires one full-export screening pair", result.stderr)

    def test_inconsistent_operation_counts_and_phase_clock_totals_reject(self):
        malformed = []
        for phase in PHASES:
            entry = record()
            entry["phases"][phase]["calls"] = 1
            malformed.append(entry)
        for clock in ("cpu", "wall"):
            entry = record()
            entry["phases"]["input"][f"{clock}_nanoseconds"] = 10_000
            malformed.append(entry)
        for entry in malformed:
            with self.subTest(entry=entry):
                with self.assertRaises(NativeProfileError):
                    phase_records(encoded([entry]))

    def test_uncalled_phases_cannot_claim_cpu_or_wall_time(self):
        for clock in ("cpu_nanoseconds", "wall_nanoseconds"):
            entry = record()
            for name in PHASES - {"input"}:
                entry["phases"][name] = {
                    "calls": 0, "cpu_nanoseconds": 0, "wall_nanoseconds": 0,
                }
            entry["phases"]["reply_validation"][clock] = 1
            with self.subTest(clock=clock):
                with self.assertRaisesRegex(NativeProfileError, "uncalled phase"):
                    phase_records(encoded([entry]))


class NativePhaseReportTests(unittest.TestCase):
    def setUp(self):
        platform = patch("native_profile.sys.platform", "linux")
        platform.start()
        self.addCleanup(platform.stop)
        environment = patch.dict(os.environ, CAIRN_MAUDE_PHASE_REPORT="")
        environment.start()
        self.addCleanup(environment.stop)

    def test_private_report_cleanup_and_baseline_driver_cpu_are_explicit(self):
        with NativePhaseProfile(False) as profile:
            directory = Path(profile.temporary.name)

            result = profile.report(25)

        self.assertEqual(result["driver_thread_cpu_nanoseconds"], 25)
        self.assertEqual(result["processes"], [])
        self.assertFalse(directory.exists())

    def test_owned_guard_records_are_read_without_retaining_the_path(self):
        with NativePhaseProfile(True) as profile:
            directory = profile.path.parent
            profile.path.write_bytes(encoded([record()]))

            result = profile.report(50)

        self.assertEqual(result["processes"], [record()])
        self.assertEqual(result["driver_thread_cpu_nanoseconds"], 50)
        self.assertNotIn(str(directory), repr(result))
        self.assertFalse(directory.exists())

    def test_missing_oversized_and_non_regular_reports_fail_without_hanging(self):
        for mode in ("missing", "fifo", "directory", "symlink", "oversized"):
            with self.subTest(mode=mode):
                with self.assertRaises(NativeProfileError):
                    with NativePhaseProfile(True) as profile:
                        directory = profile.path.parent
                        if mode == "fifo":
                            os.mkfifo(profile.path)
                        elif mode == "directory":
                            profile.path.mkdir()
                        elif mode == "symlink":
                            target = directory / "target"
                            target.write_bytes(encoded([record()]))
                            profile.path.symlink_to(target)
                        elif mode == "oversized":
                            profile.path.write_bytes(b"x" * (MAXIMUM_PROFILE_BYTES + 1))
                        profile.report(50)
                self.assertFalse(directory.exists())

    def test_invalid_driver_clocks_reject_without_payloads(self):
        for value in (True, -1, 0.5, None, 2**64, "omitted fixture payload"):
            with self.subTest(value=value):
                with self.assertRaises(NativeProfileError) as raised:
                    with NativePhaseProfile(False) as profile:
                        profile.report(value)
                self.assertNotIn("omitted fixture payload", str(raised.exception))

    def test_unsupported_or_inherited_profiling_cannot_silently_run(self):
        with patch("native_profile.sys.platform", "darwin"):
            with self.assertRaisesRegex(NativeProfileError, "64-bit native Linux"):
                with NativePhaseProfile(True):
                    self.fail("unsupported native profile started")
        with patch.dict(os.environ, CAIRN_MAUDE_PHASE_REPORT="omitted fixture path"):
            with self.assertRaisesRegex(NativeProfileError, "owned explicit report") as raised:
                with NativePhaseProfile(True):
                    self.fail("inherited native profile started")
        self.assertNotIn("omitted fixture path", str(raised.exception))

    def test_runtime_context_preserves_native_typed_failures(self):
        profile = TamarinRuntimeProfile()
        with tempfile.TemporaryDirectory() as temporary:
            profile.temporary = tempfile.TemporaryDirectory(dir=temporary)

            result = profile.__exit__(NativeProfileError, NativeProfileError("native clock"), None)

        self.assertIsNone(result)

    def test_shared_runner_rejects_inherited_and_relative_reports_before_launch(self):
        with patch.dict(os.environ, CAIRN_MAUDE_PHASE_REPORT="omitted fixture path"):
            with self.assertRaisesRegex(GuardError, "owned explicit report"):
                run_guarded_tamarin(["tamarin-prover"], 1)
        with self.assertRaisesRegex(GuardError, "absolute report path"):
            run_guarded_tamarin(["tamarin-prover"], 1, phase_report=Path("relative"))

    def test_driver_cpu_brackets_the_timed_runner_for_each_label(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            model, proxy = root / "model", root / "proxy"
            model.write_text("fixture model")
            proxy.write_bytes(b"fixture guard")
            output = "fixture export"
            digest = experiment.hashlib.sha256(output.encode()).hexdigest()

            def guarded(command, timeout, *, proxy, phase_report):
                phase_report.write_bytes(encoded([record()]))
                return output

            with (
                patch.dict(experiment.WORKLOADS, {"full-export": (model, (digest,))}),
                patch.object(experiment, "MODELS", root),
                patch.object(experiment, "run", return_value=output),
                patch.object(experiment, "run_guarded_tamarin", side_effect=guarded),
                patch.object(experiment.subprocess, "check_output", return_value="fixture"),
                patch.object(experiment.platform, "platform", return_value="fixture-platform"),
                patch.object(experiment.time, "thread_time_ns", side_effect=[100, 150, 200, 400]),
            ):
                result = experiment.measure(proxy, "full-export", 1, profile_native=True)

        profiles = result["native_phase_profiles"]
        self.assertEqual(profiles["baseline"][0]["driver_thread_cpu_nanoseconds"], 50)
        self.assertEqual(profiles["baseline"][0]["processes"], [])
        self.assertEqual(profiles["compiled_guard"][0]["driver_thread_cpu_nanoseconds"], 200)
        self.assertEqual(profiles["compiled_guard"][0]["processes"], [record()])
        self.assertFalse(result["budget_checked"])
        self.assertFalse(result["budget_passed"])
