# Formal model: PQ ratchet mixing

Type: task
Status: open
Blocked by: 26

## Question

Write and prove the symbolic Tamarin model of PQ ratchet mixing: KEM_EK/KEM_CT chunks carried in DATA frames, with a completed epoch mixed into CK at the next Resume. Follow the [formal-tooling research](../../../docs/research/2026-10-05-formal-model-tooling.md) and cover its 8 ratchet lemmas:
- post-compromise security after one completed epoch;
- resistance to harvest-now-decrypt-later attackers;
- no downgrade to the classical-only path.

Put the model under `docs/spec/models/`. A failing lemma reopens the relevant ADR. This model gates implementing the ratchet, per the formal-verification gate.

## Comments
