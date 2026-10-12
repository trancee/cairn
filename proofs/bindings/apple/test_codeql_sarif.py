import copy
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "codeql_sarif", Path(__file__).with_name("normalize-codeql-sarif.py")
)
sarif = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sarif)
PROJECT = Path("/private/tmp/cairn-proof/scratch/fixture-targets")
PREFIX = "proofs/bindings/linux-android/"


class CodeQLSarifTest(unittest.TestCase):
    def document(self, location):
        return {"version": "2.1.0", "runs": [{
            "tool": {"driver": {"name": "CodeQL"}},
            "originalUriBaseIds": {"%SRCROOT%": {"uri": "file:///opt/cairn-apple-tools/fixture/"}},
            "artifacts": [{"location": copy.deepcopy(location)}],
            "results": [{"ruleId": "java/example", "locations": [{
                "physicalLocation": {"artifactLocation": location, "region": {"startLine": 7}}
            }]}],
        }]}

    def test_fixture_relative_locations_gain_repository_prefix(self):
        original = self.document({"uri": "consumer/Smoke.kt", "uriBaseId": "%SRCROOT%"})

        result = sarif.normalize_sarif(original, PROJECT)

        expected = {"uri": PREFIX + "consumer/Smoke.kt"}
        self.assertEqual(result["runs"][0]["artifacts"][0]["location"], expected)
        self.assertEqual(
            result["runs"][0]["results"][0]["locations"][0]["physicalLocation"],
            {"artifactLocation": expected, "region": {"startLine": 7}},
        )
        self.assertIn("uriBaseId", original["runs"][0]["artifacts"][0]["location"])

    def test_generated_source_keeps_its_real_build_path(self):
        document = self.document({"uri": PROJECT.as_uri() + "/sdk/build/uniffi/Binding.kt"})

        result = sarif.normalize_sarif(document, PROJECT)

        self.assertEqual(
            result["runs"][0]["artifacts"][0]["location"],
            {"uri": PREFIX + "sdk/build/uniffi/Binding.kt"},
        )

    def test_codeql_implicit_srcroot_uses_the_database_source_root(self):
        document = self.document({"uri": "consumer/Smoke.kt", "uriBaseId": "%SRCROOT%"})
        document["runs"][0].pop("originalUriBaseIds")

        result = sarif.normalize_sarif(document, PROJECT)

        self.assertEqual(
            result["runs"][0]["artifacts"][0]["location"],
            {"uri": PREFIX + "consumer/Smoke.kt"},
        )

    def test_file_uri_escaping_is_preserved(self):
        document = self.document({"uri": "file:///opt/cairn-apple-tools/fixture/consumer/A%20B.kt"})

        result = sarif.normalize_sarif(document, PROJECT)

        self.assertEqual(
            result["runs"][0]["artifacts"][0]["location"]["uri"],
            PREFIX + "consumer/A%20B.kt",
        )

    def test_relative_generated_path_resolves_before_mapping(self):
        document = self.document({
            "uri": "../../../private/tmp/cairn-proof/scratch/fixture-targets/sdk/Binding.kt",
            "uriBaseId": "%SRCROOT%",
        })

        result = sarif.normalize_sarif(document, PROJECT)

        self.assertEqual(
            result["runs"][0]["artifacts"][0]["location"]["uri"], PREFIX + "sdk/Binding.kt",
        )

    def test_invalid_or_out_of_scope_locations_fail_without_mutation(self):
        for location in (
            {"uri": "file:///unrelated/Source.kt"},
            {"uri": "https://example.test/Source.kt"},
            {"uri": "../../unrelated/Source.kt", "uriBaseId": "%SRCROOT%"},
            {"uri": "consumer/Smoke.kt", "uriBaseId": "unknown"},
            {"uri": "consumer/Smoke.kt", "uriBaseId": []},
            {"uri": "consumer/A%invalid.kt"},
            {"uri": "file://unrelated/Source.kt"},
            {"uri": 42},
        ):
            original = self.document(location)
            before = copy.deepcopy(original)

            with self.subTest(location=location):
                with self.assertRaises(sarif.MappingError):
                    sarif.normalize_sarif(original, PROJECT)

                self.assertEqual(original, before)

    def test_malformed_sarif_fails(self):
        for document in (None, {}, {"version": "2.1.0", "runs": []}):
            with self.subTest(document=document):
                with self.assertRaises(sarif.MappingError):
                    sarif.normalize_sarif(document, PROJECT)

    def test_truncated_cli_report_does_not_create_output(self):
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory) / "report.sarif"
            report.write_text('{"version":')
            output = Path(directory) / "mapped.sarif"

            result = subprocess.run([
                sys.executable, "-I", str(Path(__file__).with_name("normalize-codeql-sarif.py")),
                str(report), str(output), str(PROJECT),
            ], capture_output=True, text=True, timeout=5)

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "FAIL: Kotlin CodeQL SARIF mapping: JSONDecodeError\n")
            self.assertFalse(output.exists())
