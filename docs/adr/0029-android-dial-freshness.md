---
status: rejected
date: 2026-10-25
version: cairn-r1
---

# 0029: Keep Android dials open to targets no longer seen

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

The Android radio keeps a dial open until it connects, fails, or reaches
the 10 s timeout of ADR 0025, whether or not the target is still seen.
Spec §10.4 is unchanged.

A freshness check was built (PR #66) and did not add pairs in a fleet A/B.
The radio recorded when it last saw each address it was dialling. Every
500 ms it cancelled a dial that had not connected once the target had gone
unseen for longer than the band's limit ([ADR 0027](0027-android-energy-bands.md)):
2 s at `FULL`, 5 s at `SAVE`, 7 s at `LOW`. A cancelled dial closed its
GATT client and counted as a failed dial.

The A/B ran four 300 s arms (`main`, check, check, `main`) with every phone
forced to `FULL`. The table covers the 21 phones that linked in all four:

| 21 phones | `main` 1 | check 1 | check 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Pairs at 60 s | 35 | 28 | 30 | 32 |
| Pairs at 300 s | 58 | 60 | 61 | 60 |
| Stale cancels | 0 | 316 | 223 | 0 |
| Dial timeouts (10 s) | 107 | 11 | 34 | 199 |
| All failed dials | 211 | 491 | 464 | 353 |

- The check did what it was built for: timeouts fell 80–95 %, and each
  cancel freed its dial place after 2.0–2.5 s.
- Pairs did not move: 60.5 against 59 at 300 s, inside the run-to-run
  spread, and fewer at 60 s.
- In the first check arm, 214 of the 321 cancelled dials had no sighting
  after the dial started, and 22 cancelled addresses connected within 30 s.
  Most targets had gone, but the dial places they held were not what
  limited pairing.
- In the second check arm, `com.android.bluetooth` died on 3 phones, and on
  none in the `main` arms. One (a MediaTek phone) died 1 s after a stale
  cancel closed a pending connection; the other two were not near one.

## Consequences

- Dials to targets that stopped advertising or changed address keep their
  place for up to 10 s, as in ADR 0025.
- Issue 53 must look elsewhere for the plateau: freeing dial places sooner
  does not raise pairs.
- No frame, advert or spec change.

## Considered options

- **Cancel dials to targets unseen for a band limit.** Rejected on the A/B
  results above.
- **A shorter fixed timeout.** Also cancels dials to targets that are still
  advertising but slow to answer, on a crowded channel.
- **A fixed 2 s limit in every band.** Shorter than the scan gap at
  `BALANCED` and `LOW_POWER`, so it would cancel live dials there.
- **Dialling only targets seen in the last scan period.** Every dial already
  starts from a scan result, so this changes nothing; targets go stale after
  the dial starts.

## Open

- iOS (S6): Core Bluetooth's `connect` has no timeout and is cancelled by
  the app. This A/B gives no reason to cancel there on staleness.
