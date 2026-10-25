---
status: accepted
date: 2026-10-25
version: cairn-r1
---

# 0029: Cancel Android dials to targets no longer seen

## Context

[ADR 0025](0025-android-gatt-slot-budget.md) caps the dials in flight at 1
or 2 and fails a dial that has not come up within 10 s. With extended
advertising ([ADR 0028](0028-android-extended-advertising.md)), the central's
controller keeps a create connection pending until the target answers an
`AUX_CONNECT_REQ`. A target that stopped advertising answers none.

An HCI snoop
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md))
found two ways a target stops:

- Its slots are full, so it stops advertising (ADR 0025).
- Android rebuilds its advertising set with a new address after a connection
  attempt or at a beacon window. The old address never comes back.

In the ADR 0028 A/B, dial timeouts rose from 52 and 11 to 108 and 91 per
300 s run. Each one holds a dial place and a GATT slot for 10 s, so the
radio cannot dial peers that are advertising.

The radio scans the whole time it dials. A target that still advertises is
seen again within one scan period: continuously at `LOW_LATENCY`, within
about 3 s at `BALANCED` (1 s of every 4 s) and 4.6 s at `LOW_POWER` (0.5 s
of every 5 s).

## Decision

The Android radio records when it last saw each address it is dialling
(spec §10.4). While the dial has not connected, it checks every 500 ms and
cancels the dial once the target has gone unseen for longer than the
band's limit ([ADR 0027](0027-android-energy-bands.md)):

| Band | Scan mode | Limit |
|---|---|---:|
| `FULL` | `LOW_LATENCY` | 2 s |
| `SAVE` | `BALANCED` | 5 s |
| `LOW` | `LOW_POWER` | 7 s |

- The limit is read at each check, so a band change applies to dials in
  flight.
- A cancelled dial closes its GATT client and counts as a failed dial: the
  retry delays of §10.4 apply. It is logged as stale, with the time since
  the target was last seen.
- The check stops once the link connects. Android stops advertising a set
  once it connects, so a connected target is not seen again.
- The 10 s dial timeout stays as the bound for a target that is seen but
  does not answer.

## Consequences

- A dial to a target that stopped advertising or changed address frees its
  place after about 2 s at `FULL`, instead of 10 s.
- The new address of a rotated target is a new address to the radio: it is
  dialled after the 0–3 s first-dial spread.
- A stack that pauses scan results while a connection is pending would see
  every dial go stale. The fleet A/B checks for this before the limit is
  relied on.
- No frame or advert changes.

## Considered options

- **A shorter fixed timeout.** Also cancels dials to targets that are still
  advertising but slow to answer, on a crowded channel.
- **A fixed 2 s limit in every band.** Shorter than the scan gap at
  `BALANCED` and `LOW_POWER`, so it would cancel live dials there.
- **Dialling only targets seen in the last scan period.** Every dial already
  starts from a scan result, so this changes nothing; targets go stale after
  the dial starts.

## Open

- iOS (S6): Core Bluetooth's `connect` has no timeout and is cancelled by
  the app, so the same rule may apply there.
