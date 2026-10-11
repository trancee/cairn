import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


@unittest.skipUnless(sys.platform == "darwin", "Native Apple sandbox policy")
class ReadPolicyTest(unittest.TestCase):
    def test_compiler_socket_profile_allows_trusted_listener_startup(self):
        python = subprocess.check_output(["xcrun", "--find", "python3"], text=True).strip()
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([
                "/usr/bin/env", "-i", "PATH=/usr/bin:/bin", "/usr/bin/sandbox-exec",
                "-D", f"INPUTS={directory}", "-D", f"SCRATCH={directory}",
                "-D", "PRIVATE_IPC=true", "-f", str(Path(__file__).with_name("build.sb")),
                python, "-I", "-c",
                "import socket; s=socket.socket(); s.bind(('127.0.0.1',0)); "
                "s.listen(1); print('listener')",
            ], capture_output=True, timeout=5)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, b"listener\n")

    def test_named_system_roots_allow_executable_startup(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([
                "/usr/bin/env", "-i", "PATH=/usr/bin:/bin", "/usr/bin/sandbox-exec",
                "-D", f"INPUTS={directory}/inputs", "-D", f"SCRATCH={directory}/scratch",
                "-D", "PRIVATE_IPC=false",
                "-f", str(Path(__file__).with_name("build.sb")),
                "/bin/echo", "startup",
            ], capture_output=True, timeout=5)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, b"startup\n")

    def test_data_outside_named_roots_is_denied(self):
        with tempfile.TemporaryDirectory() as directory:
            sentinel = Path(directory) / "unlisted"
            sentinel.write_text("benign data")

            result = subprocess.run([
                "/usr/bin/env", "-i", "PATH=/usr/bin:/bin", "/usr/bin/sandbox-exec",
                "-D", f"INPUTS={directory}/inputs", "-D", f"SCRATCH={directory}/scratch",
                "-D", "PRIVATE_IPC=false",
                "-f", str(Path(__file__).with_name("build.sb")), "/bin/cat", str(sentinel),
            ], capture_output=True, timeout=5)

            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b"")
            self.assertIn(b"Operation not permitted", result.stderr)
