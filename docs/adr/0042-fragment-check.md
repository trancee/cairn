---
status: accepted
date: 2026-10-31
version: cairn-r1
---

# 0042: Check every GATT fragment and resend a corrupted write

## Context

[Issue 59](../../.scratch/cairn-r1/issues/59-controller-corrupts-write-payload.md)
found that a 512 B write from an iPhone to the Redmi `2201117TY` sometimes
arrives with a block of its bytes replaced. It happened in 5 of about 60
acceptance runs.

- The iPhone's host gave its controller the right bytes; the Redmi's
  controller gave its host the wrong ones. The damage happens below both
  hosts, and the link-layer CRC didn't catch it.
- The damaged block was 50–215 bytes long and always ended at the last byte
  of the first 251-byte link-layer PDU.
- The protocol's MACs caught every case, so the link closed with
  `authentication` ([ADR 0041](0041-close-reasons.md)). The pairing was
  lost, and the redial often failed with `0x3e` for 15–20 s
  ([issue 58](../../.scratch/cairn-r1/issues/58-crossed-dial-link-loss.md)).

The damage costs availability, not security. A fix should catch it at the
fragment and send that fragment again, before the frame reaches a MAC.

## Decision

1. **Check.** Every GATT fragment ends with a 2-byte check: CRC-16/CCITT-FALSE
   (polynomial `0x1021`, initial value `0xFFFF`, no reflection, no final XOR)
   over the header byte and the body, sent big-endian.
   - A fragment is `header ‖ body ‖ check`. The body is at most
     `min(ATT_MTU − 6, 509)` B, so a fragment still fits ATT's 512 B value
     limit.
   - The check of the ASCII string `123456789` is `0x29B1`.
   - L2CAP CoC frames carry no check (spec §4.3).
2. **Receiving core.** The core verifies and removes the check before
   reassembly. A fragment whose check fails closes the link as `Malformed`.
3. **GATT server.** Both radios check each write to RX before responding.
   A write whose check fails gets ATT error `0x9E` (application error range,
   "fragment check failed"), and the radio drops it. A write without
   response can't be resent, so the radio passes it on and the core closes
   the link. Centrals write `rx` with response.
4. **Central.** A central whose write fails with `0x9E` writes the same
   value again, up to 3 times for one fragment. A fourth failure closes the
   link. Both radios log each rejection and each resend.
5. **Notifications** get no resend, as GATT doesn't acknowledge them. A
   corrupted notification closes the link as `Malformed`. Issue 59 saw no
   corruption in that direction.

The check is not a MAC and adds no security. An attacker can recompute it;
the MACs of spec §5–§7 still authenticate every frame. A random corruption
that passes the check (1 in 65,536) still fails a MAC and closes the link,
as before this ADR.

## Considered options

- **Ignore a trailing padding byte.** The damage spans up to 215 bytes, not
  only the last one, so it would not help.
- **Keep each write within one link-layer PDU** (values of at most 244 B).
  This assumes the damage only hits multi-PDU writes. Issue 59 can't
  confirm that: SE5's 57 B S1 failed too, with no hex dump. It would also
  nearly double the writes for P2.
- **A check per frame.** A bad frame could only be dropped and the link
  closed, which is what the MACs already do.
- **Acknowledge and resend notifications.** This would need a transport
  ack, which spec §4.5 rules out. No corrupted notification was seen.
- **Accept it.** Pairings would keep failing about one time in twelve
  between these two phones.

## Consequences

- Each GATT fragment grows by 2 bytes. A P1 at MTU 517 is still three
  fragments: 512, 512 and 235 B instead of 512, 512 and 229 B.
- A write corrupted by the radio is resent instead of losing the pairing.
- Peers built before this change can't talk to peers built after it. The
  protocol is pre-release, so `cairn-r1` keeps its version, as it did for
  the P0 (0.7) and BUSY (0.9) frames. Every test device needs the new
  build.
- The SDK holds a Kotlin copy of the check for the radios' write gate,
  because the radios answer the write before the core sees it. A JVM test
  checks that copy against the core's fragments.
- Spec 0.22 records OI-43 (§4.3). The amendments go in
  [ADR 0003](0003-ble-transport.md), [ADR 0005](0005-wire-format.md),
  [ADR 0023](0023-android-ble-adapter.md) and
  [ADR 0037](0037-ios-ble-adapter.md).
