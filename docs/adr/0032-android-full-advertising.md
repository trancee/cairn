---
status: accepted
date: 2026-10-26
version: cairn-r1
---

# 0032: A full Android radio keeps advertising

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

A full radio keeps advertising, and makes room for a device that connects
(spec §10.4):

- **Advertising.** While every slot is in use, the radio advertises at
  `LOW_POWER`, whatever its energy band ([ADR 0027](0027-android-energy-bands.md)),
  and still rotates the advert with the beacon. When a slot frees it goes
  back to the band's mode.
- **A device that connects to a full GATT server** makes the radio apply
  the eviction rule for it: close the longest link idle for ≥ 30 s that is
  not stable, at most once every 15 s. If a link closes, the device keeps
  its connection; otherwise the radio disconnects it at once. A device the
  radio is dialling still costs no slot.

The radio logs when it slows and when it resumes the band's mode. Each eviction
log names its trigger, `(scan)` or `(connect)`, and a device disconnected because
nothing could be evicted is logged too, so fleet runs can count the new path.

## Consequences

- Full radios see each other, so either can make room for the other, and
  the rotating slots refill from the whole crowd.
- A full radio with nothing to evict disconnects devices that connect to
  it. Their dials fail and back off (spec §10.4): 1–5 s, then 5–15 s, then
  2 min.
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
