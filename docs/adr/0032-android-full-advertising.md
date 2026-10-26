---
status: accepted
date: 2026-10-26
version: cairn-r1
---

# 0032: A full Android radio advertises while it could evict

## Context

[ADR 0025](0025-android-gatt-slot-budget.md) stops advertising while every
GATT slot is in use, and disconnects a device that still connects. Only a
radio's own scan can make room: a full radio that sees a waiting peer
evicts an idle link ([ADR 0030](0030-android-eviction-interval.md)), never
a stable one ([ADR 0031](0031-android-stable-slots.md)).

A full radio is therefore invisible. Two full radios never see each other,
so neither evicts for the other, and their rotating slots refill only from
phones that still have a free slot. Parts of the mesh can stay apart.
Stable slots keep phones full for longer. In each 600 s arm of the ADR 0031
fleet A/B, the phones together stopped advertising for being full 500–1000
times.

## Decision

A full radio advertises while it could make room, and makes room for a
device that connects (spec §10.4):

- **Advertising.** While every slot is in use and the eviction rule below
  could close a link now, the radio advertises at `LOW_POWER`, whatever its
  energy band ([ADR 0027](0027-android-energy-bands.md)), and still rotates
  the advert with the beacon. While it could not, because every link is
  stable, too recent or active, or an eviction was under 15 s ago, it stops
  advertising, as before, and starts again when a link becomes evictable.
  When a slot frees it goes back to the band's mode.
- **A device that connects to a full GATT server** makes the radio apply
  the eviction rule for it: close the longest link idle for ≥ 30 s that is
  not stable, at most once every 15 s. If a link closes, the device keeps
  its connection; otherwise the radio disconnects it at once. A device the
  radio is dialling still costs no slot.

The radio logs when it stops, slows and resumes the band's mode. Each eviction
log names its trigger, `(scan)` or `(connect)`, and a device disconnected because
nothing could be evicted is logged too, so fleet runs can count the new path.

## Consequences

- Full radios that could evict see each other, so either can make room for
  the other, and the rotating slots refill from the whole crowd.
- A full radio with nothing to evict stays silent, so it attracts no dials
  that it would refuse. A device that connects anyway, having seen an older
  advert or because a link became active, is disconnected; its dials fail
  and back off (spec §10.4): 1–5 s, then 5–15 s, then 2 min.
- A link that becomes active again while the radio advertises full keeps it
  advertising until the next budget, so a few devices may still be refused.
- A full radio advertises at about 1 Hz, up from silence: a small cost
  compared with the links it holds.
- No frame or advert changes, and the Rust core is unaffected.
- Android only. iOS sets no advertising interval, keeps advertising
  whatever its links, and has no call to disconnect a device that connected
  to its GATT server, so its full-radio behavior belongs to the iOS budget
  (ADR 0025, open item S6).

## Considered options

- **Advertise in bursts while full**, such as 2 s every 30 s. Less energy,
  but a peer has to scan during the burst, and the two timers interact.
- **A room bit in the advert**, so centrals skip a radio with nothing to
  evict. Fewer wasted connections, but it changes the advert (§10.1) and
  the threat model's view of it.
- **Keep stopping.** Full radios stay invisible to each other.
- **Always advertise while full** (this ADR's first version). Rejected by
  the fleet run below: the radio was full mostly with stable links and dials
  in flight, so it could not evict, and refused every device that connected.

## Fleet result

27 of 29 phones with logs in all four 600 s arms (A = `main`, B = always
advertise while full, first version of this ADR):

| | A₁ | B₁ | B₂ | A₂ |
|---|---:|---:|---:|---:|
| Links | 179 | 281 | 279 | 173 |
| Median link | 35 s | 31 s | 5 s | 50 s |
| Evictions after a scan | 38 | 48 | 46 | 35 |
| Evictions for a device that connected | – | 0 | 0 | – |
| Devices refused while full | – | 87 | 118 | – |
| Pairs by 900 s | 41 | 46 | 43 | 45 |
| Largest live component (mean) | 10.9 | 15.8 | 13.2 | 16.8 |
| Live degree (mean) | 1.40 | 2.13 | 1.43 | 1.94 |

The difference between A and B was smaller than between the two B arms.
Most refusals came with 3–4 links up and a budget of 5–6: every link was
stable (⌊¾ × budget⌋), and the other slots held dials in flight or
connections that never became links. One device was refused 20 times by
the same radio. Hence the condition in the decision.
