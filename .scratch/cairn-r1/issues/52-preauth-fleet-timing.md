# Pre-auth links time out under fleet load

Type: task
Status: needs-triage
Blocked by: none

## Question

Is the 5 s pre-auth limit (spec §4.4) too tight on Android, or do links die
for other reasons? This is plan B from the S2 fleet test
([issue 32](32-slice-s2.md)).

## Method

The `CairnRadio` link trace
([ADR 0023](../../../docs/adr/0023-android-ble-adapter.md) §3) records every
link's up, fragment in/out and down. It ran on 12 USB phones (API 26–36) for
180 s, twice: `fleet1`, and `fleet2` with wall-clock timestamps corrected per
phone to within ±50 ms. Both runs used the dial policy of
[issue 50](50-simultaneous-dial-backoff.md) and the AWS-LC fix of
[issue 51](51-aws-lc-jitter-abort.md); no phone crashed. A single pair
(Nothing Phone 2 and P10 lite, nothing else running) is the control. In
fleet2, each central P0 was matched to the peripheral that received it.

## Results

| | Pair (control) | Fleet1 | Fleet2 |
|---|---|---|---|
| Links | 1 | 178 | 162 |
| Reached DATA | 1 | 53 | 53 |
| Pairing complete (P4), median / max | 0.74 s | 1.87 / 4.31 s | 1.39 / 4.47 s |
| First S2 or DATA, median / p90 / max | 1.07 s | 2.14 / 3.80 / 5.07 s | 1.63 / 3.81 / 4.88 s |
| Closed with no frame, under 5 s | 0 | 81 | 84 |
| Failed dials (mostly `CONNECTING` 0x85) | 6 | 222 | 232 |

Fleet2 gaps between P1/P2 fragments on the receiving side: median 143 ms,
p90 487 ms, max 1979 ms. In the control, each fragment arrives within 80 ms.

## Findings

1. **Refusals are explicit, not stalls.** With a pairing in flight, the core
   closes a new link at once (spec §5.6): the central closes before sending
   P0, and the peripheral closes on receiving P0. This explains the 81–84
   links that closed with no frames.
2. **A refusal by a peripheral doesn't reach the central.** The peripheral's
   close is `BluetoothGattServer.cancelConnection`, which doesn't drop a
   connection the remote central opened. In both matched fleet2 refusals, the
   peripheral closed 67 ms and 199 ms after link-up. The central kept waiting
   and closed at its own 5 s deadline, about 4.9 s later. In that time the
   central's own pairing (P0 sent) is in flight, so it refuses every other
   peer too. Eight more P0s reached no logged peripheral link, which fits
   writes arriving after the peripheral had already removed the link.
3. **Fragments are slow under load.** The radio requests neither
   `CONNECTION_PRIORITY_HIGH` nor the 2M PHY. With several links per phone,
   512 B notifications reached the central up to 2 s apart. One pairing's P1
   took from 53 ms to 4.83 s to arrive. Pairings that reached P2 or P3 by
   4.2–4.6 s then hit the 5 s limit.
4. The 5 s limit isn't the root cause. The pair finishes in about 1.1 s.
   Under load the p90 is 3.8 s, driven by findings 2 and 3.

Possibly related: spec §5.6 keeps a refused or failed address back for 1 h,
which may explain why contact counts plateau after about 150 s. Not measured
yet.

## Decision

- **Finding 3:** the central requests high connection priority and the 2M
  PHY for the first 10 s of each link
  ([ADR 0023](../../../docs/adr/0023-android-ble-adapter.md) §3).
- **Finding 2:** option A, spec OI-29 (draft 0.9). A refuses every P0 with
  a 1 B BUSY frame (PAIR step 5) and waits for B to close. B closes on
  BUSY with no back-off, and the attempt isn't counted (user's choice). A
  refusal at the admission limits is a BUSY too.
- **5 s limit:** unchanged until a fleet run with both fixes is measured.
