# Store-and-forward sync semantics

Type: grilling
Status: resolved
Blocked by:

## Question

When two peers reconnect, how are queued messages synchronized: per-direction ordering and counters, acknowledgements, deduplication, retransmission after a dropped link, maximum queue size and message expiry, and how this interacts with data-frame counters, the PQ ratchet epoch boundaries, and erasure of old keys (forward secrecy vs delayed delivery)?

## Comments

- 2026-10-05 (charting): background delivery on both platforms is required. Queued messages are **encrypted at send time** with a Signal-style **skipped-message-key window** (user chose this over encrypt-at-delivery). This ticket must fix window size, key expiry, queue bounds, and the forward-secrecy cost of retained keys.

## Answer

Recorded in [ADR 0002 — Store-and-forward](../../../docs/adr/0002-store-and-forward.md) (user, 2026-10-05, two grilling rounds):
- Messages are sealed at send time with per-direction message-key chains, reseeded at every Resume; a 1 B chain generation selects the chain.
- Two layers for queued messages only; real-time messages use the session layer only.
- One message-number space per direction. Cumulative acks, resend after Resume, dedup.
- 500 messages / 7 days per contact, with an expired-range notice.
- Skipped keys: at most 500, 7-day TTL.
- Delivery receipts and read receipts; read receipts are a global, reciprocal toggle, on by default.
- Sealed message and chain are persisted atomically. No backups; reinstall means pairing again.
