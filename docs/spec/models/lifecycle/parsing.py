"""Parser for the deliberately restricted canonical fact-list syntax."""

import re


class ProjectionError(ValueError):
    pass


def strip_comments(text: str) -> str:
    result, index, quoted = [], 0, False
    while index < len(text):
        char = text[index]
        if char == "'":
            quoted = not quoted
        if not quoted and text.startswith("//", index):
            end = text.find("\n", index)
            index = len(text) if end == -1 else end
            result.append(" ")
            continue
        if not quoted and text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end == -1:
                raise ProjectionError("unterminated comment")
            result.append(" ")
            index = end + 2
            continue
        result.append(char)
        index += 1
    if quoted:
        raise ProjectionError("unterminated literal")
    return "".join(result)


def split_terms(text: str) -> list[str]:
    result, start, stack, quoted = [], 0, [], False
    matching = {")": "(", "]": "[", ">": "<"}
    for index, char in enumerate(text):
        if char == "'":
            quoted = not quoted
        elif not quoted:
            if char in "([<":
                stack.append(char)
            elif char in ")]>":
                if not stack or stack.pop() != matching[char]:
                    raise ProjectionError("unbalanced fact/term")
            elif char == "," and not stack:
                term = text[start:index].strip()
                if not term:
                    raise ProjectionError("empty term")
                result.append(term)
                start = index + 1
    if stack or quoted:
        raise ProjectionError("unterminated fact/term")
    tail = text[start:].strip()
    if tail:
        result.append(tail)
    elif result:
        raise ProjectionError("empty term")
    return result


def delimited(text: str, start: int, opening: str, closing: str) -> tuple[str, int]:
    if start >= len(text) or text[start] != opening:
        raise ProjectionError("expected fact list or call")
    depth, quoted = 0, False
    for index in range(start, len(text)):
        char = text[index]
        if char == "'":
            quoted = not quoted
        elif not quoted:
            if char == opening:
                depth += 1
            elif char == closing:
                depth -= 1
                if depth == 0:
                    return text[start + 1:index], index + 1
    raise ProjectionError("unterminated fact list or call")


def fact_list(text: str, start: int) -> tuple[list[str], int]:
    content, end = delimited(text, start, "[", "]")
    return split_terms(content), end


def parse_fact(text: str) -> tuple[str, list[str], bool]:
    match = re.match(r"(!?)([A-Za-z][A-Za-z0-9_]*)\s*(?=\()", text)
    if not match:
        raise ProjectionError(f"unsupported fact: {text[:80]}")
    arguments, end = delimited(text, match.end(), "(", ")")
    suffix = text[end:].strip()
    if suffix and not re.fullmatch(r"\[(?:no_precomp|\+|-)(?:,\s*(?:no_precomp|\+|-))*\]", suffix):
        raise ProjectionError(f"unsupported fact suffix: {suffix[:80]}")
    return match[2], [re.sub(r"\s+", "", arg) for arg in split_terms(arguments)], bool(match[1])
