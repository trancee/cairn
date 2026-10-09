"""Replay guard mutations against the assembled native transition systems."""

import argparse
import hashlib
from pathlib import Path
import re
import sys
import tempfile

from replay import ReplayError, export_parts, lexical_views, run


TARGETS = {
    "CLASSIC_FALLBACK": "no_classical_downgrade",
    "NO_PREFIX_GUARD": "no_partial_mix",
}
OPTIONS = [
    "--quit-on-warning", "--derivcheck-timeout=60",
    "--open-chains=0", "--saturation=0",
]


def check_toolchain() -> None:
    version = run(["tamarin-prover", "--version"], 30)
    if not re.search(r"\btamarin-prover 1\.12\.0,", version) or not re.search(
        r"^Maude version 3\.5\.1\s*$", version, re.M,
    ):
        raise ReplayError("expected Tamarin 1.12.0 and Maude 3.5.1")


def declaration_header(block: str) -> str:
    content = lexical_views(block)[1]
    match = re.match(r'lemma \w+\s*(?:\[[^\]]*\])?\s*:\s*all-traces\s*"[^"]*"', content)
    if not match:
        raise ReplayError("expected all-traces target formula and attributes")
    return match[0].strip()


def check_transition_difference(default: str, mutant: str) -> None:
    masked = lexical_views(default)[0]
    declarations = list(re.finditer(
        r"^(?:restriction|rule|builtins|functions|equations|tactic)\b", masked, re.M,
    ))
    guards = [
        index for index, entry in enumerate(declarations)
        if re.match(r"restriction mandatory_mix\b", masked[entry.start():])
    ]
    if len(guards) != 1:
        raise ReplayError("expected exactly one default mandatory_mix restriction")
    position = guards[0]
    start = declarations[position].start()
    end = declarations[position + 1].start() if position + 1 < len(declarations) else len(default)
    without_guard = default[:start] + default[end:]
    if lexical_views(without_guard)[1].strip() != lexical_views(mutant)[1].strip():
        raise ReplayError("CLASSIC_FALLBACK must remove only mandatory_mix")


def canonical_tokens(text: str) -> tuple[str, ...]:
    return tuple(re.findall(r"""'[^']*'|"[^"]*"|\S""", lexical_views(text)[1]))


def check_prefix_difference(default: str, mutant: str) -> None:
    masked = lexical_views(mutant)[0]
    headers = list(re.finditer(r"^rule \(modulo E\) (\w+):", masked, re.M))
    rules = {}
    for index, header in enumerate(headers):
        if header[1] in rules:
            raise ReplayError(f"duplicate rule: {header[1]}")
        end = headers[index + 1].start() if index + 1 < len(headers) else len(mutant)
        rules[header[1]] = (header.start(), end)
    removed = []
    for kind in ("EK", "CT"):
        guarded = f"Receive_{kind}_tail"
        unguarded = guarded + "_unguarded"
        if guarded not in rules or unguarded not in rules:
            raise ReplayError(f"missing guarded/unguarded {kind} tail rule")
        start, end = rules[guarded]
        expected = lexical_views(mutant[start:end])[1]
        premise = rf"!{kind}0\(\s*pid,\s*r,\s*%e,\s*{kind.lower()}\s*\),\s*"
        expected, count = re.subn(premise, "", expected)
        if count != 1:
            raise ReplayError(f"{guarded}: expected exactly one stored-prefix premise")
        expected = expected.replace(guarded, unguarded)
        start, end = rules[unguarded]
        if canonical_tokens(expected) != canonical_tokens(mutant[start:end]):
            raise ReplayError(f"{unguarded}: change beyond removed prefix premise")
        removed.append((start, end))
    retained = mutant
    for start, end in sorted(removed, reverse=True):
        retained = retained[:start] + retained[end:]
    if canonical_tokens(retained) != canonical_tokens(default):
        raise ReplayError("NO_PREFIX_GUARD must add only the two unguarded tail rules")


def check_outcome(output: str, expected: str, target: str) -> None:
    outcomes = re.findall(
        rf"^\s*{target} \(all-traces\): (.*)$", output, re.M,
    )
    pattern = (
        r"verified \(\d+ steps\)" if expected == "verified"
        else r"falsified - found trace \(\d+ steps\)"
    )
    if len(outcomes) != 1 or not re.fullmatch(pattern, outcomes[0].strip()):
        raise ReplayError(f"{target}: expected {expected}, observed {outcomes}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=int, default=180, help="limit for each native command")
    parser.add_argument("--mutation", choices=tuple(TARGETS), default="CLASSIC_FALLBACK")
    arguments = parser.parse_args()
    if arguments.timeout <= 0:
        parser.error("--timeout must be positive")
    here = Path(__file__).resolve().parent
    target = TARGETS[arguments.mutation]
    try:
        check_toolchain()
        with tempfile.TemporaryDirectory(prefix="cairn-mutation-") as temporary:
            build = Path(temporary)
            profiles = []
            for name, definitions in (
                ("default", []), (arguments.mutation, [f"--defines={arguments.mutation}"]),
            ):
                exported = build / f"{name}.spthy"
                run([
                    "tamarin-prover", str(here / "ratchet.spthy"), *OPTIONS, *definitions,
                    "--output-module=msr", f"--output={exported}",
                ], arguments.timeout)
                source = exported.read_text()
                prefix, blocks = export_parts(source)
                if target not in blocks:
                    raise ReplayError(f"{name}: missing {target}")
                profiles.append((name, source, prefix, blocks[target]))
            if arguments.mutation == "CLASSIC_FALLBACK":
                check_transition_difference(profiles[0][2], profiles[1][2])
            else:
                check_prefix_difference(profiles[0][2], profiles[1][2])
            if declaration_header(profiles[0][3]) != declaration_header(profiles[1][3]):
                raise ReplayError("mutation changed target formula or attributes")
            for name, source, prefix, certificate in profiles:
                theory = build / f"{name}-certificate.spthy"
                theory.write_text(prefix + certificate + "end\n")
                print(
                    f"{name}: source SHA-256 {hashlib.sha256(source.encode()).hexdigest()}; "
                    f"transition SHA-256 {hashlib.sha256(prefix.encode()).hexdigest()}; "
                    "all non-lemma declarations retained; no helper lemmas",
                    flush=True,
                )
                output = run(["tamarin-prover", str(theory), *OPTIONS], arguments.timeout)
                check_outcome(output, "verified" if name == "default" else "falsified", target)
                print(output[output.rfind("summary of summaries:"):].strip(), flush=True)
        return 0
    except (OSError, ReplayError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
