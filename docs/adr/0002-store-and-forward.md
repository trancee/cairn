---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0002 — Store-and-forward: encrypt at send time with a per-session message-key chain

## Context

`pqcble` must deliver messages written while two contacts are apart, and must do it in the background on Android and iOS. Session keys exist only during a connection: Resume derives them from a fresh X25519 exchange. Messages are **sealed when the user sends them**, not when they are delivered. The sending user then sees a durable, encrypted "sent" state at once, and plaintext never waits in a queue for a future session. The cost is that message keys must exist outside a session, and some may have to be kept for late delivery.

## Decision

- **Message layer.** Each direction has a symmetric **message-key chain**. Sealing a message derives its message key from the chain, advances the chain one step, and erases the used key. The sealed message is `message number ‖ AES-256-GCM(16 B tag)` under ADR 0001's suite, about 18 B of overhead.
- **Reseeding.** Each successful Resume reseeds both directions' chains from the new chain key, folding in that session's X25519 and the latest PQ epoch. Every sealed message carries a 1-byte **chain generation** that selects its chain.
- **Two layers, only for queued messages.** A queued message travels inside a normal session data frame on delivery (+17 B). The session layer hides its number and timing. Real-time messages sent while connected use the session layer only (17 B).
- **One message-number space per direction** for all chat messages. If a real-time message is unacked when the link drops, it is sealed with the message layer and moves into the queue under the same number.
- **Delivery.**
  - The receiver acks cumulatively (the highest contiguous number), inside the session.
  - The sender keeps sealed messages until acked and resends everything above the last ack after each Resume.
  - The receiver drops duplicates.
- **Bounds.** Per contact: at most **500** queued messages, each kept at most **7 days**.
  - A full queue blocks sending in the UI.
  - An expired message is dropped, shown as "not delivered", and announced to the receiver as an **expired range**.
- **Skipped keys.** The receiver derives and keeps skipped message keys only for real gaps: at most **500**, each for at most **7 days**. On an expired-range notice it deletes them immediately.
- **Receipts.** Delivery receipts come from the ack. Read receipts are explicit session frames, controlled by one **global, reciprocal** toggle that is **on by default**.
- **Persistence.**
  - The sender stores the sealed message and the advanced chain **atomically**, before the UI shows "sent".
  - Chain and skipped-key state is excluded from backups.
  - After a reinstall or restore, the user must pair again.

## Alternatives considered

- **Encrypt at delivery time:** the strongest forward secrecy and no skipped keys, but plaintext waits in a queue and "sent" means only "stored locally".
- **One message chain from pairing, never reseeded:** simpler, but queued messages never get post-compromise healing.
- **Two layers for every message:** one code path, but about 35 B per real-time message instead of 17 B.
- **One layer only (queued ciphertext sent bare):** about 18 B, but message numbers and timing become visible to passive BLE observers.
- **Signal's MAX_SKIP = 1000 with a time limit only:** keeps more keys for longer than the queue bound can ever need.

## Risks

- **Forward-secrecy cost.** Until a queued message is delivered, the sender's sealed copy and the receiver's skipped keys let a device thief read it (up to 500 messages per contact, up to 7 days). Messages queued before a compromise and delivered after it are readable by the thief.
- **Atomicity.** Persisting the chain without the sealed message, or the reverse, permanently breaks decryption of that message number.
- **Read receipts** reveal reading behaviour by default. The toggle is reciprocal so turning it off costs the user something.
- **Traffic analysis.** Bursts of resent queued messages are visible as traffic volume. Padding classes from the data-frame design reduce, but do not remove, this.

## Migration

First version, so nothing to migrate. Changing the layering or the chain derivation needs a new protocol version byte. Queued messages sealed under an old version must be delivered or expired before a device upgrades.
