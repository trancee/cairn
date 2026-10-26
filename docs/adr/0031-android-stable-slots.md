---
status: accepted
date: 2026-10-26
version: cairn-r1
---

# 0031: Keep the strongest Android links for the mesh

## Context

[ADR 0025](0025-android-gatt-slot-budget.md) gives an Android radio 5 or 6
slots (3 in energy band `LOW`, [ADR 0027](0027-android-energy-bands.md)).
A full radio that sees a waiting peer closes its longest link idle for
30 s, at most once every 15 s ([ADR 0030](0030-android-eviction-interval.md)).
Every link is a candidate.

A 900 s fleet run ([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md))
showed two things:

- The pair graph of the 20 logged phones was one component by 90 s, with
  every phone within 4 hops of every other from 120 s. The later plateau
  is the §5.6 admission limit (10 per hour), not the radio.
- Links churn. Of 1272 links, the median lived 27 s, the 90th percentile
  52 s, and none 300 s. Links ended 30–55 s after their last Resume frame,
  so idle eviction closed them. The core never closes an authenticated
  link itself.

Cairn is a peer-to-peer mesh (ADR 0021). A message reaches a peer over a
route through other links, so the mesh needs links that stay up, not a
link to every peer. Eviction picks by idleness alone and closes the links
a mesh would route over.

## Decision

A radio keeps its strongest links as **stable** and rotates the rest
(spec §10.4):

- **Quota.** At most ⌊¾ × budget⌋ links are stable: 3 of 5 slots, 4 of 6,
  2 of 3 in `LOW`. At least one slot always rotates, so discovery and
  admission go on.
- **Eligibility.** A link is a candidate once it has been up 60 s, so a
  link that is still pairing or flaps is never kept.
- **Signal.** A link's RSSI is its latest reading no older than 30 s:
  - On a central link, the radio reads the RSSI (`readRemoteRssi`) every
    10 s. It is an HCI read outside the ATT queue: AOSP does not take the
    GATT busy lock for it, so it needs no slot between reads and writes.
  - Android has no RSSI call for a GATT server's links, so on a peripheral
    link it is the RSSI of the latest scan result from that address.
- **Rank.** Candidates with an RSSI come first, strongest first, then
  candidates without one, longest up first. The first quota of them are
  stable. The rank is recomputed at each eviction.
- **Eviction.** A stable link is never evicted. Otherwise ADR 0025 and
  ADR 0030 are unchanged: the radio closes the longest link idle for 30 s,
  at most once every 15 s, for a waiting peer.

The radio logs each central RSSI reading, and the RSSI of each evicted
link, for fleet analysis.

## Consequences

- A full radio keeps up to 3 or 4 links to its nearest neighbours, even
  while they are idle. The remaining 1 or 2 slots turn over as before.
- A phone takes in new peers more slowly, as fewer slots rotate. The pair
  count stops being the measure of the fleet; link lifetime and the
  connectivity of the link graph replace it.
- Both ends of a link rank it separately. A peer that can't measure RSSI
  on its peripheral links falls back to age, so the two ends can disagree;
  a link either end evicts is gone. The fleet A/B measures how often
  peripheral RSSI is unknown.
- One `readRemoteRssi` per central link every 10 s: an HCI command, no
  air traffic, and no wait for fragments.
- No frame or advert changes, and the Rust core is unaffected.

## Considered options

- **Seniority.** Keep the longest-up links. No new measurement, but a
  phone keeps whichever links formed first, however weak.
- **Survival.** Keep the oldest links up 60 s. Rejected for the same
  reason.
- **The central tells the peripheral which links to keep.** Both ends
  would agree, but it needs a new record, a spec change to §6 and §7, and
  a model check. Revisit if the ends disagree too often.
- **A second GATT client from the peripheral to read RSSI.** No wire
  change, but two GATT objects on one connection add OEM failure modes.
- **Rounding the quota half down.** 4 of 5 slots stable leaves one slot
  rotating in `FULL`. Floor was chosen, so 5- and 6-slot phones both rotate
  2.
