import contextlib
import importlib.util
import io
from pathlib import Path
import re
import subprocess
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name("report-sandbox-denials.py")
RUNNER = Path(__file__).with_name("run-resource-probes.sh")
spec = importlib.util.spec_from_file_location("report_sandbox_denials", SCRIPT)
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)


class ReportSandboxDenialsTest(unittest.TestCase):
    def test_query_starts_at_the_probe_and_selects_java_denials_under_opt(self):
        command = report.query("2026-10-19 11:45:03")

        self.assertEqual(command[:7], [
            "/usr/bin/log", "show", "--start", "2026-10-19 11:45:03",
            "--style", "compact", "--predicate",
        ])
        self.assertEqual(command[7], (
            'process == "kernel" AND eventMessage CONTAINS "Sandbox" '
            'AND eventMessage CONTAINS "java(" AND eventMessage CONTAINS "/opt"'
        ))

    def test_each_denial_and_the_total_are_reported_even_when_absent(self):
        log = (
            "Timestamp               Ty Process[PID:TID]\n"
            "2026-10-19 11:45:06.436 E  kernel[0:69f4] [com.apple.sandbox.reporting:violation] "
            "Sandbox: java(7900) deny(1) file-write-data /opt/cairn-apple-tools/x.bin\n"
        )

        self.assertEqual(report.summarize(log), [
            "DIAGNOSTIC: sandbox-denial 2026-10-19 11:45:06.436 "
            "java(7900) deny(1) file-write-data /opt/cairn-apple-tools/x.bin",
            "DIAGNOSTIC: java sandbox denials under /opt: 1",
        ])
        self.assertEqual(report.summarize("Timestamp               Ty Process[PID:TID]\n"),
                         ["DIAGNOSTIC: java sandbox denials under /opt: 0"])

    def test_unavailable_log_query_is_reported_without_failing_the_probe(self):
        for failure in (
            subprocess.TimeoutExpired(["/usr/bin/log"], 15),
            subprocess.CalledProcessError(1, ["/usr/bin/log"]),
            OSError("unavailable"),
        ):
            with self.subTest(failure=type(failure).__name__):
                errors = io.StringIO()
                with mock.patch.object(report.subprocess, "run", side_effect=failure), \
                        mock.patch.object(report.sys, "argv", ["report", "2026-10-19 15:05:24"]), \
                        contextlib.redirect_stderr(errors):
                    report.main()

                self.assertEqual(
                    errors.getvalue(),
                    f"DIAGNOSTIC: sandbox-denial query unavailable: {type(failure).__name__}\n",
                )

    def test_fixture_targets_reports_denials_whether_or_not_the_probe_passes(self):
        arm = re.search(r"^    fixture-targets\)\n(.*?)^      ;;$", RUNNER.read_text(),
                        re.MULTILINE | re.DOTALL).group(1)

        start = arm.index("probe_start=$(/bin/date '+%Y-%m-%d %H:%M:%S')")
        supervised = arm.index('uid-supervisor.py" --seconds 60 --diagnose-after 50')
        captured = arm.index("|| probe_result=$?")
        reported = arm.index('report-sandbox-denials.py" "$probe_start"')
        propagated = arm.index('if [ "$probe_result" -ne 0 ]; then exit "$probe_result"; fi')
        self.assertLess(start, supervised)
        self.assertLess(supervised, captured)
        self.assertLess(captured, reported)
        self.assertLess(reported, propagated)
        self.assertLess(propagated, arm.index("check-build-scratch.py"))


if __name__ == "__main__":
    unittest.main()
