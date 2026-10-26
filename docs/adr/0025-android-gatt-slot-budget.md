---
status: accepted
date: 2026-10-25
version: cairn-r1
---

# 0025: Budget Android GATT connection slots

## Context

In a 12–15 phone fleet, about half of all phone pairs never connected
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)).
About 80 % of failed dials ended with status `133`, most of them within
milliseconds, before anything was sent over the air.

The Android stack keeps one GATT link record (TCB) per connected or
connecting device, for both GATT roles. It allocates the record when a
connect starts. The table holds `GATT_MAX_PHY_CHANNEL` entries:
- 7 in AOSP up to Android 14;
- from Android 15, the system property
  `bluetooth.core.le.max_number_of_concurrent_connections`, at least 8 and
  at most 16 (`gatt_get_max_phy_channel()`).

On the fleet, `dumpsys bluetooth_manager` showed 8, 10 and 16 on the phones
that print it. When the table is full, `connectGatt` fails with `133` at
once, and incoming links are dropped "due to out of resources".

In run `ev1`:
- 274 of 443 fast `133` failures fell within 100 ms of a
  `Max TCB for gatt_if … reached` log line. That is every fast `133` on the
  five phones whose stack logs the tag.
- 30 incoming links were dropped.
- The slots were not held by sessions. One phone hit the limit 78 times with
  about one link up; the rest were its own dials and incoming connections
  that had not subscribed yet.

The S2 radio (ADR 0023) dials every address it sees, with no cap. It
advertises as connectable whatever its load, and never closes an
established link while both phones stay in range. With 14 phones, each
wants 13 links, so the tables fill with dials and half-open links. At most
about 49 of 91 pairs fit at once, and a phone that is full stays full.

The failures do not follow API level: phones on API 26, 28, 29, 31 and 34
hit the limit. Phones report no usable battery wear, so wear is not an
input here.

## Decision

On Android, the radio budgets its GATT connections (spec §10.4):

- **Slots.** The radio counts every dial that has not come up, every central
  link and every device connected to its GATT server, subscribed or not.
  Its budget is 5 slots on API ≤ 34 and 6 on API 35+. That is the AOSP
  minimum of 7 or 8 less 2, which leaves room for a connection that races
  the budget and for other apps.
- **Pending dials.** At most 1 dial in flight on API ≤ 28, where the stack
  runs one LE connect at a time, and at most 2 otherwise.
- **Dial timeout.** A dial that has not come up within 10 s is closed and
  counts as a failed dial (§10.4 retries). Otherwise a stack waits up to
  30 s, holding a slot.
- **Who dials.** Android advertises service data (service UUID ‖ beacon) as
  spec §10.1 specifies. A peer that advertises a beacon is dialled only if
  the radio's own advertised beacon is lower, comparing the 8 bytes as an
  unsigned big-endian number; equal beacons dial. A peer that advertises
  only the service UUID, such as iOS in the background, is dialled as
  before. This halves the dials in a crowd.
- **Beacon rotation.** The advertising set restarts at every 5-minute window
  boundary plus 0–30 s of random jitter (spec §10.1), and picks up the new
  beacon. Near a boundary the two phones may compare different windows, so
  both or neither may dial. That lasts at most until the second phone
  rotates.
- **Advertising.** The radio advertises only while it has a free slot, and
  stops while every slot is in use. A device that still connects to a full
  GATT server is disconnected at once.
- **Eviction.** A full radio that sees an advertising address with no link,
  connection or dial, and no dial back-off, closes its longest-idle link. A link is
  idle when it has carried no fragment for 30 s. The radio evicts at most
  once every 60 s. The freed slot lets it advertise or dial again, and the
  core Resumes the evicted contact later. A false positive, such as a
  linked peer seen at a rotated address, costs one idle link per minute,
  which in a crowd is the rotation wanted anyway.

## Consequences

- A phone in a crowd holds at most 5–6 links, and each pair dials one way.
  The link graph stays connected, and coverage builds up as idle links
  rotate.
- Fewer dials should fail with fast `133`. A fleet A/B against `main`
  measures it.
- Advertising carries the beacon, so contacts can match a beacon before
  connecting (ADR 0003). The threat model already assumes it (A1, A6). Each
  restart takes a new advertising set, which on most stacks takes a new
  resolvable private address. ADR 0008's address-rotation risk still
  needs a per-vendor check.
- An idle link may close while both phones stay in range. Messages queued
  later wait for a new link; the core Resumes on it.

## Considered options

- **No cap, slower advertising or scanning.** Advertising collisions are
  about 7 % at this density, so slowing them gains little, and it does not
  free slots.
- **Close links after 30 s without frames.** This is simpler, but it churns
  links even when no other phone is waiting.
- **Never close links.** A full phone stays full, and later arrivals never
  get in.
- **Drop the dial rule and keep only the caps.** Both phones of a pair would
  still dial each other, so two slots are spent for each link while the
  dials are in flight.
- **Lower budgets for older API levels or older phones.** Fleet data does not
  support it: the limit hits API 26 to 34 alike. API ≤ 28 gets one pending
  dial only because its stack serializes connects.

## Open

- iOS budgets (S6). CoreBluetooth documents no connection limit, and its
  connects never time out.
- A congestion controller on top of the budget was tried and rejected
  ([ADR 0026](0026-android-congestion-levels.md)).

## Amendments

2026-10-25, from [ADR 0027](0027-android-energy-bands.md) (OI-33): in energy
band `LOW` the budget is 3 slots.

2026-10-25, from [ADR 0028](0028-android-extended-advertising.md) (OI-34): a
radio that advertises extended dials a peer it sees through a legacy advert
whatever their beacons.

2026-10-26, from [ADR 0030](0030-android-eviction-interval.md) (OI-35): a
full radio evicts at most once every 15 s.

2026-10-26, from [ADR 0031](0031-android-stable-slots.md) (OI-36): eviction
skips up to ⌊¾ × budget⌋ stable links, the strongest by RSSI.

2026-10-26, from [ADR 0032](0032-android-full-advertising.md) (OI-37): a
full radio advertises at `LOW_POWER`, and evicts an idle link for a device
that connects to it instead of disconnecting it.
