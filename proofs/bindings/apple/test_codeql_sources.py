import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
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
REPOSITORY = Path("/private/tmp/cairn-proof/scratch/repository-build")
APP = "app/src/commonMain/kotlin/ch/trancee/cairn/app/App.kt"
SDK_TEST = "sdk/src/commonTest/kotlin/ch/trancee/cairn/sdk/CoreBindingTest.kt"
ROOT_GENERATED = str(REPOSITORY) + "/sdk/build/uniffi/bindings/jvmMain/kotlin/cairn_ffi.kt"
EXPECTED = [CONSUMER, ANDROID, APP, SDK_TEST]


class CodeQLSourcesTest(unittest.TestCase):
    def report(self):
        return {"#select": {"tuples": [
            ["/opt/cairn-apple-tools/fixture/" + CONSUMER[len(PREFIX):], 25],
            ["/opt/cairn-apple-tools/fixture/" + ANDROID[len(PREFIX):], 20],
            [GENERATED, 100],
            ["/opt/cairn-apple-tools/repository-inputs/source/" + APP, 30],
            [str(REPOSITORY) + "/" + SDK_TEST, 40],
            [ROOT_GENERATED, 200],
        ]}}

    def verify(self, report, expected=EXPECTED):
        return sources.verify_sources(report, expected, PROJECT, REPOSITORY)

    def test_compiled_sources_are_mapped_to_repository_paths(self):
        report = self.report()

        result = self.verify(report)

        self.assertEqual(result[CONSUMER], 25)
        self.assertEqual(result[ANDROID], 20)
        self.assertEqual(result[PREFIX + "sdk/build/uniffi/bindings/jvmMain/kotlin/Binding.kt"], 100)

    def test_root_build_sources_map_without_the_fixture_prefix(self):
        report = self.report()

        result = self.verify(report)

        self.assertEqual(result[APP], 30)
        self.assertEqual(result[SDK_TEST], 40)
        self.assertEqual(result["sdk/build/uniffi/bindings/jvmMain/kotlin/cairn_ffi.kt"], 200)

    def test_missing_tracked_kotlin_source_fails(self):
        report = self.report()
        report["#select"]["tuples"].pop(1)

        with self.assertRaisesRegex(sources.CoverageError, "missing-tracked-source"):
            self.verify(report)

    def test_missing_tracked_root_kotlin_source_fails(self):
        report = self.report()
        report["#select"]["tuples"].pop(3)

        with self.assertRaisesRegex(sources.CoverageError, "missing-tracked-source"):
            self.verify(report)

    def test_archived_files_cannot_replace_compiled_rows(self):
        report = {"#select": {"tuples": []}, "archived": EXPECTED}

        with self.assertRaisesRegex(sources.CoverageError, "missing-tracked-source"):
            self.verify(report)

    def test_missing_generated_bindings_of_either_build_fails(self):
        for generated in (GENERATED, ROOT_GENERATED):
            report = self.report()
            report["#select"]["tuples"] = [
                row for row in report["#select"]["tuples"] if row[0] != generated
            ]

            with self.subTest(generated=generated):
                with self.assertRaisesRegex(sources.CoverageError, "missing-generated-bindings"):
                    self.verify(report)

    def test_malformed_evidence_fails_closed(self):
        invalid = [
            None, {}, {"#select": {"tuples": "invalid"}},
            {"#select": {"tuples": [[GENERATED, True]]}},
            {"#select": {"tuples": [[GENERATED, 0]]}},
            {"#select": {"tuples": [[GENERATED, -1]]}},
            {"#select": {"tuples": [[GENERATED]]}},
            {"#select": {"tuples": [["/unrelated/Source.kt", 1]]}},
            {"#select": {"tuples": [[str(PROJECT) + "/../Source.kt", 1]]}},
            {"#select": {"tuples": [[str(REPOSITORY) + "/../Source.kt", 1]]}},
            {"#select": {"tuples": [["/opt/cairn-apple-tools/repository-inputs/rust/Source.kt", 1]]}},
            {"#select": {"tuples": [["/opt/cairn-apple-tools/repository-inputs/source/Source.java", 1]]}},
        ]
        for report in invalid:
            with self.subTest(report=report):
                with self.assertRaises(sources.CoverageError):
                    self.verify(report, [CONSUMER])

    def test_invalid_manifests_fail_closed(self):
        for expected in (
            [], None, [CONSUMER, CONSUMER], [42], ["/abs/Source.kt"], ["../Source.kt"],
            ["app/../Source.kt"], ["app/./Source.kt"], ["app//Source.kt"], ["app/Source.java"],
        ):
            with self.subTest(expected=expected):
                with self.assertRaises(sources.CoverageError):
                    self.verify(self.report(), expected)

    def test_truncated_cli_report_has_redacted_typed_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.json"
            report.write_text('{"#select":')

            result = subprocess.run([
                sys.executable, "-I", str(Path(__file__).with_name("verify-codeql-sources.py")),
                str(report), str(Path(directory) / "manifest.json"), str(PROJECT),
                str(REPOSITORY),
            ], capture_output=True, text=True, timeout=5)

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "FAIL: Kotlin CodeQL coverage: JSONDecodeError\n")
