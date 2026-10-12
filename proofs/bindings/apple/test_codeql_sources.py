import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location(
    "codeql_sources", Path(__file__).with_name("verify-codeql-sources.py")
)
sources = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sources)
PREFIX = "proofs/bindings/linux-android/"
PROJECT = Path("/private/tmp/cairn-proof/scratch/fixture-targets")
CONSUMER = PREFIX + "consumer/src/jvmMain/kotlin/Smoke.kt"
ANDROID = PREFIX + "androidConsumer/src/main/kotlin/Smoke.kt"
GENERATED = str(PROJECT) + "/sdk/build/uniffi/bindings/jvmMain/kotlin/Binding.kt"


class CodeQLSourcesTest(unittest.TestCase):
    def report(self):
        return {"#select": {"tuples": [
            ["/opt/cairn-apple-tools/fixture/" + CONSUMER[len(PREFIX):], 25],
            ["/opt/cairn-apple-tools/fixture/" + ANDROID[len(PREFIX):], 20],
            [GENERATED, 100],
        ]}}

    def test_compiled_sources_are_mapped_to_repository_paths(self):
        report = self.report()

        result = sources.verify_sources(report, [CONSUMER, ANDROID], PROJECT)

        self.assertEqual(result[CONSUMER], 25)
        self.assertEqual(result[ANDROID], 20)
        self.assertEqual(result[PREFIX + "sdk/build/uniffi/bindings/jvmMain/kotlin/Binding.kt"], 100)

    def test_missing_tracked_kotlin_source_fails(self):
        report = self.report()
        report["#select"]["tuples"].pop(1)

        with self.assertRaisesRegex(sources.CoverageError, "missing-tracked-source"):
            sources.verify_sources(report, [CONSUMER, ANDROID], PROJECT)

    def test_archived_files_cannot_replace_compiled_rows(self):
        report = {"#select": {"tuples": []}, "archived": [CONSUMER, ANDROID]}

        with self.assertRaisesRegex(sources.CoverageError, "missing-tracked-source"):
            sources.verify_sources(report, [CONSUMER, ANDROID], PROJECT)

    def test_missing_generated_bindings_fails(self):
        report = self.report()
        report["#select"]["tuples"].pop()

        with self.assertRaisesRegex(sources.CoverageError, "missing-generated-bindings"):
            sources.verify_sources(report, [CONSUMER, ANDROID], PROJECT)

    def test_malformed_evidence_fails_closed(self):
        invalid = [
            None, {}, {"#select": {"tuples": "invalid"}},
            {"#select": {"tuples": [[GENERATED, True]]}},
            {"#select": {"tuples": [[GENERATED, 0]]}},
            {"#select": {"tuples": [[GENERATED, -1]]}},
            {"#select": {"tuples": [[GENERATED]]}},
            {"#select": {"tuples": [["/unrelated/Source.kt", 1]]}},
            {"#select": {"tuples": [[str(PROJECT) + "/../Source.kt", 1]]}},
        ]
        for report in invalid:
            with self.subTest(report=report):
                with self.assertRaises(sources.CoverageError):
                    sources.verify_sources(report, [CONSUMER], PROJECT)

    def test_invalid_manifests_fail_closed(self):
        for expected in ([], None, [CONSUMER, CONSUMER], ["other/Source.kt"], [42]):
            with self.subTest(expected=expected):
                with self.assertRaises(sources.CoverageError):
                    sources.verify_sources(self.report(), expected, PROJECT)
