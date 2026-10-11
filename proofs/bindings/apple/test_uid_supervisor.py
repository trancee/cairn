import os
import json
import signal
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


@unittest.skipUnless(
    os.geteuid() == 0 and os.environ.get("GITHUB_ACTIONS") == "true",
    "Dedicated-UID supervision requires the disposable hosted root fixture",
)
class DedicatedSupervisorTest(unittest.TestCase):
    def test_diagnostic_time_must_be_positive_and_before_deadline(self):
        with tempfile.TemporaryDirectory() as directory:
            for value in ("0", "-1", "1", "nan", "inf"):
                with self.subTest(value=value):
                    result = subprocess.run(
                        [sys.executable, str(Path(__file__).with_name("uid-supervisor.py")),
                         "--seconds", "1", "--diagnose-after", value,
                         str(Path(directory) / "proof.log"), "/bin/echo", "unexpected"],
                        capture_output=True, timeout=10, text=True,
                    )

                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertIn("Process diagnostic time must be positive and before the deadline",
                                  result.stderr)
                    self.assertNotIn("unexpected", result.stdout)

    def test_slow_child_reports_only_owned_process_identity_before_deadline(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("uid-supervisor.py")),
                 "--seconds", "2", "--diagnose-after", "0.5", str(output),
                 sys.executable, "-I", "-c", "import time; time.sleep(60)"],
                capture_output=True, timeout=25, text=True,
            )

            self.assertEqual(result.returncode, 124, result.stderr)
            snapshots = [
                json.loads(line.removeprefix("DIAGNOSTIC: owned-process "))
                for line in result.stdout.splitlines()
                if line.startswith("DIAGNOSTIC: owned-process ")
            ]
            self.assertTrue(snapshots, result.stdout)
            self.assertEqual({row["uid"] for row in snapshots}, {59000})
            self.assertTrue(all(set(row) == {
                "uid", "pid", "ppid", "state", "cpu_time", "command",
            } for row in snapshots), snapshots)
            self.assertIn("PASS: dedicated UID has no remaining processes", result.stdout)

    def test_child_file_ceiling_allows_boundary_and_rejects_next_byte(self):
        program = (
            "import errno,os,signal,tempfile; "
            "signal.signal(signal.SIGXFSZ,signal.SIG_IGN); "
            "\nwith tempfile.TemporaryFile(dir=os.environ['HOME'],buffering=0) as output:\n"
            " for _ in range(128): output.write(b'x'*(1024**2))\n"
            " output.flush()\n"
            " assert os.fstat(output.fileno()).st_size==134217728\n"
            " try:\n"
            "  output.write(b'x'); output.flush()\n"
            " except OSError as error:\n"
            "  assert error.errno==errno.EFBIG,error\n"
            " else:\n"
            "  raise AssertionError('file ceiling allowed excess')\n"
            " print('PASS: 128 MiB file boundary; next byte rejected')\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("uid-supervisor.py")),
                 str(output), sys.executable, "-I", "-c", program],
                capture_output=True, timeout=25,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(output.read_text().strip(),
                             "PASS: 128 MiB file boundary; next byte rejected")

    def test_child_receives_approved_limits_and_only_dedicated_identity(self):
        program = (
            "import ctypes,json,os,resource; "
            "libc=ctypes.CDLL(None,use_errno=True); "
            "count=libc.getgroups(0,None); "
            "assert count >= 0,ctypes.get_errno(); "
            "groups=(ctypes.c_uint32*count)(); "
            "assert libc.getgroups(count,groups)==count,ctypes.get_errno(); "
            "print(json.dumps({"
            "'uid':os.getuid(),'gid':os.getgid(),'groups':list(groups),"
            "'cpu':resource.getrlimit(resource.RLIMIT_CPU),"
            "'processes':resource.getrlimit(resource.RLIMIT_NPROC),"
            "'file':resource.getrlimit(resource.RLIMIT_FSIZE),"
            "'core':resource.getrlimit(resource.RLIMIT_CORE),"
            "'environment':sorted(k for k in os.environ "
            "if k != '__CF_USER_TEXT_ENCODING')}))"
        )
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"

            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("uid-supervisor.py")),
                 str(output), sys.executable, "-I", "-c", program],
                capture_output=True, timeout=25,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(output.read_text()), {
                "uid": 59000, "gid": 20, "groups": [20],
                "cpu": [900, 900], "processes": [128, 128],
                "file": [134217728, 134217728], "core": [0, 0],
                "environment": ["HOME", "LANG", "PATH", "TMPDIR"],
            })

    def test_deadline_removes_detached_descendant_and_preserves_output(self):
        program = (
            "import os,time; "
            "pid=os.fork(); "
            "\nif pid == 0:\n"
            " os.setsid()\n"
            " fd=os.open('/dev/null',os.O_RDWR)\n"
            " os.dup2(fd,1); os.dup2(fd,2)\n"
            " time.sleep(60)\n"
            "else:\n"
            " print('detached='+str(pid),flush=True)\n"
            " time.sleep(60)\n"
        )
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "proof.log"
            process_id = None
            try:
                result = subprocess.run(
                    [sys.executable, str(Path(__file__).with_name("uid-supervisor.py")),
                     "--seconds", "1", str(output), sys.executable, "-I", "-c", program],
                    capture_output=True, timeout=25,
                )

                print(result.stdout.decode(), end="", flush=True)
                print(result.stderr.decode(), end="", flush=True)
                self.assertEqual(result.returncode, 124, result.stderr)
                retained = output.read_text().strip()
                self.assertTrue(retained.startswith("detached="), retained)
                process_id = int(retained.split("=")[1])
                with self.assertRaises(ProcessLookupError, msg="Detached descendant survived deadline"):
                    os.kill(process_id, 0)
            finally:
                if process_id is not None:
                    try:
                        os.kill(process_id, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == "__main__":
    unittest.main()
