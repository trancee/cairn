# Beacon and discovery tuning

Type: grilling
Status: resolved
Blocked by: 15

## Question

What advertising/scan settings, beacon-window length and rotation rules does `cairn` use per app state (foreground, background, screen off, iOS backgrounded/terminated)? Decide: the Android advertise mode/interval and scan mode per state, the iOS scan options, the 5-minute window vs a shorter one, alignment of beacon rotation with the OS address rotation where possible, how the device beacon key is rotated after a contact is removed, the doorbell alternation cadence, and battery budgets to verify in the device test lab.

## Comments

## Answer

Recorded in [ADR 0008: Beacon and discovery tuning](../../../docs/adr/0008-beacon-discovery-tuning.md). The user accepted all recommendations on 2026-10-05:
- **Duty cycle** in three states: foreground, background-active and background-idle.
- **Beacon window:** 5 min, with advertising restarted at each boundary plus jitter.
- **Connect policy:** purpose-driven and rate-limited (once per 2 min per address; back off 1 h after 3 misses).
- **Idle Resume:** after 6 h, or when a PQ epoch is due.
- **Doorbells:** up to 8 per cycle, round-robin.
- **Beacon-key rotation:** no overlap.
- **Battery target:** at most 2 % per 24 h when idle.
