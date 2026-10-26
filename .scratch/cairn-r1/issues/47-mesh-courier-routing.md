# Mesh courier and routing

Type: research
Status: resolved
Blocked by: 31

## Question

How does a message reach a contact that is not in BLE range, travelling only
along chains of neighbours (the contacts-graph option in the
[mesh research note](../../../docs/research/2026-10-23-ble-mesh-design.md))?
Decide the courier and routing layer: what a relaying neighbour stores and
forwards, how the destination is addressed without revealing the social graph
(for example a BitChat-style 16 B routing tag), TTL and storage limits, and
delivery acknowledgements.

Done when an ADR records the design, the threat model adds the malicious
courier adversary (drop, delay, replay, traffic analysis), and the formal
model scope for end-to-end secrecy and authenticity across relays is decided.

## Comments

2026-10-23: created by [ADR 0021](../../../docs/adr/0021-automatic-neighbour-admission.md),
decision 10. Single-hop admission ships first.

2026-10-26: resolved by [ADR 0033](../../../docs/adr/0033-courier-relaying.md).
The owner chose: contacts only (strangers deferred to a future ADR); binary
spray-and-wait with copy budget 6 and a 24 h lifetime, both configurable;
per-envelope routing tags `MAC(K_route, "route", dir ‖ gen ‖ idx)`;
authenticated tombstones `tag ‖ s` with `c = H(s)`; courier on by default,
16 envelopes per depositor (32 Verified), 256 envelopes and 1 MiB total,
refuse when full; formal model `courier.spthy` for secrecy, authenticity,
once-only delivery and tombstone unforgeability, with tag unlinkability
argued in prose. The threat model adds A8, the malicious courier. Spec,
model and implementation continue in
[issue 54](54-courier-spec-model-implementation.md).
