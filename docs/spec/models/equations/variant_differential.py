"""Differential check of Lean variant schemes against native Maude variants.

Lean family F: each exported scheme value under every native AC unifier of its
`nativeVariantSystem`. Maude family G: `get variants`. Every G tuple must be an
AC instance of some F tuple, every normalized F tuple an AC instance of some G
tuple, and every F value must normalize like the unifier's term instance.
"""

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import re
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from equations.maude_module import reviewed_module
from equations.maude_native import select_proxy


# ("var", name, sort) or ("app", symbol, arguments)
Term = tuple
Equation = tuple[Term, Term]
Substitution = dict[str, Term]

PREAMBLE = "set show command off .\nset show timing off .\nset show stats off .\n"
SETUP_PROMPTS = 5
PROMPT = "Maude> "
CONJUNCTION = " /\\ "
PATTERN_BASE = 1000
SUBJECT_BASE = 5000
TOKEN = re.compile(r"\s*([A-Za-z0-9#%_]+|[(),:])")


@dataclass(frozen=True)
class Case:
    term: Term
    variables: tuple[Term, ...]
    schemes: tuple[tuple[Term, tuple[Equation, ...]], ...]


@dataclass(frozen=True)
class Report:
    lean: int
    maude: int
    failures: tuple[str, ...]


def parse_term(text: str) -> Term:
    tokens = TOKEN.findall(text)
    if "".join(tokens) != re.sub(r"\s+", "", text):
        raise ValueError(f"unexpected term syntax: {text!r}")
    term, position = _parse(tokens, 0)
    if position != len(tokens):
        raise ValueError(f"trailing term syntax: {text!r}")
    return term


def _parse(tokens: list[str], position: int) -> tuple[Term, int]:
    if position >= len(tokens) or tokens[position] in "(),:":
        raise ValueError("expected a symbol")
    symbol = tokens[position]
    position += 1
    if position < len(tokens) and tokens[position] == ":":
        if position + 1 >= len(tokens) or not tokens[position + 1].isalpha():
            raise ValueError("expected a variable sort")
        return ("var", symbol, tokens[position + 1]), position + 2
    if position < len(tokens) and tokens[position] == "(":
        arguments = []
        while True:
            argument, position = _parse(tokens, position + 1)
            arguments.append(argument)
            if position >= len(tokens) or tokens[position] not in ",)":
                raise ValueError("expected ',' or ')'")
            if tokens[position] == ")":
                return ("app", symbol, tuple(arguments)), position + 1
    return ("app", symbol, ()), position


def render(term: Term) -> str:
    if term[0] == "var":
        return f"{term[1]}:{term[2]}"
    if not term[2]:
        return term[1]
    return f"{term[1]}({','.join(render(argument) for argument in term[2])})"


def variable_key(term: Term) -> str:
    return render(term)


def variables(term: Term) -> list[Term]:
    if term[0] == "var":
        return [term]
    found = []
    for argument in term[2]:
        for variable in variables(argument):
            if variable not in found:
                found.append(variable)
    return found


def substitute(term: Term, substitution: Substitution) -> Term:
    if term[0] == "var":
        return substitution.get(variable_key(term), term)
    return ("app", term[1], tuple(substitute(argument, substitution) for argument in term[2]))


def rename_apart(term: Term, base: int) -> Term:
    renaming = {
        variable_key(variable): ("var", f"x{base + index}", variable[2])
        for index, variable in enumerate(variables(term))
    }
    return substitute(term, renaming)


def tuple_term(head: Term, rest: list[Term]) -> Term:
    tail: Term = ("app", "nil", ())
    for item in reversed([head, *rest]):
        tail = ("app", "cons", (item, tail))
    return tail


def split_replies(output: str, count: int) -> list[str]:
    parts = output.split(PROMPT)
    if len(parts) != SETUP_PROMPTS + count + 1:
        raise ValueError(f"expected {count} native replies, got {len(parts) - SETUP_PROMPTS - 1}")
    if any(part.strip() for part in (*parts[:SETUP_PROMPTS], parts[-1])):
        raise ValueError("unexpected native output outside replies")
    return [part.strip() for part in parts[SETUP_PROMPTS:-1]]


def parse_blocks(reply: str, header: str) -> list[tuple[Term | None, Substitution]]:
    if reply in ("No unifier.", "No match."):
        return []
    blocks: list[tuple[Term | None, Substitution]] = []
    value: Term | None = None
    bindings: Substitution = {}
    started = False
    for line in reply.splitlines():
        line = line.strip()
        if re.fullmatch(rf"{header} \d+", line):
            if started:
                blocks.append((value, bindings))
            value, bindings, started = None, {}, True
        elif not line or re.fullmatch(r"rewrites: \d+", line):
            continue
        elif line == "No more variants." and header == "Variant":
            if started:
                blocks.append((value, bindings))
            return blocks
        elif not started:
            raise ValueError(f"unexpected native reply line: {line!r}")
        elif " --> " in line:
            left, right = line.split(" --> ", 1)
            bindings[variable_key(parse_term(left))] = parse_term(right)
        elif line == "empty substitution":
            continue
        elif header == "Variant" and value is None and (match := re.fullmatch(r"\[?\w+\]?: (.+)", line)):
            value = parse_term(match[1])
        else:
            raise ValueError(f"unexpected native reply line: {line!r}")
    if header == "Variant":
        raise ValueError("native variant reply is incomplete")
    if started:
        blocks.append((value, bindings))
    return blocks


def parse_export(text: str) -> list[Case]:
    cases: list[Case] = []
    term: Term | None = None
    names: tuple[Term, ...] = ()
    schemes: list[tuple[Term, list[Equation]]] = []

    def close() -> None:
        if term is not None:
            cases.append(Case(term, names, tuple((value, tuple(system)) for value, system in schemes)))

    for line in text.splitlines():
        if not line.strip():
            continue
        keyword, _, rest = line.partition(" ")
        if keyword == "CASE":
            close()
            term, names, schemes = parse_term(rest), (), []
        elif keyword == "VARS" and term is not None:
            names = tuple(parse_term(name) for name in rest.split())
        elif keyword == "SCHEME" and term is not None:
            schemes.append((parse_term(rest), []))
        elif keyword == "EQUATION" and schemes:
            left, separator, right = rest.partition(" =? ")
            if not separator:
                raise ValueError(f"malformed exported equation: {line!r}")
            schemes[-1][1].append((parse_term(left), parse_term(right)))
        else:
            raise ValueError(f"unexpected export line: {line!r}")
    close()
    return cases


class NativeSession:
    def __enter__(self) -> "NativeSession":
        self.proxy = str(select_proxy()[0])
        self.module = PREAMBLE + reviewed_module()
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def run(self, commands: list[str]) -> list[str]:
        if not commands:
            return []
        result = subprocess.run(
            [self.proxy, "-interactive", "-no-tecla", "-no-banner", "-no-wrap", "-batch"],
            input=self.module + "".join(f"{command} .\n" for command in commands),
            text=True, capture_output=True, env=dict(os.environ), timeout=600,
        )
        if result.returncode or result.stderr:
            raise RuntimeError(f"native proxy failed ({result.returncode}): {result.stderr.strip()}")
        return split_replies(result.stdout, len(commands))

    def matches(self, pairs: list[tuple[Term, Term]]) -> list[bool]:
        replies = self.run([
            f"match in MSG : {render(rename_apart(pattern, PATTERN_BASE))} <=? "
            f"{render(rename_apart(subject, SUBJECT_BASE))}"
            for pattern, subject in pairs
        ])
        return [bool(parse_blocks(reply, "Matcher")) for reply in replies]

    def reduce(self, terms: list[Term]) -> list[Term]:
        results = []
        for reply in self.run([f"reduce {render(rename_apart(term, PATTERN_BASE))}" for term in terms]):
            match = re.fullmatch(r"result \[?\w+\]?: (.+)", reply)
            if match is None:
                raise ValueError(f"unexpected native reduce reply: {reply!r}")
            results.append(parse_term(match[1]))
        return results


def covered(session: NativeSession, patterns: list[Term], subjects: list[Term]) -> list[bool]:
    pairs = [(pattern, subject) for subject in subjects for pattern in patterns]
    found = iter(session.matches(pairs))
    return [any([next(found) for _ in patterns]) for _ in subjects]


def check_case(case: Case, session: NativeSession) -> Report:
    replies = session.run([
        f"get variants in MSG : {render(case.term)}",
        *(f"unify in MSG : {CONJUNCTION.join(f'{render(left)} =? {render(right)}' for left, right in system)}"
          for _, system in case.schemes),
    ])
    native = [
        tuple_term(value, [substitute(variable, bindings) for variable in case.variables])
        for value, bindings in parse_blocks(replies[0], "Variant")
        if value is not None
    ]
    lean: list[Term] = []
    instances: list[Term] = []
    for (value, _), reply in zip(case.schemes, replies[1:]):
        for _, unifier in parse_blocks(reply, "Unifier"):
            lean.append(tuple_term(
                substitute(value, unifier),
                [substitute(variable, unifier) for variable in case.variables],
            ))
            instances.append(tuple_term(substitute(case.term, unifier), [substitute(value, unifier)]))
    failures = []
    for index, pair in enumerate(session.reduce(instances), 1):
        if pair[2][0] != pair[2][1][2][0]:
            failures.append(f"Lean variant {index} does not normalize like its term instance")
    for index, found in enumerate(covered(session, lean, native), 1):
        if not found:
            failures.append(f"native variant {index} is not an instance of any Lean variant")
    for index, found in enumerate(covered(session, native, session.reduce(lean)), 1):
        if not found:
            failures.append(f"Lean variant {index} is not an instance of any native variant")
    return Report(len(lean), len(native), tuple(failures))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export", required=True, type=Path, help="QueryVariantExport output")
    arguments = parser.parse_args()
    try:
        cases = parse_export(arguments.export.read_text())
        if not cases:
            raise ValueError("empty Lean variant export")
        failed = False
        with NativeSession() as session:
            for case in cases:
                report = check_case(case, session)
                if not report.lean or not report.maude:
                    report = Report(report.lean, report.maude, (*report.failures, "empty variant family"))
                status = "FAIL" if report.failures else "ok"
                print(f"{status}: {render(case.term)}: Lean {report.lean}, native {report.maude}")
                for failure in report.failures:
                    print(f"  {failure}")
                failed |= bool(report.failures)
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    if failed:
        print("FAIL: Lean variant schemes and native Maude variants differ.", file=sys.stderr)
        return 1
    print(f"PASS: Lean variant schemes and native Maude variants cover each other on {len(cases)} queries.")
    print("Scope: differential corpus evidence via native AC unify/match/reduce; not a proof of Maude.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
