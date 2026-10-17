"""Diagnostic-only sampling of owned native guard processes on Linux."""

import errno
import os
from pathlib import Path
import threading
import time
from types import TracebackType

from equations.maude_runner import GuardError


class LinuxProcessProfile:
    def __init__(self, proxy: Path) -> None:
        identity = proxy.stat()
        self.identity = identity.st_dev, identity.st_ino
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.collect, name="native-process-profile")
        self.failure: OSError | UnicodeError | ValueError | GuardError | None = None
        self.processes: dict[tuple[int, int], dict[str, int | float]] = {}
        self.active: dict[int, int] = {}
        self.disappeared_reads = 0
        self.sampler_cpu_seconds = 0.0
        self.clock_ticks_per_second = os.sysconf("SC_CLK_TCK")
        if self.clock_ticks_per_second <= 0:
            raise GuardError("native Linux process clock unavailable")

    def __enter__(self) -> "LinuxProcessProfile":
        try:
            enabled = Path("/proc/sys/kernel/sched_schedstats").read_bytes().strip()
        except FileNotFoundError:
            self.scheduler_statistics = "not-exposed"
        else:
            if enabled not in (b"0", b"1"):
                raise GuardError("malformed native Linux scheduler statistics setting")
            self.scheduler_statistics = "enabled" if enabled == b"1" else "disabled"
        self.started = time.monotonic()
        self.thread.start()
        return self

    def __exit__(
        self, error_type: type[BaseException] | None,
        error: BaseException | None, traceback: TracebackType | None,
    ) -> None:
        self.stop.set()
        self.thread.join()
        if error is None and self.failure is not None:
            raise GuardError("native Linux process profile unavailable or malformed") from self.failure

    def read(self, path: Path) -> bytes | None:
        try:
            return path.read_bytes()
        except OSError as error:
            if error.errno not in (errno.ENOENT, errno.ESRCH):
                raise
            self.disappeared_reads += 1
            return None

    def descendants(self) -> set[int]:
        pending = [os.getpid()]
        seen: set[int] = set()
        while pending:
            identifier = pending.pop()
            if identifier in seen:
                continue
            seen.add(identifier)
            try:
                tasks = list((Path("/proc") / str(identifier) / "task").iterdir())
            except OSError as error:
                if error.errno not in (errno.ENOENT, errno.ESRCH):
                    raise
                self.disappeared_reads += 1
                continue
            for task in tasks:
                children = self.read(task / "children")
                if children is None:
                    continue
                fields = children.decode("ascii").split()
                if any(not field.isdecimal() or int(field) <= 0 for field in fields):
                    raise GuardError("malformed native Linux descendant identifiers")
                pending.extend(int(field) for field in fields)
        return seen - {os.getpid()}

    def discover(self) -> None:
        for identifier in self.descendants():
            directory = Path("/proc") / str(identifier)
            try:
                executable = (directory / "exe").stat()
            except OSError as error:
                if error.errno not in (errno.ENOENT, errno.ESRCH):
                    raise
                self.disappeared_reads += 1
                continue
            if (executable.st_dev, executable.st_ino) != self.identity:
                continue
            command = self.read(directory / "cmdline")
            if command is not None and b"-interactive" in command.split(b"\0"):
                self.sample(identifier)

    def sample(self, identifier: int) -> None:
        directory = Path("/proc") / str(identifier)
        status = self.read(directory / "stat")
        counters = self.read(directory / "schedstat")
        if status is None or counters is None:
            self.active.pop(identifier, None)
            return
        prefix, separator, suffix = status.decode("ascii").rpartition(")")
        fields = suffix.split()
        if (
            not separator or not prefix.startswith(f"{identifier} (")
            or len(fields) < 20
            or any(not fields[index].isdecimal() for index in (11, 12, 19))
        ):
            raise GuardError("malformed native Linux process identity")
        started = int(fields[19])
        if identifier in self.active and self.active[identifier] != started:
            self.active.pop(identifier)
            return
        values = counters.decode("ascii").split()
        if len(values) != 3 or any(not value.isdecimal() for value in values):
            raise GuardError("malformed native Linux scheduler counters")
        elapsed = time.monotonic() - self.started
        observation = self.processes.setdefault((identifier, started), {
            "pid": identifier, "start_clock_ticks": started,
            "first_seen_seconds": elapsed, "samples": 0,
        })
        observation.update({
            "last_seen_seconds": elapsed,
            "last_observed_cpu_nanoseconds": int(values[0]),
            "last_observed_runqueue_nanoseconds": int(values[1]),
            "last_observed_timeslices": int(values[2]),
            "last_observed_user_clock_ticks": int(fields[11]),
            "last_observed_system_clock_ticks": int(fields[12]),
        })
        observation["samples"] += 1
        self.active[identifier] = started

    def collect(self) -> None:
        started = time.thread_time()
        discovery = 0.0
        try:
            while not self.stop.is_set():
                if time.monotonic() >= discovery:
                    self.discover()
                    discovery = time.monotonic() + 0.1
                for identifier in tuple(self.active):
                    self.sample(identifier)
                self.stop.wait(0.01)
        except (OSError, UnicodeError, ValueError, GuardError) as error:
            self.failure = error
        finally:
            self.sampler_cpu_seconds = time.thread_time() - started

    def report(self) -> dict[str, object]:
        return {
            "accounting": "last observed counters, not complete process accounting",
            "sampling_interval_seconds": 0.01,
            "discovery_interval_seconds": 0.1,
            "sampler_cpu_seconds": self.sampler_cpu_seconds,
            "scheduler_statistics_at_start": self.scheduler_statistics,
            "clock_ticks_per_second": self.clock_ticks_per_second,
            "disappeared_reads": self.disappeared_reads,
            "processes": [self.processes[key] for key in sorted(self.processes)],
        }
