---
status: accepted
date: 2026-10-28
version: cairn-r1
---

# 0036: Courier state and rows in the core

## Context

[ADR 0033](0033-courier-relaying.md) and spec §8.1 define envelopes,
inventories and tombstones. The core must keep, across restarts:

- the contact's `K_route`;
- for each queued message given to couriers, its own envelope: `s`, the
  copies still held, `expiry`, and whether it was renewed;
- envelopes carried for other contacts, at most 256 and 1 MiB;
- tombstones, at most 1024.

A tag is `MAC(K_route, "route", dir ‖ u8(gen) ‖ LEB128(idx))`, where `dir`
is the label of the chain the message was sealed on. A device is I in one
Resume and R in the next, so `dir` changes per generation. The
version-2 contact blob ([ADR 0034](0034-store-and-forward-core.md) §1)
records neither `K_route` nor any chain's `dir`. The recipient window
needs `dir` for every live receive chain and every skipped key, and a
skipped key can outlive its chain.

The row actions are `PersistDevice`, `PersistContact`, `PutQueued` and
`DeleteQueued`; the SDK stores them in sealed SQLite rows
([ADR 0035](0035-sealed-row-storage.md)).

## Decision

1. **Contact blob version 3.** The contact blob adds `K_route` after the
   door keys, and one `dir` byte (`I` or `R`, its tag label) to the send chain, each
   receive chain and each skipped key. Every blob becomes version 3. r1 is
   unreleased, so there is no migration: version-2 rows fail `Restore`
   with `InvalidBlob`, and r1 test installs must clear their app data
   before upgrading.
2. **Own envelopes live in the queued row.** A queued message whose
   `inner` fits 2048 B, sealed while fewer than 256 own envelopes exist,
   gets an own envelope inside its `PutQueued` blob:
   `tag(16) ‖ s(16) ‖ u32(expiry) ‖ u8(copies) ‖ u8(renewed)`. `c` and
   `ct` are not stored: `c` comes from `s`, and `ct` is the queued
   ciphertext. A handover or renewal rewrites the queued row. The row is
   deleted on ACK or expiry, as before.
3. **One new row kind for carried envelopes and tombstones.**
   - `PutCourier { slot, state }` and `DeleteCourier { slot }`, with
     `Restore { …, courier }` carrying the rows back. `slot` is a `u64`
     assigned by the core. After `Restore`, the next slot is one above the
     highest restored slot, so no counter is persisted.
   - A carried envelope's blob is `0 ‖ u64(depositor contact) ‖ ENV`,
     with `copies` and `expiry` already clamped.
   - A tombstone's blob is `1 ‖ tag(16) ‖ s(16) ‖ u32(expiry)`. A
     carried envelope that is delivered becomes a tombstone in the same
     slot.
   - Slots are not tags: tag bytes are chosen by the depositor and may
     collide in any prefix.
   - The SDK seals a courier row as [ADR 0035](0035-sealed-row-storage.md)
     §2 does, with `kind` 3, the slot in the `contact` field and `msgno` 0.
4. **Configuration in the device row.** The device blob adds
   `u8(enabled) ‖ u8(L) ‖ u16(T in minutes)`, defaulting to on, 6 and
   1440. A new event `SetCourier { enabled, copies, lifetime_minutes }`
   persists it; values outside 1–16 copies or 60–10080 minutes return
   `CoreError::InvalidCourierConfig`. Turning couriering off refuses new
   deposits and keeps carried envelopes until they expire.
5. **Limits are counted from rows.** Per-depositor counts, the 256/1 MiB
   totals and the 1024 tombstones are recomputed from restored rows, not
   stored.
6. **Delivery notices are unchanged.** `ChatDelivered` still means the
   peer's ACK covered the message. A TOMB for an own envelope deletes the
   envelope's copies but not the queued message, which waits for the ACK.

## Consequences

- One new table in the SDK (`courier`), sealed like the others, and two
  new FFI actions. Kotlin `RowStore`, `SealedRowStore` and the SQLDelight
  schema gain the courier rows.
- A contact row grows by 32 B for `K_route` plus 1 B per chain and per
  skipped key: up to about 532 B at 500 skipped keys.
- A carried envelope costs one row write when stored, one per handover and
  one when it becomes a tombstone.
- Existing installs must clear their app data, which drops their
  contacts, and re-pair. The SQLDelight schema stays at version 1, so an
  old database also lacks the `courier` table.

## Rejected alternatives

- **Recomputing `dir` from the Resume role:** the device does not keep a
  history of its role per generation, and a skipped key outlives its chain.
- **Tags as row keys:** a depositor chooses the tag bytes; core slots keep
  the key space under the device's control and keep tags off disk keys.
- **One blob for all courier state:** up to 1 MiB rewritten per change.
- **Own envelopes as courier rows:** they would duplicate the queued
  ciphertext and need two writes to stay consistent with the queued row.
