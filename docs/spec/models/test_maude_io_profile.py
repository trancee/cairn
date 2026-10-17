"""Nested stream-I/O evidence at the existing diagnostic report boundary."""

import unittest

from test_maude_native_profile import encoded, record
from native_profile import MAXIMUM_PROFILE_BYTES, NativeProfileError, phase_records


class NativeIoStatisticsTests(unittest.TestCase):
    def test_nested_io_clocks_are_not_added_to_their_parent_phases(self):
        entry = record()
        entry["phases"]["native_io"]["cpu_nanoseconds"] = 800
        entry["phases"]["native_io"]["wall_nanoseconds"] = 1600
        for name, cpu, wall in (
            ("native_write", 250, 400),
            ("native_wait", 400, 1000),
            ("native_stdout_read", 100, 200),
        ):
            entry["io_phases"][name]["cpu_nanoseconds"] = cpu
            entry["io_phases"][name]["wall_nanoseconds"] = wall

        result = phase_records(encoded([entry]))

        self.assertEqual(result, [entry])

    def test_io_operation_counts_include_setup_and_allow_only_one_stderr_eof(self):
        for name, calls in (
            ("input_read", 0), ("input_wait", 1), ("input_wait", 4),
            ("native_write", 5), ("native_write", 7),
            ("native_wait", 6), ("native_stdout_read", 6),
            ("native_stderr_read", 2),
        ):
            entry = record()
            entry["io_phases"][name]["calls"] = calls
            if calls == 0:
                entry["io_phases"][name]["cpu_nanoseconds"] = 0
                entry["io_phases"][name]["wall_nanoseconds"] = 0
            with self.subTest(name=name, calls=calls):
                with self.assertRaisesRegex(NativeProfileError, "I/O operation counts"):
                    phase_records(encoded([entry]))

    def test_io_clock_families_cannot_exceed_their_enclosing_scope(self):
        for clock in ("cpu_nanoseconds", "wall_nanoseconds"):
            for family in ("input", "native"):
                entry = record()
                if family == "input":
                    entry["io_phases"]["input_read"][clock] = (
                        entry["phases"]["input"][clock]
                    )
                else:
                    for name in ("native_write", "native_wait", "native_stdout_read"):
                        entry["io_phases"][name][clock] = (
                            entry[f"interactive_{clock}"] // 2
                        )
                with self.subTest(clock=clock, family=family):
                    with self.assertRaisesRegex(NativeProfileError, "I/O clock totals"):
                        phase_records(encoded([entry]))

    def test_missing_unknown_duplicate_and_malformed_io_fields_reject(self):
        malformed = []
        entry = record()
        del entry["io_phases"]
        malformed.append(encoded([entry]))
        for value in (None, [], {}, dict(record()["io_phases"], unknown={})):
            entry = record()
            entry["io_phases"] = value
            malformed.append(encoded([entry]))
        for name in record()["io_phases"]:
            entry = record()
            del entry["io_phases"][name]
            malformed.append(encoded([entry]))
        for counters in (None, [], {}, dict(record()["io_phases"]["input_read"], extra=0)):
            entry = record()
            entry["io_phases"]["input_read"] = counters
            malformed.append(encoded([entry]))
        malformed.append(encoded([record()]).replace(b'"native_write":', b'"input_wait":'))
        for data in malformed:
            with self.subTest(data=data):
                with self.assertRaises(NativeProfileError):
                    phase_records(data)

    def test_invalid_io_integers_reject_without_exposing_values(self):
        for name in record()["io_phases"]:
            for field in ("calls", "cpu_nanoseconds", "wall_nanoseconds"):
                for value in (True, -1, 0.5, None, 2**64, float("nan"), "omitted fixture payload"):
                    entry = record()
                    entry["io_phases"][name][field] = value
                    with self.subTest(name=name, field=field, value=value):
                        with self.assertRaises(NativeProfileError) as raised:
                            phase_records(encoded([entry]))
                        self.assertNotIn("omitted fixture payload", str(raised.exception))

    def test_uncalled_io_operations_cannot_claim_time(self):
        for field in ("cpu_nanoseconds", "wall_nanoseconds"):
            entry = record()
            entry["io_phases"]["native_stderr_read"][field] = 1
            with self.subTest(field=field):
                with self.assertRaisesRegex(NativeProfileError, "uncalled phase"):
                    phase_records(encoded([entry]))

    def test_fragmented_replies_stderr_eof_and_ready_input_interrupt_are_valid(self):
        entry = record()
        entry["io_phases"]["input_wait"]["calls"] = 3
        entry["io_phases"]["native_wait"]["calls"] = 10
        entry["io_phases"]["native_stdout_read"]["calls"] = 9
        entry["io_phases"]["native_stderr_read"]["calls"] = 1

        result = phase_records(encoded([entry]))

        self.assertEqual(result, [entry])

    def test_module_only_profile_retains_setup_io_without_query_phases(self):
        entry = record()
        for name in entry["phases"].keys() - {"input"}:
            entry["phases"][name] = {
                "calls": 0, "cpu_nanoseconds": 0, "wall_nanoseconds": 0,
            }
        entry["io_phases"]["native_write"]["calls"] = 4
        entry["io_phases"]["native_wait"]["calls"] = 5
        entry["io_phases"]["native_stdout_read"]["calls"] = 5

        result = phase_records(encoded([entry]))

        self.assertEqual(result, [entry])

    def test_eight_uint64_boundary_records_fit_the_existing_size_limit(self):
        maximum = 2**64 - 1
        queries = (maximum - 5) // 2
        records = [record(index + 1) for index in range(8)]
        for entry in records:
            for clock in ("cpu_nanoseconds", "wall_nanoseconds"):
                entry[f"interactive_{clock}"] = maximum
                for counters in entry["phases"].values():
                    counters[clock] = maximum // 6
                for name in ("input_wait", "input_read"):
                    entry["io_phases"][name][clock] = maximum // 12
                for name in ("native_write", "native_wait", "native_stdout_read"):
                    entry["io_phases"][name][clock] = maximum // 3
            for name, counters in entry["phases"].items():
                counters["calls"] = 2 * queries if name == "journal" else queries
            entry["io_phases"]["input_wait"]["calls"] = maximum
            entry["io_phases"]["input_read"]["calls"] = maximum
            entry["io_phases"]["native_write"]["calls"] = queries + 4
            entry["io_phases"]["native_wait"]["calls"] = queries + 5
            entry["io_phases"]["native_stdout_read"]["calls"] = queries + 5
        data = encoded(records)

        result = phase_records(data)

        self.assertEqual(result, records)
        self.assertLessEqual(len(data), MAXIMUM_PROFILE_BYTES)
