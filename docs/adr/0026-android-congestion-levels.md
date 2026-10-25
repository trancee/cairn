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

The Android radio tracks two congestion levels (spec §10.4): the *crowd*
level, from how many peers are near, and the *channel* level, from how many
dials fail.

- **Signals.** Every 5 s, the radio computes:
  - *density*: distinct addresses whose cairn advert it saw in the last
    30 s;
  - *failure rate*: of the dials that ended in the last 60 s, the share that
    failed, including timeouts. Fewer than 4 ended dials count as 0.
- **Levels.**

  | Level | Crowd: density | Channel: failure rate |
  |---|---|---|
  | `CROWDED` | ≥ 8 | ≥ 50 % |
  | `BUSY` | ≥ 4 | ≥ 25 % |
  | `CLEAR` | otherwise | otherwise |

- **Hysteresis.** Each level rises at once. It falls by one level only after
  the lower level has held at every evaluation for 60 s.
- **Actions.**
  - The crowd level sets the base gap between dial starts: 0 at `CLEAR`,
    1 s at `BUSY`, 2 s at `CROWDED`. The gap doubles after each failed dial,
    up to 4 times the base, and resets when a dial comes up.
  - At channel level `CLEAR` the radio advertises and scans at `LOW_LATENCY`
    and dials time out after 10 s. At `BUSY` and `CROWDED` it advertises and
    scans at `BALANCED` and dials time out after 5 s.
  - While every slot is in use, the radio scans at `LOW_POWER` whatever the
    level: only eviction needs scan results then. No level uses `LOW_POWER`
    otherwise.
- **Scan restarts.** The radio restarts the scan at most once every 10 s,
  and applies a later mode change when that time has passed. This stays
  within Android's 5 starts per 30 s.
- **Logging.** Each level change logs both levels, the density and the
  failure rate.

## Consequences

- In a crowd, each phone spaces its connect requests. Fewer of them should
  collide, while discovery keeps its pace until dials actually fail. The
  fleet A/B, and a 900 s run of this change, measure it.
- A quiet phone keeps today's behaviour: `CLEAR` changes nothing.
- Discovery slows only on a failing channel, and only to `BALANCED`. Energy
  bands remain a separate step (issue 53, plan D).
- A failed dial now frees its slot after 5 s on a failing channel, not 10 s.
  A peer that answers slowly there may fail once more and be retried.

## Considered options

- **Continuous AIMD on dial rate and duty cycle.** Smoother, but harder to
  test, and every small step restarts the scan against the 5-per-30-s quota.
- **One level from both signals, with `LOW_POWER` advertising and scanning
  at `CROWDED`.** In the first A/B (15 phones × 300 s, 2026-10-25), density
  13 sent every scanning phone to `CROWDED` at the first evaluation. Failed
  dials fell from 233 to 126, but pairs fell from 45 to 38, and from 33 to 17
  in the first 60 s: discovery slowed more than fewer collisions gained.
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
