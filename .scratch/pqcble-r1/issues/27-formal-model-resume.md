# Formal model: Resume

Type: task
Status: open
Blocked by: 26

## Question

Write and prove the symbolic Tamarin model of Resume (S1/S2 and the KCI variants), following the [formal-tooling research](../../../docs/research/2026-10-05-formal-model-tooling.md). It covers that report's 10 Resume lemmas: mutual authentication, key secrecy, forward secrecy across epochs, replay resistance, and KCI resistance in the KCI profile.
- Put the model under `docs/spec/models/`.
- A failing lemma reopens the relevant ADR.
- This model gates implementing Resume, per the formal-verification gate.

## Comments
