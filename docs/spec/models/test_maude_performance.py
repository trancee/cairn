"""Approved workload budgets at the benchmark CLI/report seam."""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from equations.maude_candidate import NATIVE_DIRECTORY, source_identity


class NativePerformanceCommandTests(unittest.TestCase):
    def report(self, workload="startup", guarded=0.169):
        model = (
            NATIVE_DIRECTORY / "derivation.spthy" if workload == "startup"
            else NATIVE_DIRECTORY.parents[1] / "ratchet.spthy"
        )
        return {
            "workload_name": workload,
            "method": "three alternating paired runs",
            "source_id": source_identity(),
            "model_sha256": hashlib.sha256(model.read_bytes()).hexdigest(),
            "export_sha256": (
                "ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64"
                if workload == "startup" else
                "aaaf873a9b7baff6fbf209f1cf87088581552498ade6f9a5e471ee2b5ea6fb5d"
            ),
            "seconds": {"baseline": [0.12] * 3, "compiled_guard": [guarded] * 3},
            "platform": "budget-fixture-os",
            "architecture": "budget-fixture-cpu",
            "compiler": "rustc 1.99.0 (budget-fixture)",
            "baseline": "unchanged committed replay.run, direct pinned Tamarin/Maude",
            "logical_cpus": 2,
            "physical_memory_bytes": 8 * 1024**3,
            "baseline_revision": "a" * 40,
            "proxy_sha256": "b" * 64,
        }

    def check_report(self, report, workload="startup"):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "report.json"
            path.write_text(report if isinstance(report, str) else json.dumps(report))

            return subprocess.run(
                [sys.executable, str(NATIVE_DIRECTORY / "experiment.py"),
                 "--check-report", str(path), "--workload", workload],
                text=True, capture_output=True, timeout=5,
            )

    def test_startup_report_within_the_approved_additive_budget_is_accepted(self):
        result = self.check_report(self.report())

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS:", result.stdout)

    def test_exact_startup_limit_uses_the_paired_medians(self):
        report = self.report()
        report["seconds"] = {
            "baseline": [0.10, 0.12, 0.30],
            "compiled_guard": [0.14, 0.17, 0.35],
        }

        result = self.check_report(report)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_startup_above_fifty_milliseconds_is_rejected(self):
        result = self.check_report(self.report(guarded=0.170001))

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("50 ms startup-only budget", result.stderr)

    def test_full_export_does_not_inherit_the_startup_allowance(self):
        result = self.check_report(self.report("full-export"), "full-export")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("10% full-export budget", result.stderr)

    def test_exact_full_export_limit_is_accepted(self):
        report = self.report("full-export")
        report["seconds"] = {"baseline": [20] * 3, "compiled_guard": [22] * 3}

        result = self.check_report(report, "full-export")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_full_export_above_ten_percent_is_rejected(self):
        report = self.report("full-export")
        report["seconds"] = {"baseline": [20] * 3, "compiled_guard": [22.001] * 3}

        result = self.check_report(report, "full-export")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("10% full-export budget", result.stderr)

    def test_startup_cannot_be_relabelled_as_a_full_export(self):
        result = self.check_report(self.report(), "full-export")

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("incompatible", result.stderr)

    def test_stale_incompatible_or_incomplete_reports_are_rejected(self):
        changes = (
            ("source_id", "0" * 64), ("model_sha256", "0" * 64),
            ("export_sha256", "0" * 64), ("method", "one screening pair, not acceptance"),
            ("seconds", {"baseline": [0.12], "compiled_guard": [0.169]}),
            ("seconds", {"baseline": [0.12] * 3, "other_guard": [0.169] * 3}),
            ("platform", None), ("logical_cpus", True),
            ("physical_memory_bytes", 0), ("proxy_sha256", "bad"),
            ("baseline_revision", "bad"),
        )
        for field, value in changes:
            report = self.report()
            report[field] = value

            with self.subTest(field=field, value=value):
                result = self.check_report(report)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("FAIL:", result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_invalid_numeric_timings_are_controlled_failures(self):
        for value in (True, "0.1", None, 0, -1, float("nan"), float("inf")):
            report = self.report()
            report["seconds"]["baseline"][0] = value

            with self.subTest(value=value):
                result = self.check_report(report)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("invalid native guard elapsed time", result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_malformed_duplicate_or_truncated_json_cannot_claim_acceptance(self):
        for text in ("", "{", "[]", '{"seconds":{},"seconds":{}}', "[" * 2000):
            with self.subTest(text=text[:30]):
                result = self.check_report(text)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("FAIL:", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
