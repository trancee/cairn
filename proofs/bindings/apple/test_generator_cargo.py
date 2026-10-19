import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("generator-cargo.sh")
PINNED_CARGO = "/opt/cairn-apple-tools/rust/bin/cargo"
GENERATOR = "/opt/cairn-apple-tools/ubique/bindgen"


class GeneratorCargoTest(unittest.TestCase):
    def run_adapter(self, *arguments, environment=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            record = root / "record"
            cargo = root / "cargo"
            cargo.write_text(
                "#!/bin/bash\n"
                f"{{ printf '%s\\n' \"$@\"; printf 'DEBUG=%s\\n' \"${{CARGO_PROFILE_DEV_DEBUG-unset}}\"; }} > '{record}'\n"
            )
            cargo.chmod(0o755)
            adapter = root / "adapter.sh"
            adapter.write_text(SCRIPT.read_text().replace(PINNED_CARGO, str(cargo)))
            env = {"PATH": "/usr/bin:/bin"}
            env.update(environment or {})
            result = subprocess.run(
                ["/bin/bash", str(adapter), *arguments],
                capture_output=True, text=True, env=env, timeout=5,
            )
            recorded = record.read_text().splitlines() if record.exists() else None
            return result, recorded

    def test_generator_install_is_debug_without_debuginfo(self):
        result, recorded = self.run_adapter(
            "install", "--locked", "--root", "/scratch/bin", "--path", GENERATOR,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(recorded, [
            "install", "--debug", "--locked", "--root", "/scratch/bin", "--path", GENERATOR,
            "DEBUG=0",
        ])

    def test_inherited_debuginfo_setting_cannot_override_the_adapter(self):
        result, recorded = self.run_adapter(
            "install", "--path", GENERATOR, environment={"CARGO_PROFILE_DEV_DEBUG": "2"},
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(recorded[-1], "DEBUG=0")

    def test_other_cargo_commands_forward_unchanged(self):
        result, recorded = self.run_adapter(
            "rustc", "--lib", "--target", "aarch64-apple-darwin",
            environment={"CARGO_PROFILE_DEV_DEBUG": "2"},
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(recorded, [
            "rustc", "--lib", "--target", "aarch64-apple-darwin", "DEBUG=2",
        ])

    def test_competing_profile_arguments_are_rejected(self):
        for argument in ["--debug", "--profile", "--profile=release"]:
            with self.subTest(argument=argument):
                result, recorded = self.run_adapter("install", "--path", GENERATOR, argument)

                self.assertEqual(result.returncode, 2)
                self.assertIsNone(recorded)

    def test_installation_from_other_sources_is_rejected(self):
        for arguments in [("install", "--path", "/tmp/other"), ("install", "uniffi")]:
            with self.subTest(arguments=arguments):
                result, recorded = self.run_adapter(*arguments)

                self.assertEqual(result.returncode, 2)
                self.assertIsNone(recorded)


if __name__ == "__main__":
    unittest.main()
