"""Private native lifecycle records with bounded per-process operation batching."""

import json
import os
from pathlib import Path
import stat

from equations.maude_image import BoundaryError


def open_report() -> int | None:
    destination = os.environ.get("CAIRN_MAUDE_GUARD_REPORT")
    if not destination:
        return None
    if not Path(destination).is_absolute():
        raise BoundaryError("native evidence report: expected absolute path")
    descriptor = os.open(
        destination, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600,
    )
    valid = False
    try:
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            raise BoundaryError("native evidence report: expected regular file")
        valid = True
        return descriptor
    finally:
        if not valid:
            os.close(descriptor)


def encoded_record(event: str, **fields: str) -> bytes:
    return (json.dumps({"event": event, "pid": os.getpid(), **fields}) + "\n").encode("ascii")


def write_records(descriptor: int, records: bytes | bytearray) -> None:
    if os.write(descriptor, records) != len(records):
        raise BoundaryError("native evidence report: incomplete write")


def record(event: str, **fields: str) -> None:
    descriptor = open_report()
    if descriptor is not None:
        try:
            write_records(descriptor, encoded_record(event, **fields))
        finally:
            os.close(descriptor)


class OperationJournal:
    def __init__(self) -> None:
        self.descriptor: int | None = None
        self.pending = bytearray()

    def record(self, event: str, *, kind: str) -> None:
        if self.descriptor is None:
            self.descriptor = open_report()
        if self.descriptor is None:
            return
        self.pending.extend(encoded_record(event, kind=kind))
        if len(self.pending) >= 16_384:
            self.flush()

    def flush(self) -> None:
        if self.descriptor is not None and self.pending:
            write_records(self.descriptor, self.pending)
            self.pending.clear()

    def close(self) -> None:
        if self.descriptor is not None:
            try:
                self.flush()
            finally:
                descriptor, self.descriptor = self.descriptor, None
                os.close(descriptor)
