"""Pinned native module correspondence to the reviewed source inventory."""

import re

from equations.signature import EQUATION_PROOFS, FUNCTIONS


def native_equation(equation: str) -> str:
    text = re.sub(r"<([^<>]+)>", r"pair(\1)", equation)
    variables: dict[str, str] = {}

    def identifier(match: re.Match[str]) -> str:
        name = match[0]
        if name in FUNCTIONS:
            return f"tamXC{name}"
        if name not in variables:
            variables[name] = f"x{len(variables)}:Msg"
        return variables[name]

    left, right = re.sub(r"[A-Za-z][A-Za-z0-9_]*(?:\.[0-9]+)?", identifier, text).split("=")
    return f"eq {left} = {right} [variant] ."


def reviewed_module() -> str:
    expected = [
        "fmod MSG is", "protecting NAT .", "sort Pub Fresh Msg Node TamNat TOP .",
        "subsort Pub < Msg .", "subsort Fresh < Msg .", "subsort TamNat < Msg .",
        "subsort Msg < TOP .", "subsort Node < TOP .",
        "op f : Nat -> Fresh .", "op p : Nat -> Pub .", "op c : Nat -> Msg .",
        "op n : Nat -> Node .", "op t : Nat -> TamNat .",
        "op list : TOP -> TOP .", "op cons : TOP TOP -> TOP .", "op nil : -> TOP .",
        "op tamXCtone : -> TamNat .", "op tamtplus : TamNat TamNat -> TamNat [comm assoc] .",
    ]
    expected.extend(
        f"op tamXC{name} : {'Msg ' * FUNCTIONS[name][0]}-> Msg ." for name in sorted(FUNCTIONS)
    )
    expected.extend(sorted(native_equation(equation) for equation in EQUATION_PROOFS))
    expected.append("endfm")
    return "\n".join(expected) + "\n"
