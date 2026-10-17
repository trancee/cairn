"""Failure-only eligibility, remaining-time boundaries and immutable evidence."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from equations.maude_native import NATIVE_DIRECTORY
from equations.maude_runner import GuardError
import test_maude_performance

sys.path.insert(0, str(NATIVE_DIRECTORY))

import capture_failure
from tamarin_profile import RuntimeProfileError


class FailureCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.proxy = self.root / "native-guard"
        self.proxy.write_bytes(b"fixture native executable\n")
        self.proxy.chmod(0o700)
        self.report_path = self.root / "normal-full-export.json"
        self.report = test_maude_performance.NativePerformanceCommandTests().report("full-export")
        self.report.update(
            budget_checked=True, budget_passed=False,
            proxy_sha256=hashlib.sha256(self.proxy.read_bytes()).hexdigest(),
        )
        self.save_report()
        self.diagnostic = {
            "method": "one screening pair, not acceptance",
            "budget_checked": False, "budget_passed": False,
            "tamarin_runtime_profiles": {"fixture": "not hardware evidence"},
        }
        self.clock = patch("capture_failure.time.monotonic", return_value=1000.0)
        self.clock.start()
        self.addCleanup(self.clock.stop)
        measurement = patch("capture_failure.measure", return_value=self.diagnostic)
        self.measurement = measurement.start()
        self.addCleanup(measurement.stop)

    def save_report(self):
        self.report_path.write_text(json.dumps(self.report))

    def capture(self, started=500, workload="full-export"):
        output = Path(tempfile.mkdtemp(dir=self.root))
        result = capture_failure.capture_failure(
            self.report_path, workload, self.proxy, output, started,
        )
        return result, output

    def test_failed_report_is_preserved_before_one_separate_nonacceptance_pair(self):
        original = self.report_path.read_bytes()

        result, output = self.capture()

        self.assertEqual(result["status"], "captured", result)
        self.assertEqual(self.report_path.read_bytes(), original)
        self.assertEqual(result["failed_report_sha256"], hashlib.sha256(original).hexdigest())
        self.assertFalse(result["budget_checked"])
        self.assertFalse(result["budget_passed"])
        self.assertEqual(json.loads((output / "diagnostic-full-export.json").read_text()), self.diagnostic)
        self.assertEqual(json.loads((output / "failure-capture.json").read_text()), result)
        self.measurement.assert_called_once_with(self.proxy, "full-export", 1, profile_tamarin=True)

    def test_exact_remaining_time_boundary_includes_the_retention_reserve(self):
        for started, expected in ((459.999, "skipped"), (460, "captured"), (460.001, "captured")):
            self.measurement.reset_mock()
            with self.subTest(started=started):
                result, output = self.capture(started)

                self.assertEqual(result["status"], expected, result)
                self.assertEqual(self.measurement.call_count, int(expected == "captured"))
                self.assertEqual((output / "diagnostic-full-export.json").exists(), expected == "captured")

    def test_exhausted_job_time_skips_without_starting_another_workload(self):
        result, output = self.capture(started=1)

        self.assertEqual(result["status"], "skipped", result)
        self.assertEqual(result["reason"], "insufficient remaining job time")
        self.measurement.assert_not_called()
        self.assertFalse((output / "diagnostic-full-export.json").exists())

    def test_invalid_or_future_monotonic_job_clocks_fail_closed(self):
        for started in (0, -1, True, "500", 1001, float("nan"), float("inf")):
            with self.subTest(started=started):
                result, output = self.capture(started)

                self.assertEqual(result["status"], "failed", result)
                self.measurement.assert_not_called()
                self.assertFalse((output / "diagnostic-full-export.json").exists())

    def test_passing_or_relabelled_diagnostic_reports_cannot_trigger_capture(self):
        changes = (
            {"seconds": {"baseline": [20] * 3, "compiled_guard": [21] * 3}},
            {"method": "one screening pair, not acceptance"},
            {"tamarin_runtime_profiles": {}}, {"native_process_profiles": {}},
            {"budget_checked": False}, {"budget_passed": True},
            {"source_id": "0" * 64}, {"proxy_sha256": "0" * 64},
        )
        original = dict(self.report)
        for change in changes:
            self.report = dict(original, **change)
            self.save_report()
            with self.subTest(change=change):
                result, _ = self.capture()

                self.assertEqual(result["status"], "failed", result)
                self.measurement.assert_not_called()

    def test_startup_failure_can_only_trigger_a_full_export_diagnostic_pair(self):
        self.report = test_maude_performance.NativePerformanceCommandTests().report("startup", 0.2)
        self.report.update(
            budget_checked=True, budget_passed=False,
            proxy_sha256=hashlib.sha256(self.proxy.read_bytes()).hexdigest(),
        )
        self.save_report()

        result, _ = self.capture(workload="startup")

        self.assertEqual(result["status"], "captured", result)
        self.assertEqual(result["failed_workload"], "startup")
        self.measurement.assert_called_once_with(self.proxy, "full-export", 1, profile_tamarin=True)

    def test_truncated_duplicate_or_missing_failure_reports_never_start_diagnostics(self):
        for data in ("", "{", "[]", '{"seconds":{},"seconds":{}}', "x" * 200_001):
            self.report_path.write_text(data)
            with self.subTest(prefix=data[:20]):
                result, _ = self.capture()

                self.assertEqual(result["status"], "failed", result)
                self.measurement.assert_not_called()
        self.report_path.unlink()

        result, _ = self.capture()

        self.assertEqual(result["status"], "failed", result)
        self.measurement.assert_not_called()

    def test_runtime_or_tool_failure_is_explicit_without_copying_payloads(self):
        for error in (
            RuntimeProfileError("incomplete Tamarin RTS statistics"),
            GuardError("omitted fixture process output"),
            subprocess.TimeoutExpired(["omitted fixture argument"], 5),
            OSError("omitted fixture path"),
        ):
            self.measurement.side_effect = error
            with self.subTest(kind=type(error).__name__):
                result, output = self.capture()

                self.assertEqual(result["status"], "failed", result)
                self.assertEqual(result["error_kind"], type(error).__name__)
                self.assertNotIn("omitted fixture", (output / "failure-capture.json").read_text())
                self.assertFalse((output / "diagnostic-full-export.json").exists())

    def test_time_allowance_exhaustion_cannot_publish_a_completed_diagnostic(self):
        with patch("capture_failure.time.monotonic", side_effect=[1000.0, 1400.0]):
            result, output = self.capture()

        self.assertEqual(result["status"], "failed", result)
        self.assertFalse((output / "diagnostic-full-export.json").exists())

    def test_changed_original_report_cannot_publish_a_completed_diagnostic(self):
        def change_original(*arguments, **keywords):
            self.report_path.write_text("changed fixture report")
            return self.diagnostic
        self.measurement.side_effect = change_original

        result, output = self.capture()

        self.assertEqual(result["status"], "failed", result)
        self.assertFalse((output / "diagnostic-full-export.json").exists())

    def test_replayed_capture_refuses_to_overwrite_or_run_another_pair(self):
        _, output = self.capture()
        original_status = (output / "failure-capture.json").read_bytes()

        with self.assertRaises(FileExistsError):
            capture_failure.capture_failure(
                self.report_path, "full-export", self.proxy, output, 500,
            )

        self.assertEqual((output / "failure-capture.json").read_bytes(), original_status)
        self.measurement.assert_called_once()


class FailureCaptureCommandTests(unittest.TestCase):
    def test_nonbudget_cli_failure_has_a_failed_status_without_raw_content(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            report = output / "normal-full-export.json"
            report.write_text("omitted fixture diagnostic payload")

            result = subprocess.run(
                [sys.executable, str(NATIVE_DIRECTORY / "capture_failure.py"),
                 "--report", str(report), "--workload", "full-export",
                 "--proxy", "/absent/native-guard", "--output", str(output),
                 "--job-started-at", str(time.monotonic())],
                text=True, capture_output=True, timeout=5,
            )

            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout)["status"], "failed")
            self.assertNotIn("omitted fixture diagnostic payload", result.stdout + result.stderr)
