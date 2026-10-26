---
status: accepted
date: 2026-10-26
version: cairn-r1
---

# 0033: Couriers carry queued messages to out-of-range contacts

## Context

Every nearby peer becomes a neighbour automatically
([ADR 0021](0021-automatic-neighbour-admission.md)), but a queued message
reaches its contact only at their next Resume
([ADR 0002](0002-store-and-forward.md), spec §8). A contact who is never in
range again never gets it. The link graph is well connected: in a 900 s
fleet run every phone was within 4 hops of every other from 120 s
([ADR 0031](0031-android-stable-slots.md)), but links last tens of seconds,
so a route that exists now is gone by the next message.

The [mesh research note](../research/2026-10-23-ble-mesh-design.md)
recommends the contacts-graph option: the pairwise core stays as it is,
and neighbours carry sealed mail they cannot read
(store-carry-forward, after BitChat's courier and DTN spray-and-wait).
[Issue 47](../../.scratch/cairn-r1/issues/47-mesh-courier-routing.md) asked
for that layer.

## Decision

The owner chose every rule below on 2026-10-26.

1. **Scope.** A message travels through couriers only to an existing
   **contact** that is out of range. Messaging a peer that was never a
   contact, which needs sealing to a non-adjacent peer and a prekey
   distribution the mesh does not have, is a separate future ADR.
2. **Envelope.** The courier carries the queued message's existing
   ciphertext, sealed once under `mk_idx` (spec §8), inside an envelope that
   hides `gen` and `idx`:
   ```
   ENV    = tag(16) ‖ c(16) ‖ expiry(u32) ‖ copies(1) ‖ ct
   tag    = MAC(K_route, "route", dir ‖ gen ‖ LEB128(idx))
   s      = KDF(mk_idx, "", "delivered", "", 16)
   c      = Trunc16(H(lp("cairn-r1 delivered") ‖ s))
   ct     = Seal(mk_idx, 0^12, gen ‖ idx, padded(LEB128(msgno) ‖ text)) ‖ tag(16)
   ```
   - `K_route = KDF(RK, "", "route", "", 32)` is a new pairing output
     (spec §5.5), derived before `RK` is erased. Only the two contacts can
     compute a tag.
   - A tag is new for every envelope, so couriers cannot link two
     envelopes of one pair. It is also the envelope's ID for deduplication.
   - The inner plaintext is padded to the smallest of
     {32, 64, 128, 256, 512, 1024, 2048} B that fits, so a courier learns only
     the bucket. Messages over 2048 B are not given to couriers.
   - `expiry` (Unix minutes) and `copies` are not authenticated. Couriers
     clamp them (rule 4); neither affects what the recipient accepts.
   - The sender computes `s` and `c` while sealing, before it erases
     `mk_idx`, and keeps `s` until the message is delivered or expired.
   - Overhead: 37 B over the ciphertext; a 1-line chat is 32 + 16 + 37 = 85 B.
3. **Forwarding: binary spray-and-wait.**
   - A sender deposits an envelope with `copies = L` while the contact is
     queued and not linked. A holder with `copies > 1` hands
     `⌊copies / 2⌋` to a neighbour that lacks the tag and keeps the rest.
     A holder with 1 copy only delivers. A receiver gets at most half the
     giver's copies, so with `L = 6` (6 → 3 → 1) an envelope passes at most
     2 couriers: 3 links from sender to recipient.
   - A handover completes when the receiver accepts. Until then the giver
     keeps its copies, so a dropped link can duplicate custody but never
     lose it.
   - Envelopes travel only over authenticated pairwise links, inside DATA
     frames (spec §7), so A1 sees none of their fields.
4. **Configuration.** Each device configures its own copy budget `L`
   (default **6**, 1–16) and envelope lifetime (default **24 h**,
   1 h – 7 d). As a sender it sets `copies = L` and
   `expiry = now + lifetime`. As a courier it clamps an incoming
   `copies` to its own `L` and `expiry` to `now` + its own lifetime, and drops
   an envelope at expiry. A sender re-deposits an envelope that expired
   while its message is still queued, at most once per lifetime.
5. **Inventory and delivery.** On each Resume, both sides send the tags they
   hold, own and carried, as 8 B prefixes (spec §8.1). A recipient precomputes the tags of the next
   unreceived indices of each live chain of each contact (at most 500 per
   contact, spec §8), matches locally, and fetches only the matches.
   Consumed indices leave the window, so duplicates are never fetched.
   A courier learns that this neighbour took this envelope, and nothing
   about the sender.
6. **Tombstones.** After opening a fetched envelope, the recipient sends
   `TOMB = tag ‖ s` (32 B) to the courier. Any holder checks
   `Trunc16(H(lp("cairn-r1 delivered") ‖ s)) == c`, deletes the envelope,
   and passes the tombstone on in later inventories until the envelope's
   expiry. A sender that learns of delivery by ACK publishes the
   tombstones of its own deposited envelopes. Making a tombstone needs
   `mk_idx`, so couriers cannot fake a delivery.
7. **Courier limits.** Couriering is **on by default**; the user can turn
   it off.
   - At most **16** live envelopes per depositing neighbour, **32** for a
     Verified neighbour.
   - At most **256** envelopes and **1 MiB** in total.
   - When full, a courier **refuses** new deposits. It never evicts, so a
     flooder cannot push out honest mail.
   - A courier refuses a tag it holds or has a tombstone for.
8. **Failures.** An envelope that fails `Open` is dropped without consuming
   `mk_idx`, the link to that courier closes (fail closed, spec §7.1), and
   the tag is not fetched from that courier again. A matching tag whose index
   was already consumed is ignored.
9. **Wire.** Spec work adds `K_route` to §5.5, the inner padding to §8, the
   courier rules as a new §8 subsection, and DATA records for inventory,
   fetch, envelope, deposit, accept or refuse, and tombstone to §7.3. It is
   tracked as OI-37 in [issue 54](../../.scratch/cairn-r1/issues/54-courier-spec-model-implementation.md).

## Formal model

A new Tamarin trace model `courier.spthy` treats every courier as the
Dolev-Yao attacker and proves, before implementation (Constitution O3/S6):

- **P1 secrecy:** a message sealed to an honest contact stays secret.
- **P2 authenticity:** the recipient accepts only what its contact sealed.
- **P3 once-only:** an envelope replayed along any courier path is accepted
  at most once.
- **P4 tombstones:** a valid tombstone exists only if the recipient opened
  the envelope or the sender released `s`.

**P5 tag unlinkability** is argued in prose from the PRF security of
HMAC-SHA-384 and is not modelled. A diff-mode model was considered and
rejected as too costly for its value. The existing pairing, Resume and
ratchet models are unchanged: couriers never take part in them.

## Consequences

- Queued messages can reach contacts that are out of range, held by at most
  `L` devices and at most 3 links from the sender, with no new asymmetric
  cryptography and no change to pairing, Resume or the ratchet.
- One new pairing output (`K_route`) and inner padding of queued messages.
  Contacts paired before this change have no `K_route`; r1 is unreleased, so
  re-pairing is acceptable.
- Couriers spend storage (≤ 1 MiB), slot time and battery for others. A
  flooder is bounded by admission limits (spec §5.6) times the
  per-depositor quota.
- A new adversary, the malicious courier (A8), joins the threat model:
  - it can drop, delay, replay or corrupt mail; the only defence is
    redundancy across `L` copies;
  - the first courier knows the depositor sent something, the last one
    knows the fetcher received something. Colluding first and last couriers
    can link sender and recipient, so the contact graph is not hidden from
    them;
  - it can rewrite `copies` and `expiry`, bounded by every other courier's
    clamps.
- Traffic analysis across a dense mesh (timing, envelope counts per link)
  is not addressed.

## Rejected alternatives

- **Strangers as recipients now** (PQXDH-style sealing): a 1088–1120 B
  KEM ciphertext per first message and no prekey distribution. Deferred.
- **Two-hop only:** simpler, but reach depends on one carrier meeting the
  recipient.
- **Epidemic forwarding with a hop TTL** (BitChat): best reach, but
  unbounded copies per envelope and the most battery, slot and abuse cost.
- **Per-day tags:** let couriers link and count a pair's envelopes per day.
- **No courier acks:** couriers would carry delivered mail until expiry.
- **Evicting the oldest envelope when full:** a flooder could push out
  honest mail.
- **Prose-only security argument:** contradicts formal model before
  implementation for a new protocol step.
