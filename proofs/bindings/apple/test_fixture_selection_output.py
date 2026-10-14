import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class FixtureSelectionOutputTest(unittest.TestCase):
    def run_selection_probe(self, directory, command):
        root = Path(directory)
        tools = root / "tools"
        (tools / "gradle/bin").mkdir(parents=True)
        (tools / "fixture/sdk").mkdir(parents=True)
        (tools / "fixture/consumer").mkdir()
        (tools / "fixture/androidConsumer").mkdir()
        for filename in (
            "settings.gradle.kts", "sdk/build.gradle.kts", "sdk/apple.gradle.kts",
            "consumer/build.gradle.kts", "androidConsumer/build.gradle.kts",
        ):
            (tools / "fixture" / filename).write_text("")
        home = root / "home"
        home.mkdir()
        gradle = tools / "gradle/bin/gradle"
        gradle.write_text(
            "#!/bin/bash\n"
            'for argument in "$@"; do\n'
            '  if [ "$argument" = -PcairnProofPlatform=invalid ]; then\n'
            "    printf 'Unsupported cairnProofPlatform: invalid\\n' >&2\n"
            "    exit 1\n"
            "  fi\n"
            "done\n"
            "printf 'controlled Gradle progress\\n'\n"
            "printf 'controlled Gradle diagnostic\\n' >&2\n"
            + command + "\n"
        )
        gradle.chmod(0o755)
        scripts = Path(__file__).parent
        output = root / "retained.log"
        result = subprocess.run(
            [
                sys.executable, str(scripts.parent / "linux-android/bounded-proof.py"),
                "--seconds", "2", str(output), "/bin/bash",
                str(scripts / "check-fixture-selection.sh"), str(tools),
            ],
            env={**os.environ, "HOME": str(home)},
            capture_output=True, text=True, timeout=15,
        )
        return result, output.read_text(), (home / "fixture-default.log").read_text()

    def test_selection_progress_is_retained_when_the_real_collector_expires(self):
        with tempfile.TemporaryDirectory() as directory:
            result, retained, selection_log = self.run_selection_probe(
                directory, "exec /bin/sleep 60",
            )

        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn("FAIL: proof deadline exceeded", result.stderr)
        self.assertIn("PASS: fixture rejects invalid selection", retained)
        self.assertIn("controlled Gradle progress\ncontrolled Gradle diagnostic\n", retained)
        self.assertEqual(result.stdout, retained)
        self.assertEqual(
            selection_log, "controlled Gradle progress\ncontrolled Gradle diagnostic\n",
        )

    def test_selection_failure_keeps_its_exit_status_and_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            result, retained, selection_log = self.run_selection_probe(directory, "exit 17")

        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertIn("controlled Gradle progress\ncontrolled Gradle diagnostic\n", retained)
        self.assertEqual(result.stdout, retained)
        self.assertEqual(
            selection_log, "controlled Gradle progress\ncontrolled Gradle diagnostic\n",
        )
