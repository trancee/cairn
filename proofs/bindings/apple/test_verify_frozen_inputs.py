from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("verify-frozen-inputs.py")


class VerifyFrozenInputsTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.root = self.work / "root"
        self.root.mkdir()

    def manifest(self, name, count):
        for index in range(count):
            path = self.root / name / f"file-{index:02d}"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(f"{name}-{index}\n".encode() * (index + 1))
        listing = subprocess.run(
            ["shasum", "-a", "256", *sorted(
                str(path.relative_to(self.root)) for path in (self.root / name).iterdir()
            )],
            cwd=self.root, check=True, capture_output=True,
        ).stdout
        manifest = self.work / f"{name}.sha256"
        manifest.write_bytes(listing)
        return manifest

    def serial_log(self, manifest):
        return subprocess.run(
            ["shasum", "-a", "256", "--check", str(manifest)],
            cwd=self.root, capture_output=True,
        ).stdout

    def verify(self, *pairs, jobs=3):
        arguments = [sys.executable, "-I", str(SCRIPT), "--root", str(self.root),
                     "--jobs", str(jobs)]
        for manifest, log in pairs:
            arguments += ["--check", str(manifest), str(log)]
        return subprocess.run(arguments, capture_output=True, text=True)

    def test_logs_match_serial_check_byte_for_byte(self):
        tools = self.manifest("tools", 11)
        gradle = self.manifest("gradle", 2)
        tools_log, gradle_log = self.work / "tools.log", self.work / "gradle.log"

        result = self.verify((tools, tools_log), (gradle, gradle_log))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(tools_log.read_bytes(), self.serial_log(tools))
        self.assertEqual(gradle_log.read_bytes(), self.serial_log(gradle))

    def test_mismatch_fails_after_writing_every_log(self):
        tools = self.manifest("tools", 7)
        cargo = self.manifest("cargo", 7)
        (self.root / "cargo" / "file-05").write_bytes(b"tampered\n")
        tools_log, cargo_log = self.work / "tools.log", self.work / "cargo.log"

        result = self.verify((tools, tools_log), (cargo, cargo_log))

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(tools_log.read_bytes(), self.serial_log(tools))
        self.assertEqual(cargo_log.read_bytes(), self.serial_log(cargo))
        self.assertIn(b"cargo/file-05: FAILED\n", cargo_log.read_bytes())

    def test_missing_file_fails(self):
        native = self.manifest("native", 5)
        (self.root / "native" / "file-00").unlink()
        log = self.work / "native.log"

        result = self.verify((native, log))

        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"native/file-00: FAILED open or read\n", log.read_bytes())

    def test_empty_manifest_fails_like_serial_check(self):
        empty = self.work / "empty.sha256"
        empty.write_bytes(b"")
        log = self.work / "empty.log"

        result = self.verify((empty, log))

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(log.read_bytes(), self.serial_log(empty))

    def test_single_job_matches_parallel_result(self):
        tools = self.manifest("tools", 9)
        log = self.work / "tools.log"

        result = self.verify((tools, log), jobs=1)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.read_bytes(), self.serial_log(tools))

    def test_non_positive_job_count_is_rejected(self):
        tools = self.manifest("tools", 2)
        log = self.work / "tools.log"

        result = self.verify((tools, log), jobs=0)

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(log.exists())


if __name__ == "__main__":
    unittest.main()
