import os
from pathlib import Path
import re
import stat
import subprocess
import tempfile
import unittest


SCRIPTS = Path(__file__).parent
SCRIPT = SCRIPTS / "seed-gradle-home.sh"
RUNNER = SCRIPTS / "run-resource-probes.sh"
FREEZE = SCRIPTS / "freeze-gradle-inputs.sh"
WORKFLOW = SCRIPTS.parents[2] / ".github/workflows/apple-toolchain-preparation.yml"


def seed(source, home):
    return subprocess.run(["/bin/bash", str(SCRIPT), str(source), str(home)],
                          capture_output=True, text=True, timeout=30)


def freeze_read_only(root):
    for current, directories, files in os.walk(root):
        for name in files + directories:
            path = Path(current) / name
            path.chmod(path.stat().st_mode & ~0o222)
    root.chmod(root.stat().st_mode & ~0o222)


def thaw(root):
    for current, directories, files in os.walk(root):
        Path(current).chmod(Path(current).stat().st_mode | stat.S_IWUSR)
        for name in files:
            path = Path(current) / name
            path.chmod(path.stat().st_mode | stat.S_IWUSR)


class SeedGradleHomeTest(unittest.TestCase):
    def test_seed_adds_missing_entries_writably_without_replacing_existing_ones(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "gradle-warm-home"
            (source / "9.7.0/transforms/abc").mkdir(parents=True)
            (source / "9.7.0/transforms/abc/metadata.bin").write_bytes(b"seeded")
            (source / "9.7.0/kotlin-dsl").mkdir()
            (source / "9.7.0/kotlin-dsl/script.bin").write_bytes(b"seeded")
            freeze_read_only(source)
            home = root / "gradle"
            (home / "caches/9.7.0/kotlin-dsl").mkdir(parents=True)
            (home / "caches/9.7.0/kotlin-dsl/script.bin").write_bytes(b"probe-owned")

            result = seed(source, home)

            caches = home / "caches/9.7.0"
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((caches / "transforms/abc/metadata.bin").read_bytes(), b"seeded")
            self.assertEqual((caches / "kotlin-dsl/script.bin").read_bytes(), b"probe-owned")
            for path in [caches / "transforms", caches / "transforms/abc",
                         caches / "transforms/abc/metadata.bin"]:
                self.assertTrue(path.stat().st_mode & stat.S_IWUSR, path)
            self.assertFalse((source / "9.7.0/transforms/abc").stat().st_mode & 0o222)
            self.assertIn("PASS: warm Gradle home seeded", result.stdout)
            thaw(source)

    def test_missing_seed_fails_before_creating_caches(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            home = root / "gradle"
            home.mkdir()

            result = seed(root / "absent", home)

            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((home / "caches").exists())


class SeedWiringTest(unittest.TestCase):
    def test_probe_user_seeds_fixture_targets_outside_its_deadline(self):
        arm = re.search(r"^    fixture-targets\)\n(.*?)^      ;;$", RUNNER.read_text(),
                        re.MULTILINE | re.DOTALL).group(1)
        seeding = arm.index('sudo -n -u "$user"')
        command = re.match(r'(?:\\\n|[^\n])*', arm[seeding:]).group(0)

        self.assertLess(seeding, arm.index("uid-supervisor.py"))
        self.assertIn('/usr/bin/sandbox-exec -D "INPUTS=$work/inputs" -D "SCRATCH=$volume"',
                      command)
        self.assertIn('-D PRIVATE_IPC=false -f "$work/build.sb"', command)
        self.assertIn('"$work/inputs/seed-gradle-home.sh"', command)
        self.assertIn('"$tools/gradle-warm-home" "$volume/gradle"', command)
        self.assertIn('cp "$scripts/seed-gradle-home.sh" "$work/inputs/seed-gradle-home.sh"',
                      RUNNER.read_text())

    def test_freeze_publishes_a_read_only_lockless_warm_home_with_its_manifest(self):
        text = FREEZE.read_text()

        self.assertIn("warm=/opt/cairn-apple-tools/gradle-warm-home", text)
        self.assertIn('"$prepared/gradle-home/caches/9.7.0/transforms"', text)
        self.assertIn('"$prepared/gradle-home/caches/jars-9"', text)
        self.assertIn('chmod -R a+rX,a-w "$warm"', text)
        self.assertIn('gradle-warm-home \\\n  > "$prepared/gradle-warm-home.sha256"', text)

    def test_workflow_verifies_and_retains_the_warm_home_manifest(self):
        text = WORKFLOW.read_text()

        self.assertIn('--check "$preparation/gradle-warm-home.sha256" '
                      '"$preparation/gradle-warm-integrity.log"', text)
        self.assertIn("apple-preparation/gradle-warm-home.sha256", text)


if __name__ == "__main__":
    unittest.main()
