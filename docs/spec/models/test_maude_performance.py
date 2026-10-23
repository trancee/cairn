"""Approved workload budgets at the benchmark CLI/report seam."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import unittest.mock

from equations.maude_native import NATIVE_DIRECTORY, source_identity
from equations.maude_runner import GuardError

sys.path.insert(0, str(NATIVE_DIRECTORY))

import experiment


class CommittedBaselineTests(unittest.TestCase):
    def repository(self, temporary):
        root = Path(temporary)
        replay = root / "docs/spec/models/replay.py"
        replay.parent.mkdir(parents=True)
        replay.write_text("committed\n")
        for command in (
            ["init", "-q"], ["add", "."],
            ["-c", "user.name=fixture", "-c", "user.email=fixture@invalid",
             "-c", "commit.gpgsign=false", "commit", "-q", "-m", "baseline"],
        ):
            subprocess.run(
                ["git", "-C", str(root), *command], check=True, capture_output=True, timeout=10,
                env=experiment.git_environment(),
            )
        return root, replay

    def test_fixture_repository_ignores_inherited_git_environment(self):
        with tempfile.TemporaryDirectory() as sentinel, tempfile.TemporaryDirectory() as temporary:
            clean = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
            subprocess.run(["git", "init", "-q", sentinel], check=True, capture_output=True, timeout=10, env=clean)
            sentinel_git = str(Path(sentinel) / ".git")
            inherited = {"GIT_DIR": sentinel_git, "GIT_INDEX_FILE": str(Path(sentinel_git) / "index")}
            with unittest.mock.patch.dict(os.environ, inherited):
                self.repository(temporary)

            sentinel_head = subprocess.run(
                ["git", "-C", sentinel, "rev-parse", "--verify", "-q", "HEAD"],
                capture_output=True, timeout=10, env=clean,
            )

        self.assertNotEqual(sentinel_head.returncode, 0)

    def test_baseline_state_is_independent_of_the_working_directory(self):
        with tempfile.TemporaryDirectory() as temporary, tempfile.TemporaryDirectory() as elsewhere:
            root, replay = self.repository(temporary)
            replay.write_text("edited\n")
            previous = os.getcwd()
            os.chdir(elsewhere)
            try:
                edited = experiment.committed_baseline(root)
                replay.write_text("committed\n")
                restored = experiment.committed_baseline(root)
            finally:
                os.chdir(previous)

        self.assertFalse(edited)
        self.assertTrue(restored)

    def test_unavailable_baseline_state_fails_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(GuardError, "committed replay baseline unavailable"):
                experiment.committed_baseline(Path(temporary))

    def test_acceptance_requires_a_committed_baseline(self):
        with self.assertRaisesRegex(GuardError, "requires a committed replay baseline"):
            experiment.baseline_label(3, committed=False)

    def test_screening_labels_an_uncommitted_baseline(self):
        self.assertEqual(experiment.baseline_label(3, committed=True), experiment.COMMITTED_BASELINE)
        self.assertEqual(experiment.baseline_label(1, committed=True), experiment.COMMITTED_BASELINE)
        self.assertEqual(experiment.baseline_label(1, committed=False), experiment.WORKING_TREE_BASELINE)


class NativePerformanceCommandTests(unittest.TestCase):
    def test_unreviewed_export_identifies_the_phase_and_digests_without_its_payload(self):
        output = "unreviewed native export\n"
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "tamarin-prover"
            executable.write_text(f"#!{sys.executable}\nprint({output!r}, end='')\n")
            executable.chmod(0o755)
            environment = dict(os.environ, PATH=temporary + os.pathsep + os.environ["PATH"])

            result = subprocess.run(
                [sys.executable, str(NATIVE_DIRECTORY / "experiment.py"),
                 "--proxy", str(executable), "--workload", "startup", "--rounds", "1"],
                text=True, capture_output=True, env=environment, timeout=5,
            )

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("unreviewed baseline export", result.stderr)
        self.assertIn(hashlib.sha256(output.encode()).hexdigest(), result.stderr)
        self.assertIn("ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64", result.stderr)
        self.assertNotIn(output.strip(), result.stdout + result.stderr)

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

    def child_resources(self):
        return {
            label: [{
                "user_seconds": 0.1, "system_seconds": 0.02,
                "voluntary_context_switches": 32, "involuntary_context_switches": 3,
            } for _ in range(3)]
            for label in ("baseline", "compiled_guard")
        }

    def test_malformed_child_resource_diagnostics_cannot_claim_acceptance(self):
        malformed = [
            None, [], {}, {"baseline": [], "compiled_guard": []},
            {"other": [], "compiled_guard": []},
        ]
        incomplete = self.child_resources()
        incomplete["baseline"].pop()
        malformed.append(incomplete)
        for field, values in (
            ("user_seconds", (True, "0.1", None, -1, float("nan"), float("inf"))),
            ("system_seconds", (True, -1, float("inf"))),
            ("voluntary_context_switches", (True, 0.5, -1, "32")),
            ("involuntary_context_switches", (True, 0.5, -1, None)),
        ):
            for value in values:
                resources = self.child_resources()
                resources["baseline"][0][field] = value
                malformed.append(resources)
        missing = self.child_resources()
        del missing["compiled_guard"][0]["system_seconds"]
        malformed.append(missing)
        for entry in (None, [], dict(self.child_resources()["baseline"][0], extra=0)):
            resources = self.child_resources()
            resources["compiled_guard"][0] = entry
            malformed.append(resources)
        for resources in malformed:
            report = self.report()
            report["waited_child_resources"] = resources
            with self.subTest(resources=resources):
                result = self.check_report(report)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("child-resource diagnostics", result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_child_resource_diagnostics_do_not_replace_the_wall_time_budget(self):
        report = self.report(guarded=0.170001)
        report["waited_child_resources"] = self.child_resources()

        result = self.check_report(report)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("50 ms startup-only budget", result.stderr)

    def test_process_profiled_measurements_cannot_claim_budget_acceptance(self):
        for field, reason in (
            ("native_process_profiles", "process profiling is diagnostic only"),
            ("native_linux_comparison", "Linux comparison is diagnostic only"),
            ("tamarin_runtime_profiles", "Tamarin RTS profiling is diagnostic only"),
            ("native_phase_profiles", "native phase profiling is diagnostic only"),
        ):
            report = self.report()
            report[field] = {}
            with self.subTest(field=field):
                result = self.check_report(report)

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn(reason, result.stderr)

    def test_well_formed_child_resources_retain_existing_report_acceptance(self):
        report = self.report()
        report["waited_child_resources"] = self.child_resources()
        report["waited_child_resources"]["compiled_guard"][0] = {
            "user_seconds": 0, "system_seconds": 0,
            "voluntary_context_switches": 0, "involuntary_context_switches": 0,
        }

        result = self.check_report(report)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS:", result.stdout)

    def test_startup_report_within_the_approved_additive_budget_is_accepted(self):
        result = self.check_report(self.report())

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS:", result.stdout)

    def test_reviewed_native_linux_startup_retains_the_additive_limit(self):
        report = self.report(guarded=0.17)
        report["export_sha256"] = "59548c48458d4bdf8e7fee57ba0257642f0a21bfd94c2004a4fb990781659fae"
        report["platform"] = "Linux-native-fixture"
        report["architecture"] = "x86_64"

        result = self.check_report(report)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_exact_startup_limit_uses_the_paired_medians(self):
        report = self.report()
        report["seconds"] = {
            "baseline": [0.10, 0.12, 0.30],
            "compiled_guard": [0.14, 0.17, 0.35],
        }

        result = self.check_report(report)

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_startup_above_fifty_milliseconds_is_rejected(self):
        for digest in (
            "ecd7e735a4f3fc7119dbd00d2edbd245c01900b6035c0dd2e271bea4c5607b64",
            "59548c48458d4bdf8e7fee57ba0257642f0a21bfd94c2004a4fb990781659fae",
        ):
            report = self.report(guarded=0.170001)
            report["export_sha256"] = digest

            with self.subTest(digest=digest):
                result = self.check_report(report)

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

    def test_reviewed_native_linux_export_retains_the_full_export_limit(self):
        report = self.report("full-export")
        report["export_sha256"] = "1b66b2a76902af6c98de7b22edbe6f4d8fddc27cd2adb580db6d5eff639dbd48"
        report["platform"] = "Linux-native-fixture"
        report["architecture"] = "x86_64"
        report["seconds"] = {"baseline": [20] * 3, "compiled_guard": [22] * 3}

        result = self.check_report(report, "full-export")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_linux_export_cannot_bypass_relative_limit_with_startup_allowance(self):
        for baseline, guarded in ((20, 22.001), (0.12, 0.169)):
            report = self.report("full-export")
            report["export_sha256"] = "1b66b2a76902af6c98de7b22edbe6f4d8fddc27cd2adb580db6d5eff639dbd48"
            report["seconds"] = {"baseline": [baseline] * 3, "compiled_guard": [guarded] * 3}

            with self.subTest(baseline=baseline, guarded=guarded):
                result = self.check_report(report, "full-export")

                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("10% full-export budget", result.stderr)

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
            ("export_sha256", []), ("export_sha256", {}), ("export_sha256", True),
            ("seconds", {"baseline": [0.12], "compiled_guard": [0.169]}),
            ("seconds", {"baseline": [0.12] * 3, "other_guard": [0.169] * 3}),
            ("platform", None), ("logical_cpus", True),
            ("physical_memory_bytes", 0), ("proxy_sha256", "bad"),
            ("baseline_revision", "bad"), ("baseline", experiment.WORKING_TREE_BASELINE),
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
