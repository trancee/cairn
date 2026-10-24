# Simultaneous dial delays the first link

Type: task
Status: resolved
Blocked by: none

## Question

Two Android phones that start Cairn at the same moment both scan and dial
each other. In the S2 device demonstration
([issue 32](32-slice-s2.md)), both `connectGatt` calls failed with status 133
on the P10 lite and the Nothing Phone (2). `AndroidRadio` allows one attempt
per address every 2 minutes (spec §10.4,
[ADR 0023](../../../docs/adr/0023-android-ble-adapter.md) §3), so the two
phones retried in step at +120 s and collided again. The link came up only
because the P10 lite's dial failed first.

Decide how to break the symmetry. Candidates: a short randomized first-retry
delay after a failed dial, a deterministic dial tie-break from advertised
data, or yielding the central role when an inbound central connection exists.
Address rotation means the advertising address differs from the address the
peer connects from, so the current `address in peripherals` check does not
detect the inbound link.

Done when two phones started together link within seconds in a repeatable
device test, with a Robolectric test of the retry policy written first.

## Fleet observation (2026-10-24)

Sixteen arm64 phones started together, before the fix. Their 133 failures
fall into two classes:
- **Fast collisions.** Most failures came within 2 s, many with HCI reason
  `0x3e` (connection failed to be established) while the server saw the same
  peer connect: crossed or simultaneous dials.
- **Timeouts.** About 30 s, when the peer never answered.

Separately, slow phones (P10 lite: Bluetooth 4.2, no Data Length Extension,
50 ms connection interval) linked and then closed exactly 5 s later on the
pre-authentication limit of spec §4.4. That is a separate question, about
the 5 s limit, not this issue.

## Decision

Option B (user's choice, 2026-10-24; spec §10.4, OI-28, ADR 0008
amendment):
- The first dial to an address waits a random 0–3 s after the address is
  first seen.
- A dial that fails before link-up is retried after a random 1–5 s, then a
  random 5–15 s.
- A third failure, or a dial that linked, waits 2 min.

`AndroidRadio` gates dials on scan results, not timers, and logs each failed
dial (stage, status, elapsed time, next delay, last two address bytes) under
`CairnRadio`. Robolectric tests: `DialPolicyTest`.

## Result

**Pair test.** Nothing Phone (2) and P10 lite, both force-stopped and
started together, six times. Every trial linked: the UI showed the contact
5–9 s after launch, including UI polling delay. In trial 6 both dials
collided (`CONNECTING` status `0x85` after 277 ms); the retry 1.1 s later
linked.

**Fleet, 15 phones.** The Pixel 6, Pixel 4a, Nokia X20 and Nothing Phone (1)
stayed PIN-locked, and Settings covered Cairn on the P10 lite, so 11 phones
ran Cairn.
- Every one of the 11 formed contacts: 2–8 each, 64 in total. Counts stopped
  growing between +150 s and +240 s.
- Failed dials per phone in 4 min ranged from 0 to 27, mostly `CONNECTING`
  `0x85`. The Moto edge 30 fusion and the Mi Note 3 also reported `0x3e`.

The earlier fleet run is not directly comparable: its zero-contact counts
for the Mi Note 3 and Poco F1 may be artefacts, because `uiautomator dump`
returns nothing on those phones while Cairn's UI is animating.
