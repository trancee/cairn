---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0005: Wire format: frames, records, version, padding, beacon and doorbell

## Context

[ADR 0001](0001-crypto-suite.md) fixes the suite, [ADR 0002](0002-store-and-forward.md) the message layer, and [ADR 0003](0003-ble-transport.md) the framing and size limits. What remained open was the byte layout of every message.

The goal is the smallest bytes on air that still satisfy:
- legacy advertising (31 B);
- the pre-auth frame limit (2560 B);
- an ATT MTU of 23 at minimum.

Byte counts and airtime come from the prototype `docs/research/prototypes/wire-layouts/wire_layouts_prototype.py`. The full layout tables are in [the wire-format draft](../research/2026-10-05-wire-format-draft.md).

## Decision

- **Version.**
  - The version byte appears only in the QR payload and in pairing message P1.
  - Otherwise the version is implied by the GATT service UUID and the `"pqcble-r1"` label in every KDF/MAC context.
  - Each contact stores its agreed version. Resume and data frames carry no version byte, and there is no negotiation.
- **Frame header (1 B).**
  - Layout: `MORE(1) | type(3): PAIR, S1, S2, DATA | sub(4)`.
  - Every fragment repeats the header; reassembly clears MORE.
  - In DATA frames the header is the AEAD AAD.
  - Reserved values close the link silently.
- **Pairing.**
  - Four messages: P1 `ver ‖ mode ‖ H(nA) ‖ X-Wing ek` (1251 B); P2 `ct ‖ nB` (1137 B); P3 `nA ‖ AEAD(confirm ‖ card)`; P4 `AEAD(confirm ‖ card)`.
  - The SAS comes from the transcript and `nB` through commit-then-reveal.
  - The QR payload is `ver ‖ H(ek_A) ‖ token` (49 B).
  - In QR mode, A also confirms a 4-digit code derived from the transcript, which both phones show. It is local only, so there is no wire change (see the [threat model](../spec/threat-model.md)).
  - TOFU keeps the transcript so it can be verified later.
- **Resume.** S1 57 B and S2 49 B, as in findings §4.2. The KCI variants add one ML-KEM-768 ciphertext each way.
  - The Resume index and retry counter are never sent. Ratchet DATA records carry their epoch identifier.
  - **No 0-RTT.**
- **DATA frame.** `hdr ‖ AES-256-GCM(records ‖ zero padding) ‖ tag(16)`, with an implicit nonce.
  - Records are `type(1) ‖ LEB128 len ‖ body`; the current type table, including later amendments, is normative in [spec §7.3](../spec/pqcble-r1.md#73-records).
  - A `0x00` type byte starts the padding.
- **Padding.** The plaintext is padded to buckets of 32, 64, 128, 256, 512, 1024, 2048 and the maximum.
  - Ratchet KEM_EK/KEM_CT chunks (with an epoch and a LEB128 offset, so a transfer can continue after a disconnect) fill the slack first.
  - A completed KEM epoch is mixed into `CK` at the next Resume, so frames need no key-phase bit.
- **Overhead.** The 21 B real-time chat overhead is accepted. At MTU 23, even "hi" needs two fragments.
- **Beacon.**
  - One **device beacon key**, given to every contact at pairing: `Trunc8(HMAC(BK_d, role ‖ 5-min window))`, with a daily one-way `BK_d` chain.
  - Removing a contact rotates the key, and the new key reaches the remaining contacts at their next Resume.
  - Android legacy advertising (flags + service data with the 128-bit UUID + beacon) totals 29 / 31 B.
- **Doorbell.** An 8 B per-contact `Trunc8(HMAC(K_door_pair, "door" ‖ window))` that **replaces** the beacon in the same slot. It carries no payload.
  - Only Android rings; iOS can only be rung.
  - **Amends ADR 0001:** the doorbell is an HMAC tag, not an AEAD tag.

## Alternatives considered

- **A version byte in S1.** +1 B per Resume and no benefit, since the contact already stores the version.
- **Beacons per contact pair.** These resist tracking by contacts, but advertising must cycle through N beacons, so discovery slows as N grows.
- **Pad to 16 B, or no padding.** Smaller, but message lengths leak, and ratchet chunks would cost extra frames.
- **0-RTT early data.** Replayable within the desync window, and saves only about one connection event.
- **The AEAD doorbell `beacon ‖ ctr ‖ AEAD(flags) ‖ tag`.** At 42 B it needs extended advertising, which iOS lacks and only some Android devices support.
- **Implicit-length last record.** Saves 1–2 B per message but complicates parsing.

## Risks

- **Tracking by contacts.** A contact, or a stolen contact phone, can recognise and track the device's beacon until the key rotates.
- **Doorbell replay.** A doorbell replayed within its window causes one wasted connection. Its presence reveals "pending mail" only to the intended contact.
- **Padding cost.** Bucket padding costs up to about 2× bytes for small messages (a 30 B chat becomes 81 B instead of 51 B).
- **Parsing.** The LEB128 and record parser runs on decrypted plaintext and must be fuzzed (`pqcble-wire`). Its timing depends only on lengths, never on key material.
- **Unverified inputs.** The legacy-advertising arithmetic assumes Android adds only the 3 B flags AD. This needs a device-lab check.

## Migration

This is the first version. Any layout change requires a new protocol version: a new service UUID, a new `ctx` label and a new version byte. Contacts paired under an older version must pair again.

## Amendments

2026-10-05, from spec consolidation ([`pqcble-r1` spec §13](../spec/pqcble-r1.md#13-consolidation-issues-resolved-2026-10-05)):
- The contact card carries `day ‖ BK_day`, so P3 ≤ 135 B and P4 ≤ 119 B (OI-1).
- The beacon formula has no `role` (OI-2).
- New records: `0A BEACON_KEY`, `0B BEACON_ACK` and `0C EPOCH_DONE` (provisional) (OI-3, OI-4).
- S1 sub bit 1 = MIX (provisional) (OI-4).
- QUEUED body = `gen ‖ LEB128(idx) ‖ Seal(msgno ‖ text)` (OI-6).
- iOS beacon UUID derivation (OI-9).
- CLOSE reason codes (OI-14).

2026-10-05, from *Formal model: Resume* ([`pqcble-r1` spec §13](../spec/pqcble-r1.md#13-consolidation-issues-resolved-2026-10-05)):
- `K_id` and `K_auth_I` bind I's pairing role (`"id A"`, `"auth I B"`, …), so a device never accepts its own reflected S1. No byte changes (OI-16).
- At most one Resume per contact in flight; on collision, pairing role A's attempt wins (OI-17).
- KCI profile: `th_s` covers `ct_I`, so S2 cannot be altered to desync the pair. No byte changes (OI-18).

2026-10-05, from *Formal model: SAS pairing* ([`pqcble-r1` spec §13](../spec/pqcble-r1.md#13-consolidation-issues-resolved-2026-10-05)):
- B aborts unless `P1.mode` equals the mode its user selected, so a mode downgrade is impossible. No byte changes (OI-19).

2026-10-05, in-progress *Formal model: PQ ratchet mixing* (spec draft 0.5):

- **Context:** wrapping epoch identifiers conflict with non-reuse, and a
  failed MIX attempt followed by a classical retry weakens the no-downgrade
  requirement.
- **Decision:** epoch identifiers are non-wrapping `u32` values, encoded as
  canonical LEB128 in KEM_EK, KEM_CT and EPOCH_DONE (OI-21). A ready initiator
  retains the pending epoch until commitment and keeps MIX = 1 on retries.
  A mismatch fails closed with a local recovery-required error (OI-22).
- **Alternatives:** keep one-byte identifiers with session-bound wrap
  bookkeeping; retain classical fallback with a qualified security claim.
  The user selected simpler identifier semantics and fail-closed mixing.
- **Risks:** epoch identifiers grow from one to at most five bytes. A
  mismatch blocks new sessions until recovery or re-pairing; traffic
  blocking can still prevent progress. The composed formal proof is pending.
- **Migration:** this changes the unreleased draft; there are no released
  contacts to migrate. Future parsers and vectors MUST use the new layout.
  Existing research layouts are historical, superseded drafts. Epoch
  exhaustion requires re-pairing, never wraparound.

2026-10-05, ratchet recovery refinement (OI-23):

- **Context:** a lost first DATA leaves I committed and R holding two CK
  candidates. Erasing or re-mixing an epoch without candidate-specific
  metadata can desynchronise their epoch positions.
- **Decision:** each CK candidate carries its post-mix epoch position.
  I commits and erases at valid S2. R retains the old branch's required
  epoch state until candidate confirmation, then atomically selects its
  CK/position and erases the losing branch. Recovery on an already-mixed
  candidate contributes no second copy of the epoch.
- **Alternative:** add an explicit epoch-commit acknowledgement, costing
  an authenticated exchange and still requiring lost-ack recovery.
- **Risks:** persisted CK and epoch metadata must be transactional;
  partial erasure is unsafe. The composed proof remains pending.
- **Migration:** no wire fields change. Future contact state must persist
  the CK/epoch association; no released state exists to migrate.

2026-10-05, durable ratchet transfer (OI-25/26, spec draft 0.6):

- **Context:** offsets alone cannot recover a transfer when a disconnect
  loses a receipt, and unspecified overlap handling permits ambiguous
  reassembly or unbounded sparse buffers.
- **Decision:** add `0D KEM_PROGRESS` with canonical LEB128 epoch, closed
  one-byte kind (`01` EK, `02` CT) and canonical LEB128 next expected offset.
  Send cumulative receipts only after bytes/offset are atomically durable.
  Re-advertise active-branch progress after Resume; repeat EPOCH_DONE while
  a completed epoch remains active. Persist immutable sender objects before
  transmission and retransmit unacknowledged bytes without regenerating keys.
  Append only at the contiguous frontier; accept exact duplicate ranges
  wholly within it. Gaps, conflicts, cross-frontier overlaps, wrong epochs
  and invalid bounds fail closed without partial storage mutation.
- **Alternatives:** restart the whole transfer after every disconnect;
  allow sparse offset maps. The user selected durable cumulative progress
  and bounded contiguous storage.
- **Risks:** receipts consume DATA slack and cannot guarantee liveness
  against traffic blocking. Their bodies are 3-8 B (epoch 1-5 B, kind 1 B,
  offset 1-2 B), plus the 2 B record header. Transactional persistence,
  malformed/boundary inputs and crash recovery still need implementation
  tests; symbolic pieces do not prove a byte parser.
- **Migration:** this extends the unreleased draft; no released contacts
  exist. Update future parsers/vectors to spec §7.3/§9. A released layout
  change would require the protocol-version migration described above.
