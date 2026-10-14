#!/usr/bin/env python3
"""Fail-closed persistent Maude proxy for Cairn's ratchet proof tools."""

import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import stat
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from equations.maude_image import BoundaryError, validate_query, validate_reply
from equations.maude_module import validate_module


PROMPT = b"Maude> "
FLAGS = {"-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"}
SETUP = {"set show command off .", "set show timing off .", "set show stats off ."}


def record(event: str, **fields: str) -> None:
    destination = os.environ.get("CAIRN_MAUDE_GUARD_REPORT")
    if destination:
        if not Path(destination).is_absolute():
            raise BoundaryError("native evidence report: expected absolute path")
        descriptor = os.open(
            destination, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_NOFOLLOW | os.O_NONBLOCK, 0o600,
        )
        try:
            if not stat.S_ISREG(os.fstat(descriptor).st_mode):
                raise BoundaryError("native evidence report: expected regular file")
            encoded = (json.dumps({"event": event, "pid": os.getpid(), **fields}) + "\n").encode("ascii")
            if os.write(descriptor, encoded) != len(encoded):
                raise BoundaryError("native evidence report: incomplete write")
        finally:
            os.close(descriptor)


def read_reply(process: subprocess.Popen[bytes]) -> bytes:
    if process.stdout is None or process.stderr is None:
        raise BoundaryError("native process: missing output pipe")
    output = bytearray()
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ, "output")
        selector.register(process.stderr, selectors.EVENT_READ, "errors")
        while True:
            for key, _ in sorted(selector.select(), key=lambda event: event[0].data != "errors"):
                chunk = os.read(key.fd, 8096)
                if not chunk:
                    if key.data == "output":
                        raise BoundaryError("native process: premature EOF")
                    selector.unregister(key.fileobj)
                    continue
                if key.data == "errors":
                    raise BoundaryError("native process: stderr diagnostic")
                output.extend(chunk)
                if output.endswith(PROMPT):
                    return bytes(output[:-len(PROMPT)])


def forward(reply: bytes) -> None:
    sys.stdout.buffer.write(reply + PROMPT)
    sys.stdout.buffer.flush()


def interrupted(_signal: int, _frame: object) -> None:
    raise InterruptedError("native process interrupted")


def stop_native(process: subprocess.Popen[bytes]) -> tuple[int, bytes, bytes]:
    handlers = {number: signal.signal(number, signal.SIG_IGN) for number in (signal.SIGTERM, signal.SIGINT)}
    try:
        process.terminate()
        try:
            output, errors = process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            output, errors = process.communicate()
        if process.returncode is None:
            raise BoundaryError("native shutdown: missing exit status")
        return process.returncode, output, errors
    finally:
        for pipe in (process.stdin, process.stdout, process.stderr):
            if pipe is not None:
                pipe.close()
        for number, handler in handlers.items():
            signal.signal(number, handler)


def validate_shutdown(result: tuple[int, bytes, bytes]) -> None:
    status, output, errors = result
    if status not in {0, -signal.SIGTERM, -signal.SIGKILL} or output.strip() or errors:
        raise BoundaryError("native shutdown: unexpected exit or diagnostic")


def main() -> int:
    process: subprocess.Popen[bytes] | None = None
    pending = False
    ready = False
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        executable = os.environ.get("CAIRN_MAUDE_BINARY") or shutil.which("maude")
        if executable is None or Path(executable).resolve() == Path(__file__).resolve():
            raise BoundaryError("native process: missing or recursive executable")
        version = subprocess.run([executable, "--version"], capture_output=True, timeout=30, check=False)
        if version.returncode or version.stdout.strip() != b"3.5.1" or version.stderr:
            raise BoundaryError("native process: expected Maude 3.5.1")
        record("version")
        if sys.argv[1:] == ["--version"]:
            sys.stdout.buffer.write(version.stdout)
            return 0
        if not sys.argv[1:]:
            if sys.stdin.buffer.read() != b"quit\n":
                raise BoundaryError("native installation: unsupported input")
            installation = subprocess.run(
                [executable], input=b"quit\n", capture_output=True, timeout=30, check=False,
            )
            if installation.returncode or installation.stderr:
                raise BoundaryError("native installation: failed probe")
            record("installation")
            sys.stdout.buffer.write(installation.stdout)
            return 0
        if not sys.argv[1:] or set(sys.argv[1:]) != FLAGS or len(sys.argv[1:]) != len(FLAGS):
            raise BoundaryError("native process: unsupported invocation")
        process = subprocess.Popen(
            [executable, *sys.argv[1:]], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, bufsize=0,
        )
        if process.stdin is None:
            raise BoundaryError("native process: missing input pipe")
        record("start")
        greeting = read_reply(process)
        if greeting.strip():
            raise BoundaryError("native process: unexpected greeting")
        forward(greeting)
        setup: set[str] = set()
        module: list[bytes] = []
        for line in sys.stdin.buffer:
            try:
                command = line.decode("ascii").strip()
            except UnicodeDecodeError as error:
                raise BoundaryError("native command: non-ASCII syntax") from error
            if module:
                module.append(line)
                if command != "endfm":
                    continue
                validate_module(b"".join(module).decode("ascii"))
                process.stdin.write(b"".join(module))
                process.stdin.flush()
                reply = read_reply(process)
                if reply.strip():
                    raise BoundaryError("native module: unexpected reply")
                module.clear()
                ready = True
                record("module")
                forward(reply)
                continue
            if command in SETUP and not ready:
                if command in setup:
                    raise BoundaryError("native setup: duplicate command")
                setup.add(command)
                process.stdin.write(line)
                process.stdin.flush()
                reply = read_reply(process)
                if reply.strip():
                    raise BoundaryError("native setup: unexpected reply")
                forward(reply)
                continue
            if command == "fmod MSG is" and not ready and setup == SETUP:
                module.append(line)
                continue
            if not ready:
                raise BoundaryError("native command: missing reviewed module")
            query = validate_query(command)
            record("begin", kind=query.kind)
            pending = True
            process.stdin.write(line)
            process.stdin.flush()
            reply = read_reply(process)
            try:
                validate_reply(query, reply.decode("ascii"))
            except UnicodeDecodeError as error:
                raise BoundaryError("native reply: non-ASCII syntax") from error
            record("accepted", kind=query.kind)
            pending = False
            forward(reply)
        if module:
            raise BoundaryError("native module: truncated declaration")
        if not ready:
            raise BoundaryError("native command: missing reviewed module")
        shutdown = stop_native(process)
        process = None
        validate_shutdown(shutdown)
        record("shutdown")
        return 0
    except InterruptedError:
        if pending or not ready:
            record("failure", reason="native operation interrupted")
            return 1
        if process is not None:
            shutdown = stop_native(process)
            process = None
            try:
                validate_shutdown(shutdown)
            except BoundaryError:
                record("failure", reason="native shutdown failed")
                print("FAIL: native shutdown failed", file=sys.stderr, flush=True)
                return 1
        record("shutdown")
        return 0
    except (OSError, BoundaryError, subprocess.TimeoutExpired) as error:
        reason = str(error) if isinstance(error, BoundaryError) else "native process: I/O or version failure"
        try:
            record("failure", reason=reason)
        except (OSError, BoundaryError):
            reason = "native evidence report: I/O failure"
        print(f"FAIL: {reason}", file=sys.stderr, flush=True)
        try:
            forward(b"FAIL: Cairn Maude boundary rejected this operation.\n")
        except BrokenPipeError:
            print("FAIL: native consumer closed its input", file=sys.stderr, flush=True)
        return 1
    finally:
        if process is not None:
            stop_native(process)


if __name__ == "__main__":
    raise SystemExit(main())
