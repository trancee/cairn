---
status: accepted
date: 2026-10-25
version: cairn-r1
---

# 0027: Lower the Android radio's duty cycles by battery band

## Context

The Android radio advertises and scans at `LOW_LATENCY` whenever it runs:
one advert every 100 ms, and a scan window that covers the whole scan
interval. It holds up to 5 or 6 GATT slots
([ADR 0025](0025-android-gatt-slot-budget.md)). That is the fastest
discovery Android offers, and the most expensive. A phone running low on
battery pays the same as one on a charger.

[ADR 0026](0026-android-congestion-levels.md) measured the cost of slower
modes in a 15-phone fleet: `LOW_POWER` advertising and scanning cut pairs
in 300 s by 16 %, and by 48 % in the first 60 s. Slower modes are therefore
worth it only where energy matters more than discovery speed.

Battery wear is no input: every fleet phone reports health "good", and
`charge_full` equals the design value where it can be read at all
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)).

## Decision

The Android radio picks an energy band from the battery (spec §10.4):

- **Inputs.**
  - the battery level and plug state, from the sticky
    `ACTION_BATTERY_CHANGED` broadcast;
  - the system Battery Saver, from `PowerManager.isPowerSaveMode` and
    `ACTION_POWER_SAVE_MODE_CHANGED`.
- **Bands.**
  - `FULL` while plugged in;
  - otherwise `LOW` below 20 %;
  - otherwise `SAVE` at 50 % or less, or while Battery Saver is on;
  - otherwise `FULL`.
- **Hysteresis.** A band rises by level only 5 points above its threshold:
  `LOW` ends at 25 %, and `SAVE` set by level ends above 55 %. Plugging in
  and Battery Saver act at once.
- **Actions.**

  | | `FULL` | `SAVE` | `LOW` |
  |---|---|---|---|
  | Advertising and scan mode | `LOW_LATENCY` | `BALANCED` | `LOW_POWER` |
  | Slots | 5 or 6 (ADR 0025) | 5 or 6 | 3 |

  - Links above a lowered slot cap stay up. The radio stops advertising and
    dialling until it is below the cap, and eviction (ADR 0025) closes idle
    links one at a time as peers wait.
  - The radio restarts the scan at most once every 10 s, and applies a
    later band change when that time has passed. This stays within
    Android's 5 starts per 30 s, which Battery Saver toggling could
    otherwise exceed.
- **Logging.** Each band change logs the band, level, plug state and Battery
  Saver.

## Consequences

- A phone on a charger, or above 50 %, behaves as today.
- In `SAVE` and `LOW`, discovery slows as measured in ADR 0026, and in
  `LOW` the phone keeps at most 3 links.
- The fleet phones are on chargers, so they stay `FULL`. A fleet run can
  force a band with `adb shell dumpsys battery unplug` and
  `dumpsys battery set level`, and reset it with `dumpsys battery reset`.
- The energy saved per band is measured from `dumpsys batterystats`, not
  from the fleet's pair count.

## Considered options

- **Two bands (`SAVE` below 30 % or Battery Saver).** Coarser: no step
  between `BALANCED` and the cheapest modes.
- **Four bands, with a critical band at 10 %.** More states to test for one
  more step, with no evidence that it matters.
- **Only advertising and scan modes, no slot cap.** Each link costs
  connection events, so a low phone should keep fewer.
- **Scan windows (10 s on, 20 s off).** Each window costs a scan start,
  which runs into Android's 5 starts per 30 s.
- **Foreground or background as an input.** Android already throttles
  background scans; the band follows energy only.

## Open

- iOS (S6).
- The thresholds are first estimates.
