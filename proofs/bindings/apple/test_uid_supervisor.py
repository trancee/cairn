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
                "file": [67108864, 67108864], "core": [0, 0],
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
