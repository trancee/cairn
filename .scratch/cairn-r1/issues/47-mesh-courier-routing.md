# Mesh courier and routing

Type: research
Status: open
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
