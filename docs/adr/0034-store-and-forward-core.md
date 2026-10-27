---
status: accepted
date: 2026-10-27
version: cairn-r1
---

# 0034: Store-and-forward in the core: row persistence and spec gaps

## Context

Slice S5 ([issue 35](../../.scratch/cairn-r1/issues/35-slice-s5.md)) adds
store-and-forward ([ADR 0002](0002-store-and-forward.md), spec §8) to the
Rust core. Couriers ([ADR 0033](0033-courier-relaying.md),
[issue 54](../../.scratch/cairn-r1/issues/54-courier-spec-model-implementation.md))
build on it. Today the core sends real-time CHAT only. A message sent while
no session is up is rejected with `NoSession`
([ADR 0022](0022-cairn-core-contract.md) §6), and the whole durable state
is one `Persist` blob (ADR 0022 §7).

Five gaps had to be closed first:

- ADR 0006 keeps a `state` row per contact and separate `queue` rows, and
  rejects one blob for everything. ADR 0022's single blob would hold up to
  500 queued messages of up to 4 KB per contact and be rewritten on every
  send.
- A contact paired over a link whose Resume never completed has no message
  chain, because the chains are seeded from `MS_{n+1}`.
- Spec §8 keeps a receive chain "only for generations with outstanding
  messages". The receiver cannot know which generations those are.
- Spec §8 deletes skipped keys "on EXPIRED". Since OI-6, `msgno` travels
  inside the ciphertext, so the receiver cannot map an expired `msgno`
  range to the `(gen, idx)` of a skipped key.
- An unacked real-time CHAT is re-sealed as QUEUED when the link drops. If
  the process dies first, its plaintext is gone, and the receiver's
  cumulative ACK stalls at the gap for ever.

## Decision

The owner chose every rule below on 2026-10-27.

### 1. Row persistence

ADR 0022's `Persist` action and blob `Restore` are replaced by rows that
match ADR 0006's tables:

| Action | Row |
|---|---|
| `PersistDevice { state }` | the device row: beacon key and day, next `ContactId`, the read-receipt setting |
| `PersistContact { contact, state }` | one contact's row: pairing output, Resume index and chain keys, message chains, skipped keys and delivery counters |
| `PutQueued { contact, msgno, state }` | one sealed queued message |
| `DeleteQueued { contact, msgno }` | removes it once acked or expired |

- `state` is a `Persisted { blob, version }` as before. Every blob is one
  canonical, strictly decoded encoding. Kotlin wraps each row with the
  master key, with AAD `row id ‖ version` (ADR 0006).
- `Restore { device, contacts, queued }` carries the rows back. `device`
  is `None` on a fresh install. A queued row for an unknown contact, a
  duplicate row, or a blob that does not decode returns `InvalidBlob`.
- All row actions of one `handle()` result are applied in one SQLite
  transaction before any later action (ADR 0006). A sealed message and its
  advanced chain are therefore stored atomically (ADR 0002).
- The blob format version becomes `2`. r1 has no released blobs, so there
  is no migration.

### 2. Sending

- **No chain.** `SendChat` to a contact with no message chain returns
  `ChatRejected { reason: NoSession }`, as today. A contact gets its first
  chain at its first Resume, which follows pairing on the same link.
- **In session.** The text is sent as CHAT and `ChatSent` is emitted. The
  plaintext is held in memory until ACKed. When the link drops, every
  unacked CHAT is sealed as QUEUED under the same `msgno` and persisted.
- **Out of session.** The text is sealed as QUEUED at once, persisted with
  the advanced chain, and `ChatQueued` is emitted.
- **Full queue.** 500 queued or unacked messages per contact return
  `ChatRejected { reason: QueueFull }`.
- **Process death.** Each contact row records its unacked real-time
  `msgno`s, never their text. After `Restore`, those messages are reported
  with `ChatExpired` and announced to the peer with EXPIRED at the next
  session, so the peer's ACK moves past the gap.

### 3. Chains and generations

- I reseeds both message chains when it commits `CK_{n+1}` after S2. R
  reseeds them when I's first DATA frame confirms the session. Until then R
  seals under its previous chain, because an unconfirmed `MS_{n+1}` may
  never reach I.
- The receiver keeps a superseded receive chain for 7 days after the
  Resume that superseded it. Any message sealed under it expires within
  that time (spec §8 bounds). A generation collision (OI-5) still deletes
  the old chain at once.
- Skipped keys are deleted when consumed, after 7 days, or on a generation
  collision. EXPIRED does not delete them; it advances the receiver's ACK
  and is shown in the UI.

### 4. Receipts and timing

- The receiver sends ACK with its highest contiguous `msgno`, counting
  received and expired numbers, in the next DATA frame after any CHAT,
  QUEUED or EXPIRED record.
- `MarkRead { contact, msgno }` sends READ in session, or at the next
  session. A global `SetReadReceipts { enabled }` event controls both
  directions: while off, the core sends no READ and drops incoming READ
  (ADR 0002).
- New actions: `ChatQueued`, `ChatDelivered` (ACK covers it), `ChatRead`,
  `ChatExpired` (the sender gave up) and `ChatsExpired { from, to }` (the
  peer announced a gap).
- The core checks the 7-day bounds against `Clock.unix_s` on every event.
  It sets no timers for them.

### 5. Scope and order

1. The Rust core and its FFI/Kotlin contract, with an in-memory row store
   in tests. One PR.
2. SQLDelight sealed storage (ADR 0006). A separate PR.
3. Couriers ([ADR 0033](0033-courier-relaying.md)) on top.

## Formal model

No model changes. The rules decide retention, timing and persistence of
keys the existing models already treat as secret until used.
`courier.spthy` covers the per-index message keys: secrecy, authenticity
and once-only acceptance. Keeping a key longer only widens the
compromise window ADR 0002 already accepts (500 keys for 7 days).

## Consequences

- The FFI and Kotlin adapter change in step 1: four row actions replace
  `Persist`, and `Restore` takes rows.
- A device thief can read messages whose skipped keys are still held, for
  up to 7 days, even after the sender announced them expired.
- A process death during a session can lose real-time messages that the
  peer never received. They are shown as not delivered, never silently
  dropped.
- Messages R sends just after S2 but before I's first DATA frame use the
  previous generation.

## Rejected alternatives

- **Keep one blob for S5.** Simplest now, but contradicts ADR 0006 and
  rewrites megabytes per send.
- **Seed a chain at pairing.** Lets messages queue straight after pairing,
  but needs a new key derivation and a model check to close a gap of a few
  seconds.
- **Sender declares outstanding generations.** Exact retention, but adds a
  record type for a saving the 500-key bound already caps.
- **EXPIRED carries `gen ‖ idx` ranges.** Deletes skipped keys at once, but
  changes the wire format for a forward-secrecy gain inside an accepted
  7-day window.
- **Seal every real-time CHAT at send time.** Loses nothing on a crash, but
  every acked CHAT leaves the receiver a skipped key.
