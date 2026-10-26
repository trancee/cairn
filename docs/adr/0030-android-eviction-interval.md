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
logged each radio's slot state. In the two `main` runs, on the 21 phones
that linked in every run:

- Most phones had every slot in use for 270–300 s of each 300 s run.
- Of the 3596 and 4348 phone-seconds spent full, 63–82 % had a link idle
  for 30 s while the 60 s interval forbade eviction. 5–12 % could have
  evicted but saw no waiting peer, and about 20 % had only links under 30 s
  old.
- The radios evicted 59 and 63 times, and about 25 pairs formed after the
  first 60 s.

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
- A fleet A/B against `main` measures pairs, evictions and link churn.

## Considered options

- **Interval 10 s and idle time 10 s.** More churn, including links that
  carry Resumes or epochs with pauses longer than 10 s.
- **No interval.** A burst of sightings could close every idle link at
  once.
- **Interval per energy band.** `SAVE` and `LOW` would trade pairing speed
  for fewer reconnects. Not measured; all A/Bs so far run at `FULL`.
