"""Reviewed canonical equation-to-kernel correspondence."""

import re

from lifecycle.parsing import ProjectionError, split_terms
from replay import ReplayError, lexical_views


EQUATION_PROOFS = {
    "flip(roleA)=roleB": "flipA",
    "flip(roleB)=roleA": "flipB",
    "fst(<x.1,x.2>)=x.1": "fst",
    "snd(<x.1,x.2>)=x.2": "snd",
    "kdec(kem(ss,pk(dk)),dk)=ss": "kdec",
    "sdec(senc(x.1,x.2),x.2)=x.1": "sdec",
}
EQUATIONS = frozenset(EQUATION_PROOFS)
FUNCTIONS = {
    "ext": (2, "binary .ext"),
    "flip": (1, "unary .flip"),
    "fst": (1, "unary .fst"),
    "h": (1, "unary .hash"),
    "kdec": (2, "binary .kdec"),
    "kdf": (3, "kdf"),
    "kem": (2, "binary .kem"),
    "mac": (2, "binary .mac"),
    "pair": (2, "binary .pair"),
    "pk": (1, "unary .pk"),
    "roleA": (0, "roleA"),
    "roleB": (0, "roleB"),
    "sdec": (2, "binary .sdec"),
    "senc": (2, "binary .senc"),
    "snd": (1, "unary .snd"),
}


def reviewed_signature(source: str) -> tuple[str, ...]:
    content, _ = lexical_views(source)
    if re.findall(r"^builtins:[^\n]*", content, re.M) != ["builtins: natural-numbers"]:
        raise ReplayError("unreviewed builtin theory")
    declarations = re.findall(
        r"^equations:\s*(.*?)\n\s*tactic:", content, re.M | re.S,
    )
    if len(declarations) != 1:
        raise ReplayError("missing or duplicate canonical equations")
    signature = re.findall(r"^functions:\s*(.*?)\n\s*equations:", content, re.M | re.S)
    if len(signature) != 1:
        raise ReplayError("missing or duplicate function signature")
    ranks = [
        re.fullmatch(r"\s*([A-Za-z][A-Za-z0-9_]*)/([0-3])\s*", rank)
        for rank in signature[0].split(",")
    ]
    if any(rank is None for rank in ranks):
        raise ReplayError("unsupported function signature")
    declared = [(rank[1], int(rank[2])) for rank in ranks if rank is not None]
    if len(declared) != len(FUNCTIONS) or dict(declared) != {
        name: arity for name, (arity, _) in FUNCTIONS.items()
    }:
        raise ReplayError("unreviewed function signature")
    try:
        equations = tuple(re.sub(r"\s+", "", equation) for equation in split_terms(declarations[0]))
    except ProjectionError as error:
        raise ReplayError("malformed canonical equations") from error
    if len(equations) != len(EQUATIONS) or set(equations) != EQUATIONS:
        raise ReplayError("unreviewed equational theory")
    return equations


def lean_term(text: str) -> tuple[str, set[str]]:
    tokens = re.findall(r"[A-Za-z][A-Za-z0-9_]*(?:\.\d+)?|[<>(),]", text)
    if "".join(tokens) != text:
        raise ReplayError("unsupported equation term")
    position = 0
    variables: set[str] = set()

    def take(expected: str) -> None:
        nonlocal position
        if position >= len(tokens) or tokens[position] != expected:
            raise ReplayError("malformed equation term")
        position += 1

    def term() -> str:
        nonlocal position
        if position >= len(tokens):
            raise ReplayError("truncated equation term")
        name = tokens[position]
        position += 1
        if name == "<":
            left = term()
            take(",")
            right = term()
            take(">")
            return f"(.binary .pair {left} {right})"
        if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(?:\.\d+)?", name):
            raise ReplayError("malformed equation term")
        if name not in FUNCTIONS:
            variable = name.replace(".", "_")
            variables.add(variable)
            return variable
        arity, constructor = FUNCTIONS[name]
        if not arity:
            return f".{constructor}"
        take("(")
        arguments = [term()]
        for _ in range(arity - 1):
            take(",")
            arguments.append(term())
        take(")")
        return f"(.{constructor} {' '.join(arguments)})"

    translated = term()
    if position != len(tokens):
        raise ReplayError("unexpected equation term suffix")
    return translated, variables


def lean_correspondence(equations: tuple[str, ...]) -> str:
    if len(equations) != len(EQUATIONS) or set(equations) != EQUATIONS:
        raise ReplayError("unreviewed equational theory")
    rows = ["import Termination", "open Cairn.Equations"]
    for equation in equations:
        left, right = equation.split("=")
        left_term, left_variables = lean_term(left)
        right_term, right_variables = lean_term(right)
        variables = sorted(left_variables | right_variables)
        binders = f"({' '.join(variables)} : MessageTerm)" if variables else ""
        rows.append(
            f"example {binders} : PrimitiveRewrite {left_term} {right_term} := "
            f".{EQUATION_PROOFS[equation]}"
        )
    return "\n".join(rows) + "\n"
