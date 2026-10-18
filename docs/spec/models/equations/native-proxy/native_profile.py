"""Bounded numeric native-phase evidence, never performance acceptance."""

import json
import os
from pathlib import Path
import stat
import sys
import tempfile
from types import TracebackType

from equations.maude_runner import GuardError, unique_fields
from replay import ReplayError


MAXIMUM_PROFILE_BYTES = 16_384
MAXIMUM_INTEGER = 2**64 - 1
PHASES = {
    "input", "query_validation", "journal", "native_io", "reply_validation", "forwarding",
}
INPUT_IO_PHASES = {"input_wait", "input_read"}
NATIVE_IO_PHASES = {
    "native_write", "native_wait", "native_stdout_read", "native_stderr_read",
}
IO_PHASES = INPUT_IO_PHASES | NATIVE_IO_PHASES


class NativeProfileError(GuardError):
    """A redacted failure of diagnostic native CPU accounting."""


def integer(value: object) -> bool:
    return type(value) is int and 0 <= value <= MAXIMUM_INTEGER


def phase_records(data: bytes) -> list[dict[str, object]]:
    if not 0 < len(data) <= MAXIMUM_PROFILE_BYTES or not data.endswith(b"\n"):
        raise NativeProfileError("missing, truncated or oversized native CPU profiles")
    try:
        records = [
            json.loads(line, object_pairs_hook=unique_fields)
            for line in data.decode("ascii").splitlines()
        ]
    except (GuardError, ValueError, UnicodeError, RecursionError) as error:
        raise NativeProfileError("malformed native CPU profiles") from error
    if not 1 <= len(records) <= 8:
        raise NativeProfileError("invalid native CPU profile process count")
    identifiers: set[int] = set()
    for record in records:
        if not isinstance(record, dict) or set(record) != {
            "pid", "interactive_cpu_nanoseconds", "interactive_wall_nanoseconds", "phases",
            "io_phases",
        }:
            raise NativeProfileError("malformed native CPU profile fields")
        identifier = record["pid"]
        if (
            type(identifier) is not int or not 0 < identifier < 2**32
            or identifier in identifiers
        ):
            raise NativeProfileError("invalid or repeated native CPU profile process")
        identifiers.add(identifier)
        if any(not integer(record[field]) for field in (
            "interactive_cpu_nanoseconds", "interactive_wall_nanoseconds",
        )):
            raise NativeProfileError("invalid native CPU profile clock")
        phases = record["phases"]
        for field, names in (("phases", PHASES), ("io_phases", IO_PHASES)):
            if not isinstance(record[field], dict) or set(record[field]) != names:
                raise NativeProfileError("incomplete native CPU profile phases")
            for counters in record[field].values():
                if (
                    not isinstance(counters, dict)
                    or set(counters) != {"calls", "cpu_nanoseconds", "wall_nanoseconds"}
                    or not all(integer(value) for value in counters.values())
                ):
                    raise NativeProfileError("invalid native CPU profile counters")
                if counters["calls"] == 0 and (
                    counters["cpu_nanoseconds"] != 0 or counters["wall_nanoseconds"] != 0
                ):
                    raise NativeProfileError("native CPU profile has time for an uncalled phase")
        queries = phases["query_validation"]["calls"]
        if (
            phases["journal"]["calls"] != 2 * queries
            or phases["input"]["calls"] < queries
            or any(phases[name]["calls"] != queries for name in (
                "native_io", "reply_validation", "forwarding",
            ))
        ):
            raise NativeProfileError("inconsistent native CPU profile operation counts")
        io_phases = record["io_phases"]
        input_reads = io_phases["input_read"]["calls"]
        if (
            input_reads == 0
            or io_phases["input_wait"]["calls"] not in (input_reads, input_reads + 1)
            or io_phases["native_write"]["calls"] != queries + 4
            or io_phases["native_stdout_read"]["calls"] < queries + 5
            or io_phases["native_wait"]["calls"] < io_phases["native_stdout_read"]["calls"]
            or io_phases["native_stderr_read"]["calls"] > 1
        ):
            raise NativeProfileError("inconsistent native CPU profile I/O operation counts")
        for clock in ("cpu", "wall"):
            field = f"{clock}_nanoseconds"
            total = record[f"interactive_{clock}_nanoseconds"]
            if sum(phase[field] for phase in phases.values()) > total:
                raise NativeProfileError("inconsistent native CPU profile clock totals")
            if (
                sum(io_phases[name][field] for name in INPUT_IO_PHASES)
                > phases["input"][field]
                or sum(io_phases[name][field] for name in NATIVE_IO_PHASES) > total
            ):
                raise NativeProfileError("inconsistent native CPU profile I/O clock totals")
    return records


class NativePhaseProfile:
    def __init__(self, guarded: bool) -> None:
        self.guarded = guarded
        self.path: Path | None = None

    def __enter__(self) -> "NativePhaseProfile":
        if sys.platform != "linux" or sys.maxsize <= 2**32:
            raise NativeProfileError("native CPU profiling requires 64-bit native Linux")
        if os.environ.get("CAIRN_MAUDE_PHASE_REPORT"):
            raise NativeProfileError("native CPU profiling requires an owned explicit report")
        self.temporary = tempfile.TemporaryDirectory(prefix="cairn-native-cpu-")
        if self.guarded:
            self.path = Path(self.temporary.name) / "phases.jsonl"
        return self

    def __exit__(
        self, error_type: type[BaseException] | None,
        error: BaseException | None, traceback: TracebackType | None,
    ) -> None:
        self.temporary.cleanup()
        if isinstance(error, (GuardError, ReplayError, OSError)) and not isinstance(
            error, NativeProfileError,
        ):
            raise NativeProfileError("native CPU diagnostic process or evidence failed") from error

    def report(self, driver_cpu_nanoseconds: int) -> dict[str, object]:
        if not integer(driver_cpu_nanoseconds):
            raise NativeProfileError("invalid native CPU diagnostic driver clock")
        records = []
        if self.path is not None:
            with os.fdopen(os.open(
                self.path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
            ), "rb") as stream:
                if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                    raise NativeProfileError("native CPU profiles require a regular file")
                records = phase_records(stream.read(MAXIMUM_PROFILE_BYTES + 1))
        return {
            "accounting": "instrumented interactive phases, not complete process-tree accounting",
            "driver_thread_cpu_nanoseconds": driver_cpu_nanoseconds,
            "processes": records,
        }
