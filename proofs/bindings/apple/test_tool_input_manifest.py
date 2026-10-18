import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name("tool-input-manifest.py")
spec = importlib.util.spec_from_file_location("tool_input_manifest", SCRIPT)
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)


def reference_manifest(root, scope="."):
    return subprocess.run([
        "/bin/bash", "-o", "pipefail", "-c",
        '/usr/bin/find "$1" -type f -print0 | LC_ALL=C /usr/bin/sort -z'
        ' | /usr/bin/xargs -0 shasum -a 256',
        "reference-manifest", scope,
    ], cwd=root, check=True, capture_output=True).stdout


class ToolInputManifestTest(unittest.TestCase):
    def test_manifest_matches_existing_pipeline_byte_for_byte(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in [
                "plain", "with space", "back\\slash", "new\nline", "caf\u00e9",
                "carriage\rreturn",
            ]:
                (root / name).write_bytes(name.encode())
            (root / "empty").touch()
            (root / "nested").mkdir()
            (root / "nested" / "executable").write_bytes(b"\x00\xff")
            (root / "nested" / "executable").chmod(0o755)
            (root / "file-link").symlink_to("plain")
            (root / "directory-link").symlink_to("nested", target_is_directory=True)
            expected = reference_manifest(root)

            actual = manifest.create_manifest(root)

            self.assertEqual(actual, expected)

    def test_each_scoped_manifest_retains_its_existing_path_prefix(self):
        for scope in ["gradle-dependencies", "cargo-inputs", "native-dependencies"]:
            with self.subTest(scope=scope), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / scope).mkdir()
                (root / scope / "input").write_bytes(b"frozen bytes")
                (root / "unrelated").write_bytes(b"excluded")
                expected = reference_manifest(root, scope)

                actual = manifest.create_manifest(root, scope)

                self.assertEqual(actual, expected)
                self.assertNotIn(b"unrelated", actual)

    def test_cli_manifest_is_accepted_by_independent_shasum(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "inputs"
            root.mkdir()
            (root / "new\nline").write_bytes(b"input")
            sums = Path(directory) / "sums"

            result = subprocess.run([
                sys.executable, "-I", str(SCRIPT), str(root),
            ], capture_output=True, timeout=5)

            self.assertEqual(result.returncode, 0, result.stderr)
            sums.write_bytes(result.stdout)
            checked = subprocess.run([
                "shasum", "-a", "256", "--check", str(sums),
            ], cwd=root, capture_output=True, timeout=5)
            self.assertEqual(checked.returncode, 0, checked.stderr)

    def test_cli_invalid_root_fails_without_emitting_a_manifest_or_path(self):
        with tempfile.TemporaryDirectory() as directory:
            missing = Path(directory) / "private-path"

            result = subprocess.run([
                sys.executable, "-I", str(SCRIPT), str(missing),
            ], capture_output=True, timeout=5)

            self.assertEqual(result.returncode, 1)
            self.assertEqual(result.stdout, b"")
            self.assertEqual(result.stderr, b"FAIL: tool-input manifest: invalid-root\n")

    def test_invalid_scopes_fail_before_reading_outside_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "inputs"
            root.mkdir()
            (Path(directory) / "outside").mkdir()
            (root / "escape").symlink_to("../outside", target_is_directory=True)
            for scope in [
                "..", "../outside", "/outside", "escape", "missing", "-name",
                "", "./outside", "outside/",
            ]:
                with self.subTest(scope=scope):
                    with self.assertRaisesRegex(manifest.ManifestError, "invalid-scope"):
                        manifest.create_manifest(root, scope)

    def test_empty_input_does_not_emit_a_stdin_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(manifest.ManifestError, "no-regular-inputs"):
                manifest.create_manifest(Path(directory))

    def test_scope_cannot_traverse_a_symlinked_parent_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "inputs"
            root.mkdir()
            outside = Path(directory) / "outside"
            (outside / "nested").mkdir(parents=True)
            (outside / "nested" / "input").write_bytes(b"must not be read")
            (root / "escape").symlink_to("../outside", target_is_directory=True)

            with self.assertRaisesRegex(manifest.ManifestError, "invalid-scope"):
                manifest.create_manifest(root, "escape/nested")

    def test_chunk_boundary_matches_existing_pipeline(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "binary").write_bytes(b"\x00\xff" * (512 * 1024 + 1))
            expected = reference_manifest(root)

            actual = manifest.create_manifest(root)

            self.assertEqual(actual, expected)

    def test_non_regular_inputs_are_not_opened_or_followed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "regular").write_bytes(b"input")
            os.mkfifo(root / "fifo")
            expected = reference_manifest(root)

            result = subprocess.run([
                sys.executable, "-I", str(SCRIPT), str(root),
            ], capture_output=True, timeout=5)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, expected)

    def test_parallel_hashing_is_byte_identical_to_serial_hashing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index in range(37):
                (root / f"input-{index:02}").write_bytes(bytes([index]) * (index * 4099))
            (root / "nested").mkdir()
            (root / "nested" / "new\nline").write_bytes(b"\x00\xff" * 70000)
            expected = reference_manifest(root)

            actual = [manifest.create_manifest(root, jobs=jobs) for jobs in (1, 2, 3, 8)]

            self.assertEqual(actual, [expected] * 4)

    def test_cli_jobs_option_emits_the_serial_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "inputs"
            (root / "scope").mkdir(parents=True)
            for index in range(9):
                (root / "scope" / f"input-{index}").write_bytes(bytes([index]) * 1000)
            expected = reference_manifest(root, "scope")

            result = subprocess.run([
                sys.executable, "-I", str(SCRIPT), "--jobs", "3", str(root), "scope",
            ], capture_output=True, timeout=5)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, expected)

    def test_invalid_job_counts_are_rejected_before_reading(self):
        with tempfile.TemporaryDirectory() as directory:
            for jobs in [0, -1]:
                with self.subTest(jobs=jobs):
                    with self.assertRaisesRegex(manifest.ManifestError, "invalid-jobs"):
                        manifest.create_manifest(Path(directory), jobs=jobs)

    def test_parallel_read_failure_emits_only_a_redacted_error(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index in range(4):
                (root / f"input-{index}").write_bytes(b"input")
            errors = io.StringIO()
            with (
                mock.patch.object(Path, "open", side_effect=PermissionError("private-path")),
                mock.patch.object(sys, "argv", [str(SCRIPT), "--jobs", "3", str(root)]),
                mock.patch.object(sys, "stdout") as output,
                mock.patch.object(sys, "stderr", errors),
            ):

                result = manifest.main()

            self.assertEqual(result, 1)
            output.buffer.write.assert_not_called()
            self.assertEqual(errors.getvalue(), "FAIL: tool-input manifest: PermissionError\n")

    def test_root_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "inputs"
            root.mkdir()
            link = Path(directory) / "link"
            link.symlink_to(root, target_is_directory=True)

            with self.assertRaisesRegex(manifest.ManifestError, "invalid-root"):
                manifest.create_manifest(link)

    def test_directory_read_error_is_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "input").write_bytes(b"input")
            with mock.patch("os.scandir", side_effect=PermissionError("private-path")):

                with self.assertRaises(PermissionError):
                    manifest.create_manifest(root)

    def test_failed_file_read_emits_only_a_redacted_error(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "input").write_bytes(b"input")
            errors = io.StringIO()
            with (
                mock.patch.object(Path, "open", side_effect=PermissionError("private-path")),
                mock.patch.object(sys, "argv", [str(SCRIPT), str(root)]),
                mock.patch.object(sys, "stdout") as output,
                mock.patch.object(sys, "stderr", errors),
            ):

                result = manifest.main()

            self.assertEqual(result, 1)
            output.buffer.write.assert_not_called()
            self.assertEqual(errors.getvalue(), "FAIL: tool-input manifest: PermissionError\n")


if __name__ == "__main__":
    unittest.main()
