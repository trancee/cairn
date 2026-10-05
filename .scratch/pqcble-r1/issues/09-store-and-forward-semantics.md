# Store-and-forward sync semantics

Type: grilling
Status: open
Blocked by:

## Question

When two peers reconnect, how are queued messages synchronized: per-direction ordering and counters, acknowledgements, deduplication, retransmission after a dropped link, maximum queue size and message expiry, and how this interacts with data-frame counters, the PQ ratchet epoch boundaries, and erasure of old keys (forward secrecy vs delayed delivery)?

## Comments

- 2026-10-05 (charting): background delivery on both platforms is required. Queued messages are **encrypted at send time** with a Signal-style **skipped-message-key window** (user chose this over encrypt-at-delivery). This ticket must fix window size, key expiry, queue bounds, and the forward-secrecy cost of retained keys.
