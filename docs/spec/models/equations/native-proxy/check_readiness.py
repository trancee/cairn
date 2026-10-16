"""Linux readiness failures exercised through the real native CLI and loader."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from test_maude_boundary import NATIVE_MODULE, native_stream


class CompiledReadinessTests(unittest.TestCase):
    proxy: Path

    @unittest.skipUnless(sys.platform == "linux", "requires the native Linux loader")
    def test_readiness_setup_wait_event_removal_and_close_fail_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            library = Path(temporary) / "readiness-faults.so"
            fixture = Path(__file__).with_name("fixtures") / "readiness-faults.rs"
            for command in (
                ["rustfmt", "--edition=2024", "--check", str(fixture)],
                ["clippy-driver", "--edition=2024", "--crate-type=cdylib",
                 "-Dclippy::all", "-Dwarnings", str(fixture), "-o", str(library)],
            ):
                built = subprocess.run(
                    command, capture_output=True, text=True, timeout=30,
                )
                self.assertEqual(built.returncode, 0, built.stdout + built.stderr)
            for fault in ("create", "add", "wait", "event", "delete", "close"):
                with self.subTest(fault=fault), patch.dict(
                    os.environ, LD_PRELOAD=str(library), CAIRN_EPOLL_FAULT=fault,
                ):
                    result = native_stream(
                        NATIVE_MODULE + "reduce tamXCroleA .\n" * 3,
                        "result Msg: tamXCroleA\nMaude> ",
                        proxy=self.proxy, close_errors=True,
                    )

                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    reason = (
                        "native process: invalid readiness event" if fault == "event"
                        else "native process: I/O or version failure"
                    )
                    self.assertIn(reason, result.stderr)
                    self.assertNotIn("panicked", result.stderr)
