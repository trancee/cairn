---
status: rejected
date: 2026-10-25
version: cairn-r1
---

# 0026: Keep the Android radio's fixed rates in a crowd

## Context

The slot budget ([ADR 0025](0025-android-gatt-slot-budget.md)) removed GATT
slot exhaustion: in a 15-phone run, no failed dial fell within 100 ms of a
`Max TCB … reached` line, against 259 on `main`
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)).
Of the 288 dials that still failed:
- 125 timed out after 10 s with no answer;
- 97 ended with status `133` within 2 s, and 18 with `0x3e`. The stack logs
  them as HCI "Connection Failed to be Established": the peer never answered
  the connect request.

The radio dials only from a scan result, so the peer was advertising, and
therefore had a free slot, milliseconds before the dial. These look like
lost connect requests: collisions on the air, or a busy peer controller.

The radio always scans and advertises at `LOW_LATENCY` and dials as soon as
it may. A congestion controller would slow all three when the air is busy,
so fewer requests collide.

## Decision

The Android radio keeps `LOW_LATENCY` advertising and scanning, starts each
dial as soon as the dial rule and slot budget allow, and keeps the 10 s dial
timeout, however crowded the air is.

Two congestion controllers were built (PR #62) and lost on pairs in fleet
A/Bs. Each A/B ran 15 phones × 300 s, back to back against `main`:

| Variant | Pairs at 60 s | Pairs at 300 s | Failed dials |
|---|---:|---:|---:|
| `main` (first A/B) | 33 | 45 | 233 |
| One level from density and failure rate | 17 | 38 | 126 |
| `main` (second A/B) | 32 | 47 | 238 |
| Crowd and channel levels | 26 | 41 | 240 |

- **One level.** Every 5 s, the radio computed:
  - *density*: distinct addresses with a cairn advert in the last 30 s;
  - *failure rate*: the share of the dials ended in the last 60 s that
    failed.

  `BUSY` (density ≥ 4 or failure rate ≥ 25 %) and `CROWDED` (density ≥ 8 or
  failure rate ≥ 50 %) advertised and scanned at `BALANCED` and `LOW_POWER`,
  spaced dial starts by 1 and 2 s, and timed dials out after 5 s. Density 13
  sent every scanning phone to `CROWDED` at the first evaluation. Failed
  dials halved, but discovery slowed more: pairs fell 16 %, and 48 % in the
  first 60 s.
- **Crowd and channel levels.** Density set only the dial gap. The failure
  rate set `BALANCED` advertising and scanning and the 5 s timeout. Failed
  dials did not fall. The 5 s timeout turned 28 slow dials into timeouts,
  and the dial gap, up to 8 s after failures, slowed dialling. Pairs fell
  13 %.

The remaining failures do not track the phone's own advert, scan or dial
rate.

## Consequences

- The radio keeps the behaviour of ADR 0025, and spec §10.4 is unchanged.
- The remaining failed dials stay open in issue 53. An HCI snoop of the
  phones with the most fast 133s would show whether the connect requests
  reach the air.
- Energy bands (issue 53, plan D) must lower duty cycles for battery, not
  congestion. They should expect the same discovery cost.

## Considered options

- **The two controllers above.** Rejected on the A/B results.
- **Continuous AIMD on dial rate and duty cycle.** Not tried. It acts on the
  same signals and rates, and every small step restarts the scan against
  Android's 5 starts per 30 s.
- **Dial only peers seen in the last 2 s.** The radio already dials only
  from a scan result, so the filter would never apply.
