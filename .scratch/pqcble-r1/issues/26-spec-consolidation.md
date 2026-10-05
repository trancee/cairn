# Spec consolidation

Type: task
Status: claimed
Blocked by: none

## Question

Merge ADRs 0001–0009, the [wire-format draft](../../../docs/research/2026-10-05-wire-format-draft.md) and the [threat model](../../../docs/spec/threat-model.md) into one normative `docs/spec/pqcble-r1.md`, written in RFC 2119 language:
- primitives and labels;
- the key schedule;
- every message's byte layout;
- state machines for pairing, Resume, the ratchet, the beacon and the doorbell;
- error handling and the security considerations.

Leave a placeholder for test vectors: they come from the reference implementation in a later slice. Flag every inconsistency found between the ADRs instead of silently resolving it.

## Comments
