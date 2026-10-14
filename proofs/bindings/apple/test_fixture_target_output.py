import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class FixtureTargetOutputTest(unittest.TestCase):
    def run_target_probe(self, directory, command):
        root = Path(directory)
        tools = root / "tools"
        (tools / "gradle/bin").mkdir(parents=True)
        (tools / "gradle-dependencies/modules-2").mkdir(parents=True)
        home = root / "home"
        home.mkdir()
        (tools / "create-plugin-project.sh").write_text("#!/bin/bash\nexit 0\n")
        gradle = tools / "gradle/bin/gradle"
        gradle.write_text(
            "#!/bin/bash\n"
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
                str(scripts / "check-fixture-targets.sh"), str(tools), sys.executable,
            ],
            env={**os.environ, "HOME": str(home)},
            capture_output=True, text=True, timeout=15,
        )
        return result, output.read_text(), (home / "fixture-targets.log").read_text()

    def test_target_progress_is_retained_when_the_real_collector_expires(self):
        with tempfile.TemporaryDirectory() as directory:
            result, retained, target_log = self.run_target_probe(
                directory, "exec /bin/sleep 60",
            )

        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn("FAIL: proof deadline exceeded", result.stderr)
        self.assertEqual(
            retained, "controlled Gradle progress\ncontrolled Gradle diagnostic\n",
        )
        self.assertEqual(result.stdout, retained)
        self.assertEqual(target_log, retained)

    def test_target_failure_keeps_its_exit_status_and_diagnostics(self):
        with tempfile.TemporaryDirectory() as directory:
            result, retained, target_log = self.run_target_probe(directory, "exit 17")

        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertEqual(
            retained, "controlled Gradle progress\ncontrolled Gradle diagnostic\n",
        )
        self.assertEqual(result.stdout, retained)
        self.assertEqual(target_log, retained)
