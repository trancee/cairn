import importlib.util
import io
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "uid_supervisor_preflight", Path(__file__).with_name("uid-supervisor.py")
)
supervisor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(supervisor)


class UIDPreflightTest(unittest.TestCase):
    def test_existing_uid_processes_are_reported_without_launch_or_cleanup(self):
        account = SimpleNamespace(pw_uid=59000, pw_gid=20, pw_shell="/usr/bin/false")
        errors = io.StringIO()
        with (
            mock.patch.object(supervisor.sys, "argv", ["supervisor", "output", "/bin/echo"]),
            mock.patch.object(supervisor.os, "geteuid", return_value=0),
            mock.patch.dict(supervisor.os.environ, {"GITHUB_ACTIONS": "true"}),
            mock.patch.object(supervisor.pwd, "getpwnam", return_value=account),
            mock.patch.object(supervisor, "account_processes", return_value={123}),
            mock.patch.object(supervisor, "report_account_processes") as report,
            mock.patch.object(supervisor.subprocess, "Popen") as launch,
            mock.patch.object(supervisor, "cleanup_account") as cleanup,
            mock.patch.object(supervisor.sys, "stderr", errors),
        ):

            with self.assertRaises(SystemExit) as result:
                supervisor.main()

        self.assertEqual(result.exception.code, 2)
        report.assert_called_once_with(59000)
        launch.assert_not_called()
        cleanup.assert_not_called()
        self.assertIn("refusing to launch or clean them", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
