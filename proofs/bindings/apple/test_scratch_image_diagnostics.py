import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import subprocess
import unittest
from unittest import mock


spec = importlib.util.spec_from_file_location(
    "scratch_detach", Path(__file__).with_name("detach-scratch.py"),
)
scratch_detach = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scratch_detach)
VOLUME = "/private/tmp/cairn-resource-fixture/scratch"
IMAGE = "/private/tmp/cairn-resource-fixture/build-scratch.dmg"
OWNED = {"image-path": IMAGE, "system-entities": [
    {"dev-entry": "/dev/disk7"}, {"dev-entry": "/dev/disk7s2"},
]}
INVENTORY = plistlib.dumps({"images": [OWNED]})


class ScratchImageDiagnosticsTest(unittest.TestCase):
    def test_unavailable_mount_info_still_reports_owned_image_devices_and_holders(self):
        inventory = {"images": [
            {"image-path": "/private/tmp/unrelated.dmg",
             "system-entities": [{"dev-entry": "/dev/disk0"}]}, OWNED,
        ]}

        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps(inventory))
            if command[0] == "/usr/sbin/diskutil" or "+f" in command:
                raise subprocess.CalledProcessError(1, command)
            if command[0] == "/usr/sbin/ioreg":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
            return subprocess.CompletedProcess(command, 0, stdout="p123\ncdiskimages-helper\n")

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn('owned scratch image devices ["/dev/disk7", "/dev/disk7s2"]', output.getvalue())
        self.assertIn("p123\ncdiskimages-helper\n", output.getvalue())
        self.assertNotIn("/dev/disk0", output.getvalue())
        self.assertNotIn("unrelated.dmg", output.getvalue())

    def test_invalid_owned_image_is_rejected_before_native_mutation(self):
        for image in ("/", IMAGE + "\n", IMAGE + "/../build-scratch.dmg",
                      "/private/tmp/cairn-resource-other/build-scratch.dmg"):
            with self.subTest(image=image):
                errors = io.StringIO()
                with mock.patch.object(
                    scratch_detach.subprocess, "run",
                    side_effect=AssertionError("invalid image reached native mutation"),
                ):
                    with contextlib.redirect_stderr(errors):
                        result = scratch_detach.detach_scratch(VOLUME, image)

                self.assertEqual(result, 1)
                self.assertIn("FAIL: invalid owned scratch image", errors.getvalue())

    def test_invalid_or_ambiguous_inventory_never_selects_other_device_targets(self):
        def inventory(entities):
            return {"images": [{"image-path": IMAGE, "system-entities": entities}]}

        cases = (
            (b"invalid", "InvalidFileException"),
            (b'<?xml version="1.0"?><plist>', "ExpatError"),
            ([], "invalid-image-inventory"),
            ({}, "invalid-image-inventory"),
            ({"images": []}, "owned-image-not-attached"),
            ({"images": [OWNED, OWNED]}, "ambiguous-owned-image"),
            (inventory([]), "invalid-owned-image-entities"),
            (inventory("invalid"), "invalid-owned-image-entities"),
            (inventory([7]), "invalid-owned-image-device"),
            (inventory([{"dev-entry": 7}]), "invalid-owned-image-device"),
            (inventory([{"dev-entry": "/dev/disk7/../disk0"}]), "invalid-owned-image-device"),
            (inventory([{"dev-entry": "/dev/disk7"}] * 2), "invalid-owned-image-device"),
            (inventory([{"dev-entry": "/dev/disk7"}, {"dev-entry": "/dev/disk0"}]),
             "ambiguous-owned-image-devices"),
            (inventory([{"dev-entry": "/dev/disk7", "mount-point": "/private/tmp/foreign"}]),
             "unexpected-owned-image-mount"),
        )
        for payload, reason in cases:
            with self.subTest(reason=reason):
                def operating_system(command, **options):
                    if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                        return subprocess.CompletedProcess(command, 1)
                    if command[:2] == ["/usr/bin/hdiutil", "info"]:
                        data = payload if isinstance(payload, bytes) else plistlib.dumps(payload)
                        return subprocess.CompletedProcess(command, 0, stdout=data)
                    if command[0] == "/usr/sbin/lsof":
                        self.assertNotIn("/dev/disk0", command)
                        self.assertNotIn("/dev/disk7", command)
                        return subprocess.CompletedProcess(command, 0, stdout="p123\ncfixture\n")
                    raise subprocess.CalledProcessError(1, command)

                output, errors = io.StringIO(), io.StringIO()
                with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
                    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                        result = scratch_detach.detach_scratch(VOLUME, IMAGE)

                self.assertEqual(result, 1)
                self.assertIn("owned scratch image unavailable: " + reason, errors.getvalue())
                self.assertIn("p123\ncfixture\n", output.getvalue())
                self.assertNotIn("/private/tmp/foreign", output.getvalue())

    def test_reported_mount_is_taken_only_from_the_owned_image(self):
        inventory = plistlib.dumps({"images": [
            {"image-path": "/private/tmp/unrelated.dmg", "system-entities": [
                {"dev-entry": "/dev/disk0", "mount-point": "/private/tmp/foreign"},
            ]},
            {"image-path": IMAGE, "system-entities": [
                {"dev-entry": "/dev/disk7"}, {"dev-entry": "/dev/disk7s2", "mount-point": VOLUME},
            ]},
        ]})

        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=inventory)
            if command[0] == "/usr/sbin/lsof":
                return subprocess.CompletedProcess(command, 0, stdout="")
            raise subprocess.CalledProcessError(1, command)

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn('reported mount points ["' + VOLUME + '"]', output.getvalue())
        self.assertNotIn("/private/tmp/foreign", output.getvalue())

    def test_metadata_and_holder_commands_share_their_original_phase_budgets(self):
        clock = [0.0]
        holder_calls = []

        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[0] == "/usr/sbin/diskutil":
                self.assertEqual(options["timeout"], 5)
                clock[0] += 3
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps({}))
            if command[0] == "/usr/bin/hdiutil":
                self.assertEqual(options["timeout"], 2)
                clock[0] += 2
                return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
            if command[0] == "/usr/sbin/ioreg":
                return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
            holder_calls.append(command)
            self.assertEqual(options["timeout"], 15 if len(holder_calls) == 1 else 3)
            clock[0] += 12 if len(holder_calls) == 1 else 3
            return subprocess.CompletedProcess(command, 0, stdout="p123\ncfixture\n")

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.time, "monotonic", side_effect=lambda: clock[0]):
            with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
                with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                    result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertEqual(clock[0], 20)
        self.assertEqual(errors.getvalue(), "FAIL: scratch detach failed\n")

    def test_exhausted_phase_budget_prevents_follow_on_native_commands(self):
        for phase in ("metadata", "holders"):
            with self.subTest(phase=phase):
                clock = [0.0]

                def operating_system(command, **options):
                    if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                        return subprocess.CompletedProcess(command, 1)
                    if command[0] == "/usr/sbin/diskutil":
                        if phase == "metadata":
                            clock[0] += 5
                            raise subprocess.TimeoutExpired(command, 5)
                        return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps({}))
                    if command[0] == "/usr/bin/hdiutil":
                        self.assertNotEqual(phase, "metadata", "metadata exceeded its shared budget")
                        return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
                    if command[0] == "/usr/sbin/ioreg":
                        return subprocess.CompletedProcess(command, 0, stdout=plistlib.dumps([]))
                    if phase == "holders":
                        self.assertIn("+f", command, "holders exceeded their shared budget")
                        clock[0] += 15
                        raise subprocess.TimeoutExpired(command, 15)
                    return subprocess.CompletedProcess(command, 0, stdout="")

                output, errors = io.StringIO(), io.StringIO()
                with mock.patch.object(scratch_detach.time, "monotonic", side_effect=lambda: clock[0]):
                    with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
                        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                            result = scratch_detach.detach_scratch(VOLUME, IMAGE)

                self.assertEqual(result, 1)
                self.assertIn("diagnostic-deadline-exhausted", errors.getvalue())

    def test_partial_holder_results_remain_visible_but_never_clear_failed_ejection(self):
        def operating_system(command, **options):
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
            if command[0] == "/usr/sbin/lsof":
                return subprocess.CompletedProcess(command, 1, stdout="p123\ncfixture\nf3\nfcwd\n")
            raise subprocess.CalledProcessError(1, command)

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertIn("p123\ncfixture\n", output.getvalue())
        self.assertIn("holder-query-nonzero", errors.getvalue())
        self.assertNotRegex(output.getvalue(), r"(?m)^f")

    def test_failed_ejection_reports_only_owned_media_kernel_clients(self):
        registry = plistlib.dumps([
            {"IOObjectClass": "IOMedia", "BSD Name": "disk0", "Open": True,
             "IOServiceBusyState": 0, "IOObjectRetainCount": 9, "IORegistryEntryChildren": [
                 {"IOObjectClass": "IOMediaBSDClient", "IOServiceBusyState": 0},
             ]},
            {"IOObjectClass": "IOMedia", "BSD Name": "disk7", "Open": True,
             "IOServiceBusyState": 1, "IOObjectRetainCount": 12, "IORegistryEntryChildren": [
                 {"IOObjectClass": "IOMediaBSDClient", "IOServiceBusyState": 0},
                 {"IOObjectClass": "IOGUIDPartitionScheme", "IOServiceBusyState": 1,
                  "IORegistryEntryChildren": [
                      {"IOObjectClass": "IOMedia", "BSD Name": "disk7s1", "Open": False,
                       "IOServiceBusyState": 0, "IOObjectRetainCount": 7},
                  ]},
             ]},
        ])
        commands = []

        def operating_system(command, **options):
            commands.append(command)
            if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                return subprocess.CompletedProcess(command, 1)
            if command[:2] == ["/usr/bin/hdiutil", "info"]:
                return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
            if command[0] == "/usr/sbin/ioreg":
                self.assertEqual(options["timeout"], 5)
                return subprocess.CompletedProcess(command, 0, stdout=registry)
            if command[0] == "/usr/sbin/lsof":
                return subprocess.CompletedProcess(command, 0, stdout="p123\ncdiskimages-helper\n")
            raise subprocess.CalledProcessError(1, command)

        output, errors = io.StringIO(), io.StringIO()
        with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                result = scratch_detach.detach_scratch(VOLUME, IMAGE)

        self.assertEqual(result, 1)
        self.assertEqual(commands[-1], ["/usr/sbin/ioreg", "-a", "-r", "-c", "IOMedia", "-w0"])
        self.assertIn(
            'DIAGNOSTIC: owned scratch media state [{"bsd-name": "disk7", "class": "IOMedia", '
            '"open": true, '
            '"busy": 1, "retain": 12, "clients": [["IOMediaBSDClient", 0], '
            '["IOGUIDPartitionScheme", 1]]}]\n',
            output.getvalue(),
        )
        self.assertIn('DIAGNOSTIC: owned scratch media absent ["disk7s2"]\n', output.getvalue())
        self.assertNotIn("disk0", output.getvalue())
        self.assertNotIn("disk7s1", output.getvalue())

    def test_owned_media_subclasses_are_reported_with_their_registry_class(self):
        registry = [{"IOObjectClass": "AppleAPFSMedia", "BSD Name": "disk9", "Open": True,
                     "IOServiceBusyState": 0, "IOObjectRetainCount": 13,
                     "IORegistryEntryChildren": [
                         {"IOObjectClass": "AppleAPFSContainer", "IOServiceBusyState": 0,
                          "IORegistryEntryChildren": [
                             {"IOObjectClass": "AppleAPFSVolume", "BSD Name": "disk9s1",
                              "Open": False, "IOServiceBusyState": 2, "IOObjectRetainCount": 8},
                         ]},
                     ]}]

        media, absent = scratch_detach.owned_media_state(registry, ["disk9", "disk9s1"])

        self.assertEqual(
            [(entry["bsd-name"], entry["class"], entry["busy"]) for entry in media],
            [("disk9", "AppleAPFSMedia", 0), ("disk9s1", "AppleAPFSVolume", 2)],
        )
        self.assertEqual(absent, [])

    def test_invalid_media_registry_is_reported_without_clearing_failed_ejection(self):
        def media(**fields):
            return [{"IOObjectClass": "IOMedia", "BSD Name": "disk7", "Open": True,
                     "IOServiceBusyState": 0, "IOObjectRetainCount": 3, **fields}]

        cases = (
            (b"invalid", "InvalidFileException"),
            ({}, "invalid-media-registry"),
            (media(Open="yes"), "invalid-owned-media-field"),
            (media(IOObjectClass="bad class\n"), "invalid-owned-media-field"),
            (media(IOServiceBusyState=True), "invalid-owned-media-field"),
            (media(IOObjectRetainCount="3"), "invalid-owned-media-field"),
            (media(IORegistryEntryChildren="x"), "invalid-media-registry"),
            (media(IORegistryEntryChildren=[7]), "invalid-media-registry"),
            (media(IORegistryEntryChildren=[{"IOObjectClass": "IOMediaBSDClient"}]),
             "invalid-owned-media-client"),
            (media(IORegistryEntryChildren=[{"IOObjectClass": "bad class\n"}]),
             "invalid-owned-media-client"),
            (media() + media(), "ambiguous-owned-media"),
        )
        for payload, reason in cases:
            with self.subTest(reason=reason):
                def operating_system(command, **options):
                    if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                        return subprocess.CompletedProcess(command, 1)
                    if command[:2] == ["/usr/bin/hdiutil", "info"]:
                        return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
                    if command[0] == "/usr/sbin/ioreg":
                        data = payload if isinstance(payload, bytes) else plistlib.dumps(payload)
                        return subprocess.CompletedProcess(command, 0, stdout=data)
                    if command[0] == "/usr/sbin/lsof":
                        return subprocess.CompletedProcess(command, 0, stdout="")
                    raise subprocess.CalledProcessError(1, command)

                output, errors = io.StringIO(), io.StringIO()
                with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
                    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                        result = scratch_detach.detach_scratch(VOLUME, IMAGE)

                self.assertEqual(result, 1)
                self.assertIn("owned scratch media unavailable: " + reason, errors.getvalue())
                self.assertNotIn("bad class", output.getvalue() + errors.getvalue())

    def test_holder_field_errors_do_not_log_unselected_file_fields(self):
        for fields in (
            "p123\nnunselected-file-field\n",
            "p123\ncfixture\nf\n",
            "p123\ncfixture\nf\x00unselected-file-field\n",
            "p123\ncfixture\nf\x1bunselected-file-field\n",
            "p123\ncfixture\nqunselected-file-field\n",
            "pinvalid\ncfixture\nf3\n",
        ):
            with self.subTest(fields=fields):
                def operating_system(command, **options):
                    if command[:2] == ["/usr/bin/hdiutil", "detach"]:
                        return subprocess.CompletedProcess(command, 1)
                    if command[:2] == ["/usr/bin/hdiutil", "info"]:
                        return subprocess.CompletedProcess(command, 0, stdout=INVENTORY)
                    if command[0] == "/usr/sbin/lsof":
                        return subprocess.CompletedProcess(command, 0, stdout=fields)
                    raise subprocess.CalledProcessError(1, command)

                output, errors = io.StringIO(), io.StringIO()
                with mock.patch.object(scratch_detach.subprocess, "run", side_effect=operating_system):
                    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                        result = scratch_detach.detach_scratch(VOLUME, IMAGE)

                self.assertEqual(result, 1)
                self.assertIn("invalid-holder-fields", errors.getvalue())
                self.assertNotIn("unselected-file-field", output.getvalue() + errors.getvalue())


if __name__ == "__main__":
    unittest.main()
