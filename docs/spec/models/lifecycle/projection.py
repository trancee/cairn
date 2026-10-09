"""Fail-closed projection of Tamarin's canonical default-rule export."""

from collections import Counter
from dataclasses import dataclass
import re

from parsing import ProjectionError, fact_list, parse_fact, split_terms, strip_comments


STARTS = {"I_S1_classic", "I_S1_mix", "R_S2_classic", "R_S2_mix"}
FINISHES = {
    "I_S2_classic", "I_S2_classic_recovery_candidate", "I_S2_mix",
    "R_Data_same_epoch", "R_Data_advance_epoch", "R_Data_recovery_candidate",
    "R_Timeout", "R_Timeout_recovery_candidate", "I_Timeout", "B_Collision_Yield",
}
TOKENS = {
    "ResumeSlot": "slot", "StartPermit": "permit", "BusySlot": "busy",
    "FinishPermit": "finish", "IWait": "attempt", "RPending": "attempt",
}
ACTIONS = {"LockStage", "ResumeStart", "ResumeFinish", "LockAcquire", "LockRelease", "Init", "I_Start"}
EQUATIONS = {
    "flip(roleA)=roleB", "flip(roleB)=roleA", "fst(<x.1,x.2>)=x.1",
    "snd(<x.1,x.2>)=x.2", "kdec(kem(ss,pk(dk)),dk)=ss",
    "sdec(senc(x.1,x.2),x.2)=x.1",
}
ARITIES = {
    "ResumeSlot": 3, "StartPermit": 3, "BusySlot": 3, "FinishPermit": 3,
    "IWait": 15, "RPending": 11, "LockStage": 3, "ResumeStart": 3,
    "ResumeFinish": 3, "LockAcquire": 3, "LockRelease": 3, "Init": 2, "I_Start": 4,
}
TARGETS = {
    "lock_stage_order": """
      ∀ pid r %s %t #i #j.
      (((LockStage(pid,r,%s)@#i) ∧ (LockStage(pid,r,%t)@#j)) ∧ (#i<#j)) ⇒
      (∃ %previous #k.
        (((LockStage(pid,r,%previous)@#k) ∧ (%t=(%previous%+%1))) ∧
          ((#i<#k) ∨ (#i=#k))) ∧ (#k<#j))
    """,
    "resume_serialized": """
      ∀ pid r %s %t #i #j.
      (((ResumeStart(pid,r,%s)@#i) ∧ (ResumeStart(pid,r,%t)@#j)) ∧ (#i<#j)) ⇒
      (∃ %u #k. ((ResumeFinish(pid,r,%u)@#k) ∧ (#i<#k)) ∧ (#k<#j))
    """,
    "initial_resume_serialized": """
      ∀ pid ck x y pq rq #p #i #j.
      ((((((Init(pid,ck)@#p) ∧ (I_Start(pid,roleA,x,pq)@#i)) ∧
        (Cur(pid,roleA,ck)@#i)) ∧ (I_Start(pid,roleA,y,rq)@#j)) ∧
        (Cur(pid,roleA,ck)@#j)) ∧ (#i<#j)) ⇒
      (∃ %s #k. ((ResumeFinish(pid,roleA,%s)@#k) ∧ (#i<#k)) ∧ (#k<#j))
    """,
}


@dataclass(frozen=True)
class Projection:
    name: str
    action: str
    before: tuple = ()
    after: tuple = ()
    events: tuple = ()


def stage(term: str) -> str:
    while term.startswith("(") and term.endswith(")"):
        term = term[1:-1]
    return term


def projected_facts(facts: list[str], actions: bool = False) -> Counter:
    projected = []
    for text in facts:
        name, args, persistent = parse_fact(text)
        if name in (TOKENS if actions else ACTIONS):
            raise ProjectionError(f"{name}: unsupported lifecycle fact position")
        if name not in (ACTIONS if actions else TOKENS):
            continue
        if persistent:
            raise ProjectionError("persistent lifecycle fact/action")
        if len(args) != ARITIES[name]:
            raise ProjectionError(f"{name}: lifecycle projection mismatch (arity)")
        if not actions:
            projected.append((TOKENS[name], args[0], args[1], stage(args[-1])))
        elif name == "Init":
            projected.append((name, args[0]))
        elif name == "I_Start":
            projected.append((name, args[0], args[1]))
        else:
            projected.append((name, args[0], args[1], stage(args[2])))
    return Counter(projected)


def project_rule(name: str, text: str) -> Projection:
    text = strip_comments(text).strip()
    premises, cursor = fact_list(text, 0)
    arrow = re.match(r"\s*--\s*", text[cursor:])
    if not arrow:
        raise ProjectionError(f"{name}: expected action arrow")
    cursor += arrow.end()
    actions, cursor = fact_list(text, cursor)
    arrow = re.match(r"\s*->\s*", text[cursor:])
    if not arrow:
        raise ProjectionError(f"{name}: expected conclusion arrow")
    conclusions, cursor = fact_list(text, cursor + arrow.end())
    if text[cursor:].strip():
        raise ProjectionError(f"{name}: unexpected rule suffix")
    before = projected_facts(premises)
    after = projected_facts(conclusions)
    events = projected_facts(actions, actions=True)
    if name == "Pair":
        action = "pair"
    elif name == "Acquire_Resume":
        action = "acquire"
    elif name in STARTS:
        action = "start"
    elif name in FINISHES:
        action = "finish"
    elif name == "Release_Resume":
        action = "release"
    else:
        action = "stutter"
    pid = "~pid" if action == "pair" else "pid"
    role = "roleB" if name == "B_Collision_Yield" else "r"
    ordinal, successor = "%s", "%s%+%1"

    def token(kind: str, value: str = ordinal) -> tuple[str, ...]:
        return kind, pid, role, value

    def event(kind: str, value: str = ordinal) -> tuple[str, ...]:
        return kind, pid, role, value

    expected_before, expected_after, expected_events = [], [], []
    if action == "pair":
        expected_after = [("slot", pid, r, "%1") for r in ("roleA", "roleB")]
        expected_events = [("Init", pid)] + [
            ("LockStage", pid, r, "%1") for r in ("roleA", "roleB")
        ]
        fresh = Counter(
            (fact_name, tuple(arguments), persistent)
            for fact_name, arguments, persistent in map(parse_fact, premises)
        )
        if fresh != Counter({("Fr", ("~pid",), False): 1, ("Fr", ("~ck",), False): 1}):
            raise ProjectionError("Pair: fresh pair identifier initialization mismatch")
    elif action == "acquire":
        expected_before = [token("slot")]
        expected_after = [token("permit", successor), token("busy", successor)]
        expected_events = [event("LockStage", successor), event("LockAcquire", successor)]
    elif action == "start":
        expected_before, expected_after = [token("permit")], [token("attempt")]
        expected_events = [event("ResumeStart")]
        if name.startswith("I_"):
            expected_events.append(("I_Start", pid, role))
    elif action == "finish":
        expected_before = [token("busy"), token("attempt")]
        expected_after = [token("finish", successor)]
        expected_events = [event("ResumeFinish", successor)]
    elif action == "release":
        expected_before, expected_after = [token("finish")], [token("slot")]
        expected_events = [event("LockStage"), event("LockRelease")]
    elif before or after or events:
        raise ProjectionError(f"{name}: unclassified lifecycle facts/actions")
    if (before, after, events) != (
        Counter(expected_before), Counter(expected_after), Counter(expected_events)
    ):
        raise ProjectionError(f"{name}: projection mismatch")
    return Projection(name, action, tuple(before.elements()), tuple(after.elements()), tuple(events.elements()))


def project_export(text: str) -> list[Projection]:
    for name, formula in TARGETS.items():
        declarations = re.findall(
            rf'^lemma {name}\s*\[[^\]]*\]:\s*all-traces\s*"([^"]*)"',
            text, re.M | re.S,
        )
        headers = re.findall(rf"^lemma {name}\b", text, re.M)
        if len(headers) != 1 or len(declarations) != 1 or (
            re.sub(r"\s+", "", declarations[0]) != re.sub(r"\s+", "", formula)
        ):
            raise ProjectionError(f"{name}: unreviewed target formula")
    equations = re.search(r"^equations:\s*(.*?)\n\s*tactic:", text, re.M | re.S)
    if not equations or {
        re.sub(r"\s+", "", equation) for equation in split_terms(equations[1])
    } != EQUATIONS:
        raise ProjectionError("unreviewed equational theory")
    if re.findall(r"^builtins:[^\n]*", text, re.M) != ["builtins: natural-numbers"]:
        raise ProjectionError("unreviewed builtin theory")
    rules = re.findall(
        r"^rule \(modulo E\) ([A-Za-z][A-Za-z0-9_]*):\s*(.*?)(?=^(?:rule |lemma |end\b))",
        text, re.M | re.S,
    )
    if not rules:
        raise ProjectionError("no canonical rules found")
    if len(rules) != len(re.findall(r"^rule\b", text, re.M)):
        raise ProjectionError("unsupported or unparsed rule declaration")
    names = [name for name, _ in rules]
    if len(set(names)) != len(names):
        raise ProjectionError("duplicate rule name")
    if not {"Pair", "Acquire_Resume", "Release_Resume", *STARTS, *FINISHES} <= set(names):
        raise ProjectionError("missing required lifecycle rule")
    return [project_rule(name, body) for name, body in rules]


def lean_certificate(rows: list[Projection]) -> str:
    def ordinal(value: str) -> str:
        if value == "%s":
            return "stage"
        if value == "%s%+%1":
            return "(stage + 1)"
        if value == "%1":
            return "1"
        raise ProjectionError(f"unsupported stage expression: {value}")

    def tokens(facts: tuple) -> str:
        return "[" + ", ".join(f".{kind} {ordinal(value)}" for kind, _, _, value in facts) + "]"

    def event_option(row: Projection, name: str) -> str:
        matching = [event for event in row.events if event[0] == name]
        return f"some {ordinal(matching[0][-1])}" if matching else "none"

    lines = ["import Composition", "", "namespace Cairn", ""]
    for row in rows:
        lines.append(f"-- {row.name}")
        if row.action == "pair":
            keys = ", ".join(
                f"(pid, {'false' if role == 'roleA' else 'true'})"
                for _, _, role, _ in row.after
            )
            lines.append(
                f"example (pid : Nat) : ([{keys}] : List Key) = "
                "[(pid, false), (pid, true)] := by rfl"
            )
            for role in ("roleA", "roleB"):
                facts = tuple(fact for fact in row.after if fact[2] == role)
                events = tuple(event for event in row.events if event[0] == "LockStage" and event[2] == role)
                local = Projection(row.name, row.action, after=facts, events=events)
                lines.extend([
                    f"example (clock : Nat) : inventory (initialAt clock) = "
                    f"countTokens {tokens(facts)} := by rfl",
                    f"example (clock : Nat) : (initialAt clock).markers = "
                    f"recordEvent ({event_option(local, 'LockStage')}) clock [] := by rfl",
                ])
            continue
        lines.extend([
            f"example (stage : Nat) : {tokens(row.before)} = inputs .{row.action} stage := by rfl",
            f"example (stage : Nat) : {tokens(row.after)} = outputs .{row.action} stage := by rfl",
            f"example (stage : Nat) : ({event_option(row, 'LockStage')}, "
            f"{event_option(row, 'ResumeStart')}, {event_option(row, 'ResumeFinish')}) "
            f"= observation .{row.action} stage := by rfl", "",
        ])
    lines.extend(["end Cairn", ""])
    return "\n".join(lines)
