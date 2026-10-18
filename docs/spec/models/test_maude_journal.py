"""Complete operation cycles cannot bypass native boundary lifecycle checks."""

import json
from pathlib import Path
import tempfile
import unittest

from equations.maude_runner import GuardError, boundary_complete


SOURCE_ID = "0" * 64
KINDS = ("reduce", "variants", "unify", "match")


def record(event, pid=41, **fields):
    return json.dumps({"event": event, "pid": pid, **fields}) + "\n"


def ready(pid=41):
    return (
        record("version", pid, source_id=SOURCE_ID)
        + record("start", pid) + record("module", pid)
    )


def cycle(kind="reduce", pid=41):
    return record("begin", pid, kind=kind) + record("accepted", pid, kind=kind)


class NativeJournalTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.report = Path(temporary.name) / "events.jsonl"

    def test_repeated_complete_cycles_preserve_all_operation_kinds(self):
        self.report.write_text(
            ready() + "".join(cycle(kind) * 1024 for kind in KINDS) + record("shutdown")
        )

        complete = boundary_complete(self.report, source_id=SOURCE_ID)

        self.assertTrue(complete)

    def test_noncanonical_valid_operations_retain_the_general_json_path(self):
        operations = "".join(
            json.dumps(
                {"pid": 41, "kind": kind, "event": event}, separators=(",\t", " : "),
            ) + "\n"
            for kind in KINDS for event in ("begin", "accepted")
        )
        self.report.write_text(ready() + operations * 4 + record("shutdown"))

        complete = boundary_complete(self.report, source_id=SOURCE_ID)

        self.assertTrue(complete)

    def test_complete_cycles_cannot_repair_an_invalid_initial_state(self):
        prefixes = (
            "",
            record("version", source_id=SOURCE_ID) + record("start"),
            ready() + record("begin", kind="match"),
            ready() + record("shutdown"),
        )
        for prefix in prefixes:
            with self.subTest(prefix=prefix):
                self.report.write_text(prefix + cycle() * 4 + record("shutdown"))

                with self.assertRaisesRegex(GuardError, "inconsistent native boundary lifecycle"):
                    boundary_complete(self.report, source_id=SOURCE_ID)

    def test_wrong_kind_or_process_cannot_complete_repeated_operations(self):
        for fields in ({"pid": 42, "kind": "reduce"}, {"pid": 41, "kind": "match"}):
            with self.subTest(fields=fields):
                invalid = record("begin", kind="reduce") + record("accepted", **fields)
                self.report.write_text(
                    ready() + cycle() * 4 + invalid * 4 + record("shutdown")
                )

                with self.assertRaisesRegex(GuardError, "inconsistent native boundary lifecycle"):
                    boundary_complete(self.report, source_id=SOURCE_ID)

    def test_malformed_later_record_is_not_hidden_by_complete_cycles(self):
        malformed = (
            '{"event": "begin", "pid": 41, "kind": "reduce", "extra": 1}\n',
            '{"event": "begin", "pid": 41, "kind": "reduce", "kind": "match"}\n',
            record("begin", kind="unknown"),
            record("accepted", kind="reduce"),
            record("version", source_id="1" * 64),
        )
        for invalid in malformed:
            with self.subTest(invalid=invalid):
                self.report.write_text(ready() + cycle() * 4 + invalid + cycle() * 4)

                with self.assertRaises(GuardError):
                    boundary_complete(self.report, source_id=SOURCE_ID)

    def test_truncated_tail_after_complete_cycles_cannot_establish_shutdown(self):
        for tail in ("", record("begin", kind="unify")):
            with self.subTest(tail=tail):
                self.report.write_text(ready() + cycle() * 4 + tail)

                complete = boundary_complete(self.report, source_id=SOURCE_ID)

                self.assertFalse(complete)

    def test_interleaved_processes_keep_independent_pending_operations(self):
        operations = "".join((
            record("begin", 41, kind="reduce"), record("begin", 42, kind="match"),
            record("accepted", 41, kind="reduce"), record("accepted", 42, kind="match"),
        ))
        self.report.write_text(
            ready(41) + ready(42) + cycle(pid=41) * 4 + operations * 4
            + cycle("match", 42) * 4 + record("shutdown", 41) + record("shutdown", 42)
        )

        complete = boundary_complete(self.report, source_id=SOURCE_ID)

        self.assertTrue(complete)

    def test_embedded_record_separators_cannot_repair_malformed_json(self):
        for separator in ("\v", "\f", "\x1c", "\x1d", "\x1e", "\x85", "\u2028", "\u2029"):
            with self.subTest(separator=repr(separator)):
                invalid = '{"event": "begin",' + separator + '"pid": 41, "kind": "reduce"}\n'
                self.report.write_text(ready() + cycle() * 4 + invalid + record("shutdown"))

                with self.assertRaises(GuardError):
                    boundary_complete(self.report, source_id=SOURCE_ID)
