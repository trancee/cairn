---
status: rejected
date: 2026-10-26
version: cairn-r1
---

# 0032: Keep a full Android radio silent

## Context

[ADR 0025](0025-android-gatt-slot-budget.md) stops advertising while every
GATT slot is in use, and disconnects a device that still connects. Only a
radio's own scan can make room: a full radio that sees a waiting peer
evicts an idle link ([ADR 0030](0030-android-eviction-interval.md)), never
a stable one ([ADR 0031](0031-android-stable-slots.md)).

A full radio is therefore invisible. Two full radios never see each other,
so neither evicts for the other, and parts of the mesh might stay apart.
Stable slots keep phones full for longer. In each 600 s arm of the ADR 0031
fleet A/B, the phones together stopped advertising for being full 500–1000
times.

## Decision

A full Android radio keeps stopping its advert and disconnecting a device
that connects, as in ADR 0025. Spec §10.4 is unchanged.

Two versions of a full radio that stays visible were built (PR #70) and
did not add pairs or connectivity in fleet A/Bs. Both made a device that
connects to a full GATT server apply the eviction rule: close the longest
link idle for ≥ 30 s that is not stable, at most once every 15 s, and
disconnect the device if no link closed.

- **Version 1** advertised at `LOW_POWER` whenever every slot was in use.
- **Version 2** advertised at `LOW_POWER` only while the eviction rule
  could close a link now, and stopped otherwise.

Each A/B ran four 600 s arms (`main`, B, B, `main`) with every phone forced
to `FULL`. The tables cover the phones with logs in all four arms.

Version 1, 27 phones:

| | `main` 1 | B 1 | B 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Links | 179 | 281 | 279 | 173 |
| Pairs by 900 s | 41 | 46 | 43 | 45 |
| Largest live component (mean) | 10.9 | 15.8 | 13.2 | 16.8 |
| Live degree (mean) | 1.40 | 2.13 | 1.43 | 1.94 |
| Evictions for a device that connected | – | 0 | 0 | – |
| Devices disconnected while full | – | 87 | 118 | – |

Version 2, 28 phones:

| | `main` 1 | B 1 | B 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Links | 203 | 187 | 314 | 215 |
| Pairs by 900 s | 53 | 50 | 63 | 58 |
| Largest live component (mean) | 18.8 | 14.8 | 19.9 | 19.1 |
| Live degree (mean) | 1.89 | 1.93 | 2.30 | 2.43 |
| Full spells silent / advertising | 505 / – | 430 / 22 | 499 / 25 | 358 / – |
| Evictions for a device that connected | – | 1 | 1 | – |
| Devices disconnected while full | – | 3 | 23 | – |

- In both runs the difference between `main` and B was smaller than
  between the two B arms.
- A full radio almost never had a link to evict. Most disconnects in
  version 1 came with 3–4 links up and a budget of 5–6: every link was
  stable (⌊¾ × budget⌋), and the other slots held dials in flight or
  connections that never became links. One device was disconnected 20
  times by the same radio.
- Version 2 removed most of the wasted connections, but only about 5 % of
  full spells had an evictable link, and it evicted once per arm.

## Consequences

- Full radios stay invisible to each other. On this fleet, two full radios
  that could make room for each other are rare: full radios are full of
  stable links and dials in flight.
- The radio's logs now name what triggered an eviction (`(scan)`) and log
  each device it disconnects for being full (`slots full; disconnecting`),
  so a later change to either path can be counted.
- No frame, advert or spec change.

## Considered options

- **Always advertise while full** (version 1). Rejected on the A/B above:
  it attracted connections it then refused.
- **Advertise while full only when a link could be evicted** (version 2).
  Rejected on the A/B above: the condition rarely held.
- **Advertise in bursts while full**, such as 2 s every 30 s. Less energy,
  but a peer has to scan during the burst, and the condition above would
  still rarely hold.
- **A room bit in the advert**, so centrals skip a radio with nothing to
  evict. It changes the advert (§10.1) and the threat model's view of it,
  for a case that is rare.

## Open

- iOS (S6): iOS sets no advertising interval, keeps advertising whatever
  its links, and has no call to disconnect a device that connected to its
  GATT server. Its full-radio behavior belongs to the iOS budget
  (ADR 0025, open item S6).
