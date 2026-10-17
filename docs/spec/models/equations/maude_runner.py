"""Run Tamarin with the mandatory proof-only Maude image boundary."""

from pathlib import Path
import json
import os
import re
import tempfile
import time


OPERATION_RECORD = re.compile(
    r'\{"event": "(begin|accepted)", "pid": ([1-9][0-9]{0,9}), '
    r'"kind": "(reduce|variants|unify|match)"\}'
)


class GuardError(RuntimeError):
    """A guarded proof command did not establish its native boundary evidence."""


def unique_fields(pairs: list[tuple[str, object]]) -> dict[str, object]:
    fields: dict[str, object] = {}
    for name, value in pairs:
        if name in fields:
            raise GuardError("duplicate native boundary field")
        fields[name] = value
    return fields


def boundary_complete(report: Path, *, source_id: str) -> bool:
    try:
        text = report.read_text()
    except (OSError, UnicodeError) as error:
        raise GuardError("missing native boundary records") from error
    if not text or not text.endswith("\n"):
        raise GuardError("truncated native boundary records")
    states: dict[int, tuple[str, str | None]] = {}
    versions: set[int] = set()
    installations: set[int] = set()
    for line in text.splitlines():
        operation = OPERATION_RECORD.fullmatch(line)
        if operation is not None:
            name, identifier, kind = operation[1], int(operation[2]), operation[3]
            previous = ("ready", None) if name == "begin" else ("pending", kind)
            if states.get(identifier) != previous:
                raise GuardError("inconsistent native boundary lifecycle")
            states[identifier] = ("pending", kind) if name == "begin" else ("ready", None)
            continue
        try:
            event = json.loads(line, object_pairs_hook=unique_fields)
        except (ValueError, RecursionError) as error:
            raise GuardError("malformed native boundary records") from error
        if not isinstance(event, dict) or type(event.get("pid")) is not int or event["pid"] <= 0:
            raise GuardError("malformed native boundary record")
        name = event.get("event")
        if not isinstance(name, str):
            raise GuardError("malformed native boundary event")
        expected = {"event", "pid"}
        if name == "version":
            expected.add("source_id")
            identity = event.get("source_id")
            if not isinstance(identity, str) or re.fullmatch(r"[0-9a-f]{64}", identity) is None:
                raise GuardError("missing or malformed native boundary source identity")
            if identity != source_id:
                raise GuardError("stale native boundary source identity; rebuild the maintained guard")
        elif name in {"begin", "accepted"}:
            expected.add("kind")
            if not isinstance(event.get("kind"), str) or event["kind"] not in {
                "reduce", "variants", "unify", "match",
            }:
                raise GuardError("malformed native boundary operation")
        elif name == "failure":
            expected.add("reason")
        if set(event) != expected:
            raise GuardError("malformed native boundary fields")
        identifier = event["pid"]
        state = states.get(identifier)
        if name == "version" and state is None and identifier not in versions:
            versions.add(identifier)
        elif name == "installation" and state is None and identifier in versions and identifier not in installations:
            installations.add(identifier)
        elif name == "start" and state is None and identifier in versions:
            states[identifier] = "start", None
        elif name == "module" and state == ("start", None):
            states[identifier] = "ready", None
        elif name == "begin" and state == ("ready", None):
            states[identifier] = "pending", event["kind"]
        elif name == "accepted" and state == ("pending", event["kind"]):
            states[identifier] = "ready", None
        elif name == "shutdown" and state == ("ready", None):
            states[identifier] = "shutdown", None
        elif name == "failure":
            raise GuardError("native boundary rejected an operation")
        else:
            raise GuardError("inconsistent native boundary lifecycle")
    if not versions:
        raise GuardError("missing native boundary records")
    return all(state == ("shutdown", None) for state in states.values())


def run_guarded_tamarin(
    command: list[str], timeout: int, *, proxy: Path | None = None,
    phase_report: Path | None = None,
) -> str:
    from .maude_native import select_proxy
    from replay import ReplayError, run

    if not command or Path(command[0]).name != "tamarin-prover" or any(
        argument.startswith("--with-maude") for argument in command[1:]
    ):
        raise GuardError("unsupported guarded Tamarin invocation")
    if os.environ.get("CAIRN_MAUDE_PHASE_REPORT"):
        raise GuardError("native CPU profiling requires an owned explicit report")
    if phase_report is not None and not phase_report.is_absolute():
        raise GuardError("native CPU profiling requires an absolute report path")
    proxy, source_id = select_proxy(proxy)
    with tempfile.TemporaryDirectory(prefix="cairn-maude-boundary-") as temporary:
        report = Path(temporary) / "events.jsonl"
        try:
            output = run([
                "env", f"CAIRN_MAUDE_GUARD_REPORT={report}",
                *([] if phase_report is None else [f"CAIRN_MAUDE_PHASE_REPORT={phase_report}"]),
                *command, f"--with-maude={proxy}",
            ], timeout)
        except (OSError, ReplayError) as error:
            raise GuardError(str(error)) from error
        deadline = time.monotonic() + 5
        while not boundary_complete(report, source_id=source_id):
            if time.monotonic() >= deadline:
                raise GuardError("native boundary shutdown incomplete")
            time.sleep(0.001)
    return output
