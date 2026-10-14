import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "benchmark_bindgen_reuse", Path(__file__).with_name("benchmark-bindgen-reuse.py"),
)
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)


class BindgenBenchmarkTest(unittest.TestCase):
    def test_prepares_the_same_immutable_vendor_symlink_as_the_owning_installer(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / "cargo-offline").mkdir()
            tools = home / "controlled-tools"

            benchmark.prepare_vendor_config(home, tools)

            config = home / "cargo-offline/config.toml"
            self.assertTrue(config.is_symlink())
            self.assertEqual(config.readlink(), tools / "cargo-inputs/vendor.toml")

    def test_rejects_conflicting_vendor_configuration(self):
        for existing in ("regular-file", "wrong-symlink"):
            with self.subTest(existing=existing), tempfile.TemporaryDirectory() as directory:
                home = Path(directory)
                (home / "cargo-offline").mkdir()
                config = home / "cargo-offline/config.toml"
                if existing == "regular-file":
                    config.write_text("controlled conflicting configuration")
                else:
                    config.symlink_to(home / "unapproved-vendor")

                with self.assertRaises(ValueError):
                    benchmark.prepare_vendor_config(home, home / "controlled-tools")

    def counts(self, messages, allow_preamble=False):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cargo.jsonl"
            path.write_text("\n".join(
                message if isinstance(message, str) else json.dumps(message)
                for message in messages
            ) + "\n")
            return benchmark.artifact_counts(path, allow_preamble)

    def generator(self, fresh=False):
        return {
            "reason": "compiler-artifact", "fresh": fresh,
            "target": {"name": benchmark.BINARY},
        }

    def test_counts_actual_fresh_and_compiled_artifacts_separately(self):
        messages = [
            benchmark.PREAMBLE,
            {"reason": "compiler-artifact", "fresh": True, "target": {"name": "shared"}},
            self.generator(),
            {"reason": "build-finished", "success": True},
        ]

        counts = self.counts(messages, allow_preamble=True)

        self.assertEqual(counts, {"fresh": 1, "compiled": 1})

    def test_rejects_missing_duplicate_or_reused_generator(self):
        for messages in ([], [self.generator(True)], [self.generator(), self.generator()]):
            with self.subTest(messages=messages):
                with self.assertRaises(ValueError):
                    self.counts(messages)

    def test_rejects_malformed_failed_or_unknown_cargo_evidence(self):
        for message in (
            [], {"reason": "compiler-artifact", "fresh": 1, "target": {}},
            {"reason": "build-finished", "success": False}, {"reason": "unknown"},
            "not JSON", benchmark.PREAMBLE,
        ):
            with self.subTest(message=message):
                with self.assertRaises(ValueError):
                    self.counts([self.generator(), message])

    def report(self, candidate_seconds=90, candidate_first=False):
        report = {
            "baseline_revision": benchmark.BASELINE_REVISION,
            "platform": "controlled-arm64", "python": "3.9.6", "cpu_count": 3,
            "rust": "controlled-pinned-rust",
            "order": ["candidate", "baseline"] if candidate_first else ["baseline", "candidate"],
            "samples": {
                "baseline": {
                    "seconds": 100, "artifacts": {"fresh": 0, "compiled": 10},
                    "architecture": "arm64", "explicit_target": False,
                },
                "candidate": {
                    "seconds": candidate_seconds, "artifacts": {"fresh": 4, "compiled": 6},
                    "architecture": "arm64", "explicit_target": True,
                },
            },
        }
        for field in (
            "candidate_adapter_sha256", "fixture_config_sha256",
            "fixture_source_sha256", "fixture_lock_sha256", "generator_lock_sha256",
            "benchmark_sha256",
        ):
            report[field] = "0" * 64
        return report

    def test_summarizes_paired_ratios_and_enforces_the_regression_budget(self):
        reports = [self.report(), self.report(80, True), self.report(100)]

        result = benchmark.summarize(reports)

        self.assertEqual(result["paired_ratios"], [0.9, 0.8, 1.0])
        self.assertEqual(result["median_ratio"], 0.9)
        self.assertEqual(result["regression_limit"], 1.1)

    def test_rejects_incomparable_or_incomplete_samples(self):
        changed = self.report()
        changed["generator_lock_sha256"] = "1" * 64
        invalid_duration = self.report()
        invalid_duration["samples"]["candidate"]["seconds"] = float("nan")
        for reports in (
            [self.report(), self.report()],
            [self.report(), self.report(), self.report()],
            [self.report(), self.report(90, True), changed],
            [self.report(), self.report(90, True), invalid_duration],
            [self.report(120), self.report(120, True), self.report(120)],
        ):
            with self.subTest(reports=reports):
                with self.assertRaises(ValueError):
                    benchmark.summarize(reports)
