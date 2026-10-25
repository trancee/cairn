---
status: accepted
date: 2026-10-25
version: cairn-r1
---

# 0026: Adapt the Android radio to crowd congestion

## Context

The slot budget ([ADR 0025](0025-android-gatt-slot-budget.md)) removed GATT
slot exhaustion: in a 15-phone run, no failed dial fell within 100 ms of a
`Max TCB … reached` line, against 259 on `main`
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md)).
Pairs rose from 36 to 49 in 300 s. Of the 288 dials that still failed:
- 125 timed out after 10 s with no answer;
- 97 ended with status `133` within 2 s, and 18 with `0x3e`. The stack logs
  them as HCI "Connection Failed to be Established": the peer never answered
  the connect request.

The radio dials only from a scan result, so the peer was advertising, and
therefore had a free slot, milliseconds before the dial. These are lost
connect requests: collisions on the air, or a busy peer controller. They
cluster on a few phones (R38: 53 failures; e9097611: 30).

The radio always scans and advertises at `LOW_LATENCY` (100 ms advertising
interval) and dials as soon as it may. In a crowd, every phone fills the air
at the highest rate. ADR 0025 rejected slower advertising as a substitute for
the budget. It is now a layer on top of it.

Android limits an app to 5 scan starts per 30 s; beyond that, scans stop
without an error. Changing the scan mode needs a restart. Android 14+
already lowers the scan duty cycle while a connect is in progress.

## Decision

The Android radio runs a congestion controller with three levels (spec
§10.4):

- **Signals.** Every 5 s, the radio computes:
  - *density*: distinct addresses whose cairn advert it saw in the last
    30 s;
  - *failure rate*: of the dials that ended in the last 60 s, the share that
    failed, including timeouts. Fewer than 4 ended dials count as 0.
- **Levels.**
  - `CROWDED` if density ≥ 8 or failure rate ≥ 50 %;
  - `BUSY` if density ≥ 4 or failure rate ≥ 25 %;
  - `CLEAR` otherwise.
- **Hysteresis.** The level rises at once. It falls by one level only after
  the lower level has held at every evaluation for 60 s.
- **Actions.**

  | | `CLEAR` | `BUSY` | `CROWDED` |
  |---|---|---|---|
  | Advertising mode | `LOW_LATENCY` | `BALANCED` | `LOW_POWER` |
  | Scan mode | `LOW_LATENCY` | `BALANCED` | `LOW_POWER` |
  | Base gap between dial starts | 0 | 1 s | 2 s |
  | Dial timeout | 10 s | 5 s | 5 s |

  - The dial gap doubles after each failed dial, up to 4 times the base,
    and resets when a dial comes up.
  - While every slot is in use, the radio scans at `LOW_POWER` whatever the
    level: only eviction needs scan results then.
- **Scan restarts.** The radio restarts the scan at most once every 10 s,
  and applies a later mode change when that time has passed. This stays
  within Android's 5 starts per 30 s.
- **Logging.** Each level change logs the level, density and failure rate.

## Consequences

- In a crowd, each phone sends fewer adverts and connect requests. Fewer of
  them should collide, at the cost of slower discovery. The fleet A/B, and a
  900 s run of this change, measure it.
- A quiet phone keeps today's behaviour: `CLEAR` changes nothing.
- A phone in a crowd that tops 8 peers stays `CROWDED`, and scans and
  advertises at `LOW_POWER`, which also saves energy. Energy bands remain a
  separate step (issue 53, plan D).
- A failed dial now frees its slot after 5 s in a crowd, not 10 s. A peer
  that answers slowly on a congested channel may fail once more and be
  retried.

## Considered options

- **Continuous AIMD on dial rate and duty cycle.** Smoother, but harder to
  test, and every small step restarts the scan against the 5-per-30-s quota.
- **Density only.** It ignores the channel: a few peers in heavy RF noise
  stay `CLEAR`.
- **Failure rate only.** It reacts only after dials fail.
- **Dial only peers seen in the last 2 s.** The radio already dials only
  from a scan result, so the filter would never apply.
- **A platform-neutral controller in `:sdk`.** iOS could reuse it, but the
  signals and actions are Android radio settings. iOS copies this ADR in S6.

## Open

- The thresholds are first estimates from one 15-phone fleet.
- iOS (S6).
- Energy bands (issue 53, plan D).
