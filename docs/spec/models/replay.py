"""Replay one certificate with all source lemmas and an unchanged transition system."""

import argparse
import hashlib
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
from typing import Literal


class ReplayError(ValueError):
    pass


def lexical_views(text: str) -> tuple[str, str]:
    """Mask strings/comments for declaration discovery; retain strings for comparison."""
    masked, content = list(text), list(text)
    index = 0
    while index < len(text):
        start = index
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ReplayError("unterminated comment")
            index = end + 2
            comment = True
        elif text.startswith("//", index):
            end = text.find("\n", index)
            index = len(text) if end < 0 else end
            comment = True
        elif text[index] in "'\"":
            end = text.find(text[index], index + 1)
            if end < 0:
                raise ReplayError("unterminated quoted term/formula")
            index = end + 1
            comment = False
        else:
            index += 1
            continue
        for offset in range(start, index):
            if text[offset] != "\n":
                masked[offset] = " "
                if comment:
                    content[offset] = " "
    return "".join(masked), "".join(content)


def export_parts(export: str) -> tuple[str, dict[str, str]]:
    masked, _ = lexical_views(export)
    if not re.match(r"\s*theory [A-Za-z][A-Za-z0-9_]*\s+begin\b", masked):
        raise ReplayError("expected canonical theory header")
    endings = list(re.finditer(r"^end\s*$", masked, re.M))
    headers = list(re.finditer(r"^lemma ([A-Za-z][A-Za-z0-9_]*)\b", masked, re.M))
    if len(endings) != 1 or not headers or endings[0].start() < headers[-1].start():
        raise ReplayError("unsupported canonical lemma layout")
    if masked[endings[0].end():].strip():
        raise ReplayError("unexpected theory suffix")
    suffix = masked[headers[0].start():endings[0].start()]
    if re.search(r"^(?:rule|restriction|builtins|functions|equations|tactic|begin)\b", suffix, re.M):
        raise ReplayError("non-lemma declaration after first lemma")
    if len(headers) != len(re.findall(r"^lemma\b", masked, re.M)):
        raise ReplayError("unsupported lemma declaration")
    blocks = {}
    for position, header in enumerate(headers):
        name = header[1]
        if name in blocks:
            raise ReplayError(f"duplicate lemma: {name}")
        end = headers[position + 1].start() if position + 1 < len(headers) else endings[0].start()
        blocks[name] = export[header.start():end]
    return export[:headers[0].start()], blocks


def lemma_header(block: str) -> tuple[str, str, str]:
    _, content = lexical_views(block)
    match = re.match(
        r'lemma \w+\s*(?:\[([^\]]*)\])?\s*:\s*'
        r'(all-traces|exists-trace)\s*"([^"]*)"', content,
    )
    if not match:
        raise ReplayError("unsupported canonical lemma header")
    return match[1] or "", match[2], content[match.end():]


def select_certificate(
    export: str, target: str,
    trace_kind: Literal["exists-trace", "all-traces"] = "exists-trace",
    uses: tuple[str, ...] = (),
) -> tuple[str, tuple[str, ...]]:
    prefix, blocks = export_parts(export)
    if target not in blocks:
        raise ReplayError(f"missing target: {target}")
    for name in uses:
        if name not in blocks:
            raise ReplayError(f"missing dependency: {name}")
        if list(blocks).index(name) > list(blocks).index(target):
            raise ReplayError(f"dependency follows target: {name}")
    if lemma_header(blocks[target])[1] != trace_kind:
        raise ReplayError(f"target must be {trace_kind}")
    retained = tuple(
        name for name, block in blocks.items()
        if name == target or name in uses or re.search(r"(?:^|,)\s*sources\s*(?:,|$)", lemma_header(block)[0])
    )
    for name in retained:
        proof = lemma_header(blocks[name])[2]
        if re.search(r"\bsorry\b", proof) or not proof.strip():
            raise ReplayError(f"{name}: incomplete certificate")
    return prefix + "".join(blocks[name] for name in retained) + "end\n", retained


def compare_replay(
    source: str, candidate: str, target: str,
    trace_kind: Literal["exists-trace", "all-traces"] = "exists-trace",
    uses: tuple[str, ...] = (),
) -> tuple[str, ...]:
    expected, retained = select_certificate(source, target, trace_kind, uses)
    expected_prefix, expected_blocks = export_parts(expected)
    actual_prefix, actual_blocks = export_parts(candidate)

    def normalized(text: str) -> str:
        return lexical_views(text)[1].strip()

    if normalized(actual_prefix) != normalized(expected_prefix):
        raise ReplayError("transition-system/signature/restriction mismatch")
    if tuple(actual_blocks) != retained:
        raise ReplayError("retained lemma inventory mismatch")
    for name in retained:
        if normalized(actual_blocks[name]) != normalized(expected_blocks[name]):
            raise ReplayError(f"{name}: formula/attributes/certificate mismatch")
    return retained


def run(command: list[str], timeout: int) -> str:
    process = subprocess.Popen(
        command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        output, errors = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
        raise ReplayError(f"timeout ({timeout}s): {' '.join(command)}") from None
    if process.returncode:
        raise ReplayError(f"command failed ({process.returncode}): {' '.join(command)}\n{output}\n{errors}")
    return output


def check_result(output: str, retained: tuple[str, ...]) -> None:
    for name in retained:
        matches = re.findall(
            rf"^\s*{re.escape(name)} \((?:exists-trace|all-traces)\): (.*)$", output, re.M,
        )
        if len(matches) != 1 or not re.fullmatch(r"verified \(\d+ steps\)", matches[0].strip()):
            raise ReplayError(f"{name}: missing verified replay result")


# Reuse lemmas whose certificates a target proof consumes.
USES = {
    "fresh_dk_origin": ("kem_ciphertext_origin",),
    "extract_origin": ("kem_ciphertext_origin",),
    "encrypted_origin": ("kem_ciphertext_origin",),
    "session_key_origin": ("kem_ciphertext_origin",),
    "ratchet_key_origin": ("kem_ciphertext_origin",),
    "initial_ck_secret": ("kem_ciphertext_origin",),
    "fresh_ss_origin": ("kem_ciphertext_origin",),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=int, default=300, help="proof-run limit in seconds")
    parser.add_argument(
        "--disclosure-sources", action="store_true",
        help="check the opt-in disclosure source-refinement profile, not the full theory",
    )
    parser.add_argument(
        "--target", choices=("lost_data_recovery", "kem_ciphertext_origin", *USES),
        default="lost_data_recovery", help="certificate to replay (default: lost_data_recovery)",
    )
    arguments = parser.parse_args()
    if arguments.timeout <= 0:
        parser.error("--timeout must be positive")
    here = Path(__file__).resolve().parent
    target = arguments.target
    uses = USES.get(target, ())
    trace_kind: Literal["exists-trace", "all-traces"] = (
        "exists-trace" if target == "lost_data_recovery" else "all-traces"
    )
    try:
        version = run(["tamarin-prover", "--version"], 30)
        if not re.search(r"\btamarin-prover 1\.12\.0,", version) or not re.search(
            r"^Maude version 3\.5\.1\s*$", version, re.M,
        ):
            raise ReplayError("expected Tamarin 1.12.0 and Maude 3.5.1")
        with tempfile.TemporaryDirectory(prefix="pqcble-witness-") as temporary:
            build = Path(temporary)
            exported = build / "assembled.spthy"
            run([
                "tamarin-prover", str(here / "ratchet.spthy"),
                "--quit-on-warning", "--derivcheck-timeout=60", "--output-module=msr",
                f"--output={exported}",
                *(["--defines=DISCLOSURE_SOURCES"] if arguments.disclosure_sources else []),
            ], 120)
            source = exported.read_text()
            selected, retained = select_certificate(source, target, trace_kind, uses)
            theory = build / "ratchet-witness.spthy"
            theory.write_text(selected)
            roundtrip = build / "roundtrip.spthy"
            run([
                "tamarin-prover", str(theory), "--quit-on-warning", "--derivcheck-timeout=60",
                "--output-module=msr", f"--output={roundtrip}",
            ], 120)
            canonical = roundtrip.read_text()
            compare_replay(source, canonical, target, trace_kind, uses)
            prefix, _ = export_parts(canonical)
            declarations = lexical_views(prefix)[0]
            rules = len(re.findall(r"^rule\b", declarations, re.M))
            restrictions = len(re.findall(r"^restriction\b", declarations, re.M))
            print(f"Source SHA-256: {hashlib.sha256(source.encode()).hexdigest()}", flush=True)
            print(f"Replay SHA-256: {hashlib.sha256(canonical.encode()).hexdigest()}", flush=True)
            print(
                f"Retained lemmas: {', '.join(retained)}; "
                f"{rules} rules, {restrictions} restrictions; all non-lemma declarations identical",
                flush=True,
            )
            output = run([
                "tamarin-prover", str(theory), "--quit-on-warning", "--derivcheck-timeout=60",
            ], arguments.timeout)
            check_result(output, retained)
            summary = output[output.rfind("summary of summaries:"):]
            print(summary.strip())
        return 0
    except (OSError, ReplayError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
