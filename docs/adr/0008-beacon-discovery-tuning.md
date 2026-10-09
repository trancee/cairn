---
status: accepted
date: 2026-10-05
version: cairn-r1
---

# 0008: Beacon and discovery tuning

## Context

[ADR 0003](0003-ble-transport.md) fixes symmetric discovery: a fixed service UUID, the beacon in Android service data or in a rotating iOS foreground UUID, and a `beacon` characteristic read as fallback. [ADR 0005](0005-wire-format.md) fixes the beacon (8 B, one device beacon key shared with contacts) and the doorbell (an 8 B tag in the beacon slot).

Platform facts from the [background BLE research](../research/2026-10-05-android-ios-background-ble.md):
- Android background scanning needs a `ScanFilter` and a `PendingIntent`.
- iOS slows scanning in the background and places background service UUIDs in the overflow area.
- Apps cannot control address rotation.
- iOS grants about 10 s per background wake.

The [threat model](../spec/threat-model.md) requires the beacon to be unlinkable against a tracking adversary (A6) and availability to be best effort.

## Decision

**Duty cycle by app state:**

| State | Android advertise | Android scan | iOS |
|---|---|---|---|
| Foreground (chat open) | `LOW_LATENCY` | `LOW_LATENCY`, filtered on the fixed UUID | Advertise the fixed UUID plus the rotating beacon UUID; scan the fixed UUID without duplicates |
| Background, active (pending queued messages or a contact seen in the last 10 min) | `BALANCED` | `LOW_POWER`, filtered, `PendingIntent` | Advertise the fixed UUID (overflow); scan the fixed UUID; state restoration on |
| Background, idle | `LOW_POWER` | Filtered `PendingIntent` scan only | As above |

**Beacon window:**
- 5 min, with ±1 window of tolerated clock skew. The receiver precomputes windows `{w−1, w, w+1}` for every contact.
- At each window boundary, plus 0–30 s of random jitter, the advertising set is stopped and restarted, so the beacon and (where the stack allows) the advertising address change together.

**Connect policy:**
- A peer showing the fixed UUID with no beacon or an unknown one is connected to for a `beacon` read **only if** there is something to send, or some contact hasn't been seen for at least 10 min.
- **Rate limits:** at most one attempt per address every 2 min; after 3 non-matching reads from an address, stop trying it for 1 h.

**Idle sync:**
- Two contacts with nothing queued Resume only if their last Resume was at least 6 h ago or a PQ epoch is due.
- This keeps PQ post-compromise recovery working without constant connections.

**Doorbell cadence:**
- An Android advertiser with pending queued messages rotates the advertising payload once per second, round-robin over the beacon and up to **8** doorbells per cycle. Further doorbells wait for the next cycle.
- iOS does not ring (ADR 0005).

**Beacon-key rotation:**
- When a contact is removed, the device derives a fresh beacon key and stops using the old one immediately. There is **no overlap**.
- The remaining contacts learn the new key in a record at their next Resume.
- Until then, discovery runs the other way: the rotating device still recognizes their beacons, which are unchanged, and connects and Resumes. Fixed-UUID connects also reach them through the connect policy.

**Battery target:**
- Background idle uses at most **2 % of battery per 24 h** on the device-lab core matrix.
- It is measured relatively, per the [energy methodology](../research/2026-10-05-energy-measurement-methodology.md).
- Foreground has no budget.

## Alternatives considered

- **A 15 min window.** Fewer recomputations, but a longer linkable interval for A6.
- **Always connecting to unknown fixed-UUID peers.** Drains battery and spams strangers with connections; observers could count `cairn` users more easily.
- **Never Resuming when idle.** Post-compromise recovery and PQ epochs would stall for silent contacts.
- **A 7-day overlap of the old beacon key.** The removed contact could keep tracking the device for 7 days, which defeats the point of rotating.
- **A continuous `LOW_LATENCY` scan in the background.** Android throttles it and it drains the battery.

## Risks

- **Address rotation.** The advertising address may not rotate together with the beacon on some stacks, leaving the beacon and address linkable (Becker et al.). Verify in the device test lab per vendor.
- **iOS background discovery.** Fixed-UUID-only advertising from a backgrounded iPhone may not reach Android at all (ADR 0003). The connect policy then relies on iOS as central.
- **Missed messages.** Rate limits can delay delivery between a contact that hasn't learned the new beacon key and an iOS device in the background.
- **Battery target.** The 2 %/24 h figure is a target. OEM power policies (for example Nokia Doze sensitivity) may break it.
- **Clock skew.** Skew beyond ±5 min stops beacon matching; recovery is by fixed-UUID connect.

## Migration

This is the first version. These parameters are policy inside the core and SDK; changing them needs no wire change and only an amendment to this ADR.

## Amendments

2026-10-05, from spec consolidation ([`cairn-r1` spec §13](../spec/cairn-r1.md#13-consolidation-issues-resolved-2026-10-05)):
- The rotated beacon key travels in `BEACON_KEY` records until `BEACON_ACK` (OI-3).
- PQ epoch cadence: ≥ 10 Resumes or ≥ 24 h since the last completed epoch (OI-11).
