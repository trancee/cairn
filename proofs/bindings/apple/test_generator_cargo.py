import os
import subprocess
import unittest
from pathlib import Path


class GeneratorCargoTest(unittest.TestCase):
    def run_adapter(self, arguments, exit_code=0):
        script = Path(__file__).with_name("generator-cargo.sh")
        command = """
exec() {
  printf 'CAIRN_TEST_ARGUMENTS\\0'
  printf '%s\\0' "$@"
  exit "$CAIRN_TEST_EXIT"
}
source "$1" "${@:2}"
"""
        return subprocess.run(
            ["/bin/bash", "-c", command, "adapter-test", str(script), *arguments],
            env={**os.environ, "CAIRN_TEST_EXIT": str(exit_code)},
            capture_output=True, timeout=5,
        )

    def arguments(self, result):
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        _, arguments = result.stdout.split(b"CAIRN_TEST_ARGUMENTS\0", 1)
        return [value.decode() for value in arguments.rstrip(b"\0").split(b"\0")]

    def test_install_uses_the_same_explicit_host_target_as_fixture_compilation(self):
        supplied = [
            "--locked", "--root", "/controlled/install", "--force",
            "--path", "/opt/cairn-apple-tools/ubique/bindgen",
            "--bin", "uniffi-bindgen-kotlin-multiplatform",
            "uniffi_bindgen_kotlin_multiplatform",
        ]

        result = self.run_adapter(["install", *supplied])

        self.assertEqual(self.arguments(result), [
            "/opt/cairn-apple-tools/rust/bin/cargo", "install", "--debug",
            "--target", "aarch64-apple-darwin", *supplied,
        ])

    def test_caller_cannot_override_the_owned_target_or_directory(self):
        for option in (
            "--target", "--target=x86_64-apple-darwin",
            "--target-dir", "--target-dir=/controlled/other",
        ):
            with self.subTest(option=option):
                result = self.run_adapter([
                    "install", "--path", "/opt/cairn-apple-tools/ubique/bindgen", option,
                ])

                self.assertEqual(result.returncode, 2, result.stderr.decode())
                self.assertIn(b"generator compilation context must be owned", result.stderr)
                self.assertNotIn(b"CAIRN_TEST_ARGUMENTS", result.stdout)

    def test_existing_profile_and_source_boundaries_remain_enforced(self):
        for arguments in (
            ["--path", "/controlled/unpinned"],
            ["--path", "/opt/cairn-apple-tools/ubique/bindgen", "--debug"],
            ["--path", "/opt/cairn-apple-tools/ubique/bindgen", "--profile=release"],
        ):
            with self.subTest(arguments=arguments):
                result = self.run_adapter(["install", *arguments])

                self.assertEqual(result.returncode, 2, result.stderr.decode())
                self.assertIn(b"FAIL:", result.stderr)
                self.assertNotIn(b"CAIRN_TEST_ARGUMENTS", result.stdout)

    def test_sdk_commands_are_forwarded_without_profile_or_target_changes(self):
        supplied = ["rustc", "--lib", "--target", "aarch64-apple-ios", "--release"]

        result = self.run_adapter(supplied)

        self.assertEqual(self.arguments(result), [
            "/opt/cairn-apple-tools/rust/bin/cargo", *supplied,
        ])

    def test_child_failure_is_preserved(self):
        result = self.run_adapter(["locate-project", "--workspace"], exit_code=17)

        self.assertEqual(result.returncode, 17, result.stderr.decode())
