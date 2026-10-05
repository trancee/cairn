# Formal model: SAS pairing

Type: task
Status: open
Blocked by: 26

## Question

Write and prove the symbolic Tamarin model of SAS commit-then-reveal pairing (P1 commits H(nA); P3 reveals nA), following the [formal-tooling research](../../../docs/research/2026-10-05-formal-model-tooling.md). Cover its 6 SAS lemmas, and add a ProVerif `weaksecret` check of the 2^-20 guessing bound.
- Put the models under `docs/spec/models/`.
- A failing lemma reopens the relevant ADR.
- This model gates implementing SAS pairing, per the formal-verification gate.

## Comments
