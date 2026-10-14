"""Typed image validation for the pinned Tamarin/Maude command boundary."""

from dataclasses import dataclass
import re

from equations.signature import FUNCTIONS
from replay import ReplayError


class BoundaryError(ReplayError):
    """A native operation escaped the checked structural image."""


SORTS = frozenset({"Pub", "Fresh", "Msg", "TamNat", "Node", "TOP"})
MESSAGE_SORTS = frozenset({"Pub", "Fresh", "Msg", "TamNat"})
ATOM_SORTS = {"p": "Pub", "f": "Fresh", "c": "Msg", "t": "TamNat", "n": "Node"}
TOKEN = re.compile(r"\s+|[x#%][0-9]+:[A-Za-z][A-Za-z0-9]*|[A-Za-z][A-Za-z0-9]*|[0-9]+|[(),]")
DECIMAL = re.compile(r"(?:0|[1-9][0-9]*)")


@dataclass(frozen=True)
class TermImage:
    sort: str
    variables: frozenset[str]
    atoms: frozenset[tuple[str, str]]


@dataclass(frozen=True)
class QueryImage:
    kind: str
    terms: tuple[TermImage, ...]


def parse_native_term(text: str, *, query: bool = False) -> TermImage:
    """Recognize the free framing image without a recursion-depth ceiling."""
    if not text.isascii():
        raise BoundaryError("native term: non-ASCII syntax")
    tokens = []
    end = 0
    for match in TOKEN.finditer(text):
        if match.start() != end:
            raise BoundaryError("native term: unsupported token")
        end = match.end()
        if not match[0].isspace():
            tokens.append(match[0])
    if end != len(text) or not tokens:
        raise BoundaryError("native term: malformed syntax")
    position = 0
    frames: list[tuple[str, list[tuple[str, str | None]]]] = []
    variables: set[str] = set()
    atoms: set[tuple[str, str]] = set()
    result: tuple[str, str | None] | None = None
    expecting = True

    def application(name: str, arguments: list[tuple[str, str | None]]) -> tuple[str, str | None]:
        sorts = [sort for sort, _ in arguments]
        if name in ATOM_SORTS:
            if len(arguments) != 1 or sorts != ["decimal"]:
                raise BoundaryError("native atom: index is not a closed decimal")
            index = arguments[0][1]
            if index is None:
                raise BoundaryError("native atom: missing index")
            atoms.add((name, index))
            return ATOM_SORTS[name], None
        if name == "nil" and not arguments:
            return "TOP", None
        if name in {"list", "cons"} and len(arguments) == {"list": 1, "cons": 2}[name]:
            if not all(sort in SORTS for sort in sorts):
                raise BoundaryError("native framing: invalid child sort")
            return "TOP", None
        if name == "tamXCtone" and not arguments:
            return "TamNat", None
        if name == "tamtplus" and len(arguments) >= 2:
            if any(sort != "TamNat" for sort in sorts):
                raise BoundaryError("native natural sum: non-natural operand")
            return "TamNat", None
        if name.startswith("tamXC") and name[5:] in FUNCTIONS:
            arity = FUNCTIONS[name[5:]][0]
            if len(arguments) != arity:
                raise BoundaryError("native message function: wrong arity")
            if any(sort not in MESSAGE_SORTS for sort in sorts):
                raise BoundaryError("native message function: invalid operand sort")
            return "Msg", None
        raise BoundaryError("native term: unreviewed constructor or arity")

    while True:
        if expecting:
            if position >= len(tokens):
                raise BoundaryError("native term: truncated argument")
            token = tokens[position]
            position += 1
            if ":" in token:
                identifier, sort = token.split(":")
                if sort not in SORTS - {"TOP"} or not DECIMAL.fullmatch(identifier[1:]):
                    raise BoundaryError("native variable: unsupported sort or index")
                if query and identifier[0] != "x":
                    raise BoundaryError("native query: unexpected fresh-variable namespace")
                variables.add(token)
                result = sort, None
            elif DECIMAL.fullmatch(token):
                result = "decimal", token
            elif token[0].isalpha():
                if position < len(tokens) and tokens[position] == "(":
                    position += 1
                    frames.append((token, []))
                    continue
                result = application(token, [])
            else:
                raise BoundaryError("native term: expected constructor")
            expecting = False
        if result is None:
            raise BoundaryError("native term: missing result")
        if not frames:
            if position != len(tokens) or result[0] not in SORTS:
                raise BoundaryError("native term: trailing syntax or unsupported root sort")
            return TermImage(result[0], frozenset(variables), frozenset(atoms))
        name, arguments = frames[-1]
        arguments.append(result)
        if position >= len(tokens):
            raise BoundaryError("native term: unclosed application")
        delimiter = tokens[position]
        position += 1
        if delimiter == ",":
            expecting = True
            continue
        if delimiter != ")":
            raise BoundaryError("native term: malformed argument separator")
        frames.pop()
        result = application(name, arguments)


def validate_query(command: str) -> QueryImage:
    """Validate a whole native operation, never select a subset of its terms."""
    if not command.isascii():
        raise BoundaryError("native query: non-ASCII syntax")
    match = re.fullmatch(r"\s*(get variants in MSG|unify in MSG|match in MSG)\s*:\s*(.*?)\s*\.\s*",
                         command, re.S)
    if match is None:
        match = re.fullmatch(r"\s*(reduce)\s+(.*?)\s*\.\s*", command, re.S)
    if match is None:
        raise BoundaryError("native query: unsupported command")
    kind, body = match.groups()
    kind = {"get variants in MSG": "variants", "unify in MSG": "unify",
            "match in MSG": "match", "reduce": "reduce"}[kind]
    terms = []
    if kind in {"reduce", "variants"}:
        terms.append(parse_native_term(body, query=True))
    else:
        equations = body.split("/\\") if kind == "unify" else [body]
        separator = "=?" if kind == "unify" else "<=?"
        for equation in equations:
            sides = equation.split(separator)
            if len(sides) != 2:
                raise BoundaryError("native query: malformed equation")
            terms.extend(parse_native_term(side.strip(), query=True) for side in sides)
    return QueryImage(kind, tuple(terms))


def sort_below(actual: str, expected: str) -> bool:
    return actual == expected or expected == "TOP" and actual in SORTS or (
        expected == "Msg" and actual in MESSAGE_SORTS
    )


def validate_reply(query: QueryImage, reply: str) -> None:
    """Require complete reply syntax and image membership of every solution."""
    if not reply.isascii():
        raise BoundaryError("native reply: non-ASCII syntax")
    lines = [line.strip() for line in reply.splitlines() if line.strip()]
    variables = frozenset(variable for term in query.terms for variable in term.variables)
    atoms = frozenset(atom for term in query.terms for atom in term.atoms)
    fresh_names: dict[str, str] = {}

    def value(text: str, expected: str, *, upper: str | None = None, binding: bool = False) -> None:
        term = parse_native_term(text)
        if not sort_below(term.sort, expected) or upper is not None and not sort_below(term.sort, upper):
            if binding:
                raise BoundaryError("native binding: incompatible sort")
            raise BoundaryError("native reply: incompatible result sort")
        if not term.atoms <= atoms:
            raise BoundaryError("native reply: new rigid atom index")
        if any(variable.startswith("x") and variable not in variables for variable in term.variables):
            raise BoundaryError("native reply: unbound original variable")
        for variable in term.variables:
            prefix = variable[0]
            if (prefix == "x") != (query.kind in {"reduce", "match"}):
                raise BoundaryError("native reply: incompatible variable namespace")
            if prefix != "x":
                key = variable[1:]
                previous = fresh_names.setdefault(key, prefix)
                if previous != prefix:
                    raise BoundaryError("native reply: ambiguous generated variable namespace")

    if query.kind == "reduce":
        match = re.fullmatch(r"result (Pub|Fresh|Msg|TamNat|Node|TOP): (.+)", lines[0]) if lines else None
        if len(lines) != 1 or match is None:
            raise BoundaryError("native reply: malformed reduction result")
        reported, text = match.groups()
        value(text, reported, upper=query.terms[0].sort)
        return
    if lines == [{"unify": "No unifier.", "match": "No match."}.get(query.kind)]:
        return
    if query.kind == "variants":
        if len(lines) < 2 or lines[-2] != "No more variants." or not re.fullmatch(
            r"rewrites: [0-9]+", lines[-1],
        ):
            raise BoundaryError("native reply: missing variant exhaustion")
        lines = lines[:-2]
    position = 0
    count = 0
    header = "Variant" if query.kind == "variants" else {"unify": "Unifier", "match": "Matcher"}[query.kind]
    while position < len(lines):
        fresh_names.clear()
        count += 1
        if not re.fullmatch(rf"{header} #?{count}", lines[position]):
            raise BoundaryError("native reply: missing or malformed solution header")
        position += 1
        if query.kind == "variants":
            if position >= len(lines) or not re.fullmatch(r"rewrites: [0-9]+", lines[position]):
                raise BoundaryError("native reply: missing variant metadata")
            position += 1
            match = re.fullmatch(r"(Pub|Fresh|Msg|TamNat|Node|TOP): (.+)", lines[position]) if position < len(lines) else None
            if match is None:
                raise BoundaryError("native reply: missing variant term")
            value(match[2], match[1], upper=query.terms[0].sort)
            position += 1
        bindings: set[str] = set()
        if position < len(lines) and lines[position] == "empty substitution":
            if query.kind == "variants":
                raise BoundaryError("native reply: unsupported variant substitution marker")
            position += 1
        else:
            while position < len(lines) and " --> " in lines[position]:
                match = re.fullmatch(r"(x[0-9]+:(?:Pub|Fresh|Msg|TamNat|Node)) --> (.+)", lines[position])
                if match is None or match[1] not in variables or match[1] in bindings:
                    raise BoundaryError("native reply: unknown or duplicate binding")
                value(match[2], match[1].split(":")[1], binding=True)
                bindings.add(match[1])
                position += 1
            if not bindings and query.kind != "variants":
                raise BoundaryError("native reply: missing substitution")
    if not count:
        raise BoundaryError("native reply: missing solutions")
