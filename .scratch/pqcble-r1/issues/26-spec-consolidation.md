# Spec consolidation

Type: task
Status: resolved
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

## Answer

Wrote [`docs/spec/pqcble-r1.md`](../../../docs/spec/pqcble-r1.md), draft 0.2: normative RFC 2119 text covering notation, the labelled KDF/MAC, versioning, transport, pairing, Resume, DATA records, store-and-forward, the PQ ratchet (provisional), beacons and the doorbell, and implementation requirements. Test vectors are a placeholder.

Consolidation found 15 issues (OI-1 to OI-15); the user accepted every proposal on 2026-10-05. Main changes:
- the card carries the device beacon key (P3 ≤ 135 B, P4 ≤ 119 B);
- the beacon has no role;
- new BEACON_KEY, BEACON_ACK and EPOCH_DONE records;
- an S1 MIX bit (provisional);
- QUEUED carries the chain index, with the msgno encrypted; generation collisions expire messages;
- a defined doorbell key derivation;
- epoch cadence ≥ 10 Resumes or ≥ 24 h;
- KCI chosen at pairing only;
- "Resume index" added to the glossary.

ADRs 0001, 0002, 0005 and 0008 carry amendment notes. The wire draft is marked superseded.
