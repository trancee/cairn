---
status: accepted
date: 2026-10-26
version: cairn-r1
---

# 0030: Evict an idle Android link every 15 s

## Context

[ADR 0025](0025-android-gatt-slot-budget.md) gives an Android radio 5 or 6
slots. A full radio stops advertising, and when it sees a waiting peer it
closes its longest link idle for 30 s, at most once every 60 s.

The fleet A/B of [ADR 0029](0029-android-dial-freshness.md)
([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md))
logged each radio's links. In the two `main` runs, on the 21 phones that
linked in every run:

- The radios evicted 59 and 63 times, and about 25 pairs formed after the
  first 60 s.
- While a phone's open links filled its slots (580 and 229 phone-seconds),
  93–100 % of the time it had a link idle for 30 s that the 60 s interval
  kept it from evicting. Dials in flight and devices connected to the GATT
  server also take slots but are not logged, so the radios were full for
  longer than this.

Once the slots fill, the 60 s interval sets how fast a phone meets new
peers.

## Decision

The interval between two evictions is 15 s (spec §10.4). The rest of ADR
0025 is unchanged: only a link idle for 30 s is evicted, and only for a
waiting peer seen advertising with no link, dial or back-off.

## Consequences

- A full phone can take in a new peer every 15 s instead of every 60 s.
- Idle links close sooner in a crowd. A message queued for an evicted
  contact waits for a new link, and the core Resumes on it, as ADR 0025
  already accepts.
- A false positive, such as a linked peer seen at a rotated address, can
  close one idle link every 15 s.
- No frame or advert changes.
- A fleet A/B confirmed the gain (below). Bluetooth on one OnePlus phone
  (CPH2359, extended advertising) restarted in both 15 s runs and in none
  of six other runs; once after the controller timed out enabling an
  advertising set. Its advertising stopped about twice as often. One phone
  is not enough to tell whether the extra advertising restarts cause it.

## Fleet A/B

Four 300 s runs (`main`, 15 s, 15 s, `main`), every phone forced to band
`FULL`, on the 23 phones that linked in all four:

| 23 phones | `main` 1 | 15 s 1 | 15 s 2 | `main` 2 |
|---|---:|---:|---:|---:|
| Pairs at 60 s | 31 | 33 | 39 | 32 |
| Pairs at 180 s | 43 | 52 | 60 | 45 |
| Pairs at 300 s | 60 | 63 | 71 | 51 |
| Evictions | 61 | 141 | 167 | 58 |
| Links up | 267 | 577 | 529 | 370 |
| Failed dials | 286 | 422 | 427 | 341 |
| Bluetooth restarts | 0 | 2 | 2 | 1 |

- Pairs at 300 s rose 21 % (67 against 55.5), and at 180 s 28 %. Both 15 s
  runs beat both `main` runs.
- Evictions rose 2.6 times and links up 1.7 times; failed dials rose 34 %.
- One phone (7XHEI…, MediaTek) restarts Bluetooth in `main` runs as well.

## Considered options

- **Interval 10 s and idle time 10 s.** More churn, including links that
  carry Resumes or epochs with pauses longer than 10 s.
- **No interval.** A burst of sightings could close every idle link at
  once.
- **Interval per energy band.** `SAVE` and `LOW` would trade pairing speed
  for fewer reconnects. Not measured; all A/Bs so far run at `FULL`.
