import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "scratch_detach", Path(__file__).with_name("detach-scratch.py"),
)
scratch_detach = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scratch_detach)
VOLUME = "/private/tmp/cairn-resource-fixture/scratch"
IMAGE = "/private/tmp/cairn-resource-fixture/build-scratch.dmg"
INVENTORY = plistlib.dumps({"images": [
    {"image-path": IMAGE, "system-entities": [
        {"dev-entry": "/dev/disk7"}, {"dev-entry": "/dev/disk7s2"},
    ]},
]})


class ScratchDetachTest(unittest.TestCase):
    def test_successful_ejection_is_not_failed_by_diagnostic_lookup_timeout(self):
        def operating_system(command, **options):
            if command[0] == "/usr/bin/hdiutil":
                return subprocess.CompletedProcess(command, 0)
            raise subprocess.TimeoutExpired(command, 5)

        diagnostics = io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stderr(diagnostics):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 0, diagnostics.getvalue())
        self.assertEqual(diagnostics.getvalue(), "")

    def test_failed_ejection_retains_state_and_holder_diagnostics_and_stays_failed(self):
        state = {
            "DeviceIdentifier": "disk7s2", "ParentWholeDisk": "disk7",
            "Mounted": True, "MountPoint": VOLUME, "Ejectable": True,
        }

        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
            if command[0] == "/usr/sbin/diskutil":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps(state))
            if command[0] == "/usr/sbin/ioreg":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
            return subprocess.CompletedProcess(command, 0, stdout="p123\ncfixture\nf3\nfcwd\n")

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn("FAIL: scratch detach failed", errors.getvalue())
        state_prefix = "DIAGNOSTIC: scratch detach state "
        reported_state = next(
            line[len(state_prefix):] for line in output.getvalue().splitlines()
            if line.startswith(state_prefix)
        )
        self.assertEqual(json.loads(reported_state), state)
        self.assertIn("p123\ncfixture\n", output.getvalue())
        self.assertNotRegex(output.getvalue(), r"(?m)^f")

    def test_unavailable_detach_command_has_a_controlled_failure(self):
        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(
            scratch_detach.subprocess, "run", side_effect=FileNotFoundError,
        ):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn("FAIL: scratch detach command unavailable", errors.getvalue())

    @unittest.skipUnless(sys.platform == "darwin", "native lsof format requires macOS")
    def test_failed_ejection_retains_native_holder_identities_without_descriptor_fields(self):
        with tempfile.NamedTemporaryFile(prefix="cairn-holder-") as owned:
            holders = subprocess.run(
                ["/usr/sbin/lsof", "-nP", "-a", "-p", str(os.getpid()), "-Fpc", "--", owned.name],
                capture_output=True, text=True, check=True, timeout=5,
            )
        self.assertRegex(holders.stdout, r"(?m)^f.+$")

        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
            if command[0] == "/usr/sbin/diskutil":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps({}))
            if command[0] == "/usr/sbin/ioreg":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
            return subprocess.CompletedProcess(command, 0, stdout=holders.stdout)

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertEqual(errors.getvalue(), "FAIL: scratch detach failed\n")
        self.assertIn("p" + str(os.getpid()) + "\n", output.getvalue())
        self.assertRegex(output.getvalue(), r"(?m)^c.+$")
        self.assertNotRegex(output.getvalue(), r"(?m)^f")

    def test_invalid_volume_is_rejected_without_native_mutation(self):
        for volume in ("", "/", "scratch", VOLUME + "/../scratch", VOLUME + "\n"):
            with self.subTest(volume=volume):
                errors = io.StringIO()
                with mock.patch.object(
                    scratch_detach.subprocess, "run",
                    side_effect=AssertionError("invalid input reached native mutation"),
                ):
                    with contextlib.redirect_stderr(errors):
                        result = scratch_detach.detach_scratch(volume, IMAGE)

                self.assertEqual(result, 1)
                self.assertIn("FAIL: invalid owned scratch volume", errors.getvalue())

    def test_invalid_disk_response_remains_observable_and_does_not_hide_holders(self):
        for response in (
            b"not a plist",
            b'<?xml version="1.0"?><plist><dict>',
            plistlib.dumps([]),
            plistlib.dumps({"MountPoint": b"invalid"}),
            plistlib.dumps({"Mounted": 1}),
        ):
            with self.subTest(response=response):
                def operating_system(command, **options):
                    if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                        return subprocess.CompletedProcess(command, 1)
                    if command[:2] == ["/usr/bin/hdiutil", "info"]:
                        return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
                    if command[0] == "/usr/sbin/diskutil":
                        return subprocess.CompletedProcess(command, 0, stdout=response)
                    if command[0] == "/usr/sbin/ioreg":
                        return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
                    return subprocess.CompletedProcess(command, 0, stdout="p123\ncfixture\n")

                output, errors = io.StringIO(), io.StringIO()
                with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
                    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                        result = scratch_detach.detach_scratch(VOLUME, IMAGE)

                self.assertEqual(result, 1)
                self.assertIn("DIAGNOSTIC: scratch detach state unavailable", errors.getvalue())
                self.assertIn("p123\ncfixture\n", output.getvalue())

    def test_failed_ejection_with_timed_out_diagnostics_preserves_deadlines_and_failure(self):
        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, -15)
            expected_deadline = 15 if command[0] == "/usr/sbin/lsof" else 5
            self.assertGreater(options["timeout"], 0)
            self.assertLessEqual(options["timeout"], expected_deadline)
            raise subprocess.TimeoutExpired(command, expected_deadline)

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn("scratch detach state unavailable: TimeoutExpired", errors.getvalue())
        self.assertIn("open-file holder collection failed: TimeoutExpired", errors.getvalue())

    def test_nonzero_diagnostic_commands_cannot_turn_failed_ejection_into_success(self):
        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            raise subprocess.CalledProcessError(1, command, stderr=b"untrusted diagnostic output")

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn("scratch detach state unavailable: CalledProcessError", errors.getvalue())
        self.assertIn("open-file holder collection failed: CalledProcessError", errors.getvalue())
        self.assertNotIn("untrusted diagnostic output", errors.getvalue())

    def unmounted_image_system(self, device_results, image_holders="p3985\ncdiskimages-helper\n",
                               inventory=INVENTORY):
        detaches, results = [], iter(device_results)

        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                detaches.append(command[-1])
                return subprocess.CompletedProcess(
                    command, 1 if command[-1] == VOLUME else next(results),
                )
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=inventory)
            if command[0] == "/usr/sbin/diskutil":
                raise subprocess.CalledProcessError(1, command)
            if command[0] == "/usr/sbin/ioreg":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
            if "+f" in command:
                return subprocess.CompletedProcess(command, 1, stdout="")
            return subprocess.CompletedProcess(command, 1, stdout=image_holders)

        return detaches, operating_system

    def detach_with(self, operating_system):
        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system), \
                mock.patch.object(scratch_detach.time, "sleep") as sleep:
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)
        return result, output.getvalue(), errors.getvalue(), sleep

    def test_unmounted_image_held_only_by_diskimages_helper_is_ejected_by_device_retry(self):
        detaches, operating_system = self.unmounted_image_system([1, 0])

        result, output, errors, sleep = self.detach_with(operating_system)

        self.assertEqual(result, 0, errors)
        self.assertEqual(detaches, [VOLUME, "/dev/disk7", "/dev/disk7"])
        self.assertEqual(sleep.call_count, 2)
        self.assertIn("PASS: unmounted scratch image ejected on device retry 2", output)
        self.assertNotIn("FAIL", errors)

    def test_device_retry_is_bounded_and_the_detach_stays_failed(self):
        detaches, operating_system = self.unmounted_image_system([1, 1, 1, 0])

        result, output, errors, sleep = self.detach_with(operating_system)

        self.assertEqual(result, 1)
        self.assertEqual(detaches, [VOLUME, "/dev/disk7", "/dev/disk7", "/dev/disk7"])
        self.assertEqual(sleep.call_count, 3)
        self.assertIn("FAIL: scratch detach failed", errors)

    def test_image_with_a_foreign_holder_is_not_retried(self):
        detaches, operating_system = self.unmounted_image_system(
            [0], image_holders="p3985\ncdiskimages-helper\np123\ncfixture\n",
        )

        result, output, errors, sleep = self.detach_with(operating_system)

        self.assertEqual(result, 1)
        self.assertEqual(detaches, [VOLUME])
        sleep.assert_not_called()

    def test_image_that_is_still_mounted_is_not_retried(self):
        mounted = plistlib.dumps({"images": [
            {"image-path": IMAGE, "system-entities": [
                {"dev-entry": "/dev/disk7"}, {"dev-entry": "/dev/disk7s2", "mount-point": VOLUME},
            ]},
        ]})
        detaches, operating_system = self.unmounted_image_system([0], inventory=mounted)

        result, output, errors, sleep = self.detach_with(operating_system)

        self.assertEqual(result, 1)
        self.assertEqual(detaches, [VOLUME])
        sleep.assert_not_called()

    def test_cli_rejects_invalid_arity_and_path_without_traceback(self):
        for arguments in ([], ["/", IMAGE], [VOLUME, "extra"], [VOLUME, IMAGE, "extra"]):
            with self.subTest(arguments=arguments):
                result = subprocess.run(
                    [sys.executable, "-I", str(Path(__file__).with_name("detach-scratch.py")),
                     *arguments],
                    capture_output=True, text=True, timeout=5,
                )

                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertNotIn("Traceback", result.stderr)
                self.assertTrue(result.stderr.startswith(("Usage:", "FAIL:")))


if __name__ == "__main__":
    unittest.main()
