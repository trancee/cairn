"""Numeric-only, final Tamarin RTS accounting for diagnostic screening pairs."""

import ast
from decimal import Decimal
import hashlib
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from types import TracebackType

from equations.maude_runner import GuardError
from replay import ReplayError
from native_profile import NativeProfileError


MAXIMUM_STATISTICS_BYTES = 200_000
REQUIRED_FIELDS = {
    "bytes allocated", "allocated_bytes", "num_GCs", "copied_bytes",
    "max_live_bytes", "n_capabilities", "task_count", "bound_task_count",
    "worker_count", "peak_worker_count", "major_gcs",
    *(f"{phase}_{clock}_seconds" for phase in ("init", "mut", "GC", "exit", "total")
      for clock in ("cpu", "wall")),
}


class RuntimeProfileError(GuardError):
    """A redacted failure of diagnostic runtime accounting."""


def numeric_statistics(data: bytes) -> dict[str, str]:
    if not 0 < len(data) <= MAXIMUM_STATISTICS_BYTES:
        raise RuntimeProfileError("missing or oversized Tamarin RTS statistics")
    try:
        text = data.decode("ascii")
        beginning = re.search(r"(?m)^[ \t]*\[", text)
        if beginning is None:
            raise ValueError("missing statistics list")
        pairs = ast.literal_eval(text[beginning.start():])
    except (UnicodeError, ValueError, SyntaxError, RecursionError) as error:
        raise RuntimeProfileError("malformed Tamarin RTS statistics") from error
    if not isinstance(pairs, list) or not 8 <= len(pairs) <= 256:
        raise RuntimeProfileError("malformed Tamarin RTS statistics structure")
    fields: dict[str, str] = {}
    for entry in pairs:
        if not isinstance(entry, tuple) or len(entry) != 2:
            raise RuntimeProfileError("malformed Tamarin RTS statistics entry")
        name, value = entry
        if (
            not isinstance(name, str) or not isinstance(value, str)
            or re.fullmatch(r"[A-Za-z0-9_ -]{1,80}", name) is None
            or len(value) > 80
            or re.fullmatch(r"[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]{1,3})?", value) is None
            or name in fields or not Decimal(value).is_finite()
        ):
            raise RuntimeProfileError("invalid numeric Tamarin RTS statistics")
        fields[name] = value
    if not REQUIRED_FIELDS <= fields.keys():
        raise RuntimeProfileError("incomplete Tamarin RTS statistics")
    for name in ("n_capabilities", "task_count"):
        if not fields[name].isdecimal() or int(fields[name]) <= 0:
            raise RuntimeProfileError("invalid Tamarin RTS capability or task count")
    return fields


def reviewed_stderr(errors: bytes, backend: str) -> bool:
    banner = (
        f"maude tool: '{backend}'\n checking version: 3.5.1. OK.\n"
        " checking installation: OK.\n"
    ).encode()
    progress = (
        "Theory loaded", "Theory translated", "Derivation checks started", "Derivation checks ended",
    )
    return errors == banner or any(
        errors == banner + "".join(
            f"[Theory {theory}] {stage}\n" for stage in progress
        ).encode()
        for theory in ("CairnRatchet", "CairnNaturalDerivationProbe")
    )


def launch(executable: str, statistics: str, backend: str) -> int:
    with subprocess.Popen(
        [executable, *sys.argv[1:], "+RTS", "-t" + statistics, "--machine-readable", "-RTS"],
        stderr=subprocess.PIPE,
    ) as process:
        errors = bytearray()
        while chunk := process.stderr.read(4096):
            errors.extend(chunk[:max(0, 4097 - len(errors))])
        result = process.wait()
    if result != 0 or not reviewed_stderr(bytes(errors), backend):
        print("FAIL: Tamarin RTS process failed or emitted unexpected stderr", file=sys.stderr)
        return 1
    return 0


class TamarinRuntimeProfile:
    def __init__(self, backend: Path | None = None) -> None:
        self.backend = "maude" if backend is None else str(backend)

    def __enter__(self) -> "TamarinRuntimeProfile":
        if os.environ.get("GHCRTS"):
            raise RuntimeProfileError("Tamarin RTS profiling requires GHCRTS unset or empty")
        executable = shutil.which("tamarin-prover")
        if executable is None:
            raise RuntimeProfileError("Tamarin RTS profiling executable unavailable")
        self.executable = Path(executable).resolve(strict=True)
        self.digest = hashlib.sha256(self.executable.read_bytes()).hexdigest()
        self.temporary = tempfile.TemporaryDirectory(prefix="cairn-tamarin-rts-")
        self.statistics = Path(self.temporary.name) / "runtime.stats"
        self.launcher = Path(self.temporary.name) / "tamarin-prover"
        try:
            self.launcher.write_text(
                f"#!{sys.executable}\nimport sys\n"
                f"sys.path[:0] = {[str(Path(__file__).parent), str(Path(__file__).parents[2])]!r}\n"
                "from tamarin_profile import launch\n"
                f"raise SystemExit(launch({str(self.executable)!r}, "
                f"{str(self.statistics)!r}, {self.backend!r}))\n",
            )
            self.launcher.chmod(0o700)
        except OSError:
            self.temporary.cleanup()
            raise
        return self

    def __exit__(
        self, error_type: type[BaseException] | None,
        error: BaseException | None, traceback: TracebackType | None,
    ) -> None:
        self.temporary.cleanup()
        if isinstance(error, (GuardError, ReplayError)) and not isinstance(
            error, (RuntimeProfileError, NativeProfileError),
        ):
            raise RuntimeProfileError(
                "Tamarin RTS process failed, timed out or emitted unexpected stderr",
            ) from error

    def command(self, command: list[str]) -> list[str]:
        return [str(self.launcher), *command[1:]]

    def report(self) -> dict[str, object]:
        if hashlib.sha256(self.executable.read_bytes()).hexdigest() != self.digest:
            raise RuntimeProfileError("Tamarin RTS profiling executable changed")
        with os.fdopen(os.open(
            self.statistics, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
        ), "rb") as stream:
            if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                raise RuntimeProfileError("Tamarin RTS statistics require a regular file")
            fields = numeric_statistics(stream.read(MAXIMUM_STATISTICS_BYTES + 1))
        return {
            "accounting": "final Tamarin RTS aggregates, not complete descendant CPU",
            "executable_sha256": self.digest,
            "numeric_fields": fields,
        }
