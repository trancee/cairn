---
status: proposed
date: 2026-10-30
version: cairn-r1
---

# 0041: Say why the core closed a link

## Context

The core closes a link with `Disconnect { link }`
([ADR 0022](0022-cairn-core-contract.md)). Both radios log `close requested`
before the link goes down ([ADR 0023](0023-android-ble-adapter.md),
[ADR 0037](0037-ios-ble-adapter.md)). They don't log why.

About twenty paths in the core end in `Disconnect`. In the acceptance runs
of [issue 58](../../.scratch/cairn-r1/issues/58-crossed-dial-link-loss.md),
an iPhone closed a link 15 ms after P3 arrived (run AR6). The log couldn't
say which check failed:

- the commitment;
- the P3 MAC;
- the card;
- the peer's beacon day.

A soak of 27,500 pairings didn't reproduce it. The next occurrence must name
its cause.

## Decision

1. `Action::Disconnect` carries a `reason: CloseReason`. The core picks one
   at each close path:

   | Reason | When |
   | --- | --- |
   | `Expired` | The pre-auth deadline passed (spec §5.6). |
   | `Busy` | A pairing is in flight, admission refused, the peer answered BUSY, or the P0 tie-break closed our own dial. |
   | `Duplicate` | The contact already has a link. |
   | `Unknown` | No contact matches the S1 pseudonym. |
   | `Malformed` | A fragment, frame, record, beacon, P0, S1 or S2 that doesn't parse, an out-of-order frame, an ACK or READ beyond what was sent, or a queued record that doesn't open (the chain reports every queued-record failure as malformed). |
   | `Unsupported` | A P1 with another version or mode. |
   | `Commitment` | P3's nonce doesn't match P1's commitment. |
   | `Authentication` | A MAC, the card's AEAD, or a session frame fails to open. |
   | `Card` | The card opens but doesn't decode. |
   | `StaleCard` | The peer's card is for a beacon day more than one day off. |
   | `Exhausted` | The session can't seal another frame. |

2. The SDK passes the reason to `Radio.disconnect(link, reason)` as a
   `DisconnectReason`. That holds every core reason plus two of the SDK's own:
   - `Backlog`, when a link's send queue overflows (ADR 0023);
   - `Poisoned`, when it replaces a poisoned core (ADR 0022 §3).
3. Both radios log `close requested (<reason>)`, with the reason in snake
   case, e.g. `close requested (stale_card)`.
4. The reason is local diagnostics only. It is never sent to the peer, and
   nothing on the wire changes. A peer still sees only the link going down.

## Consequences

- Every log of a link the core closed names the cause, on both platforms.
- Tests assert the reason, so a change to a close path shows up as a test
  failure.
- This breaks the FFI and the `Radio` interface. Both radios and every test
  fake change in the same commit.
- Reasons distinguish failed checks. That stays within the device: the
  pairing transcript and the peer see nothing new. A local log reader learns
  which check failed, but not any secret.

## Considered options

- **Log inside the core.** The core has no logger and runs under the
  constant-time and no-std rules (ADR 0007). Returning the reason keeps the
  core pure.
- **A free-form string.** That's easy to log but can't be checked in tests or
  matched by the apps.
- **An error event instead of a reason on `Disconnect`.** That gives two
  actions for one decision, and they could disagree.
- **A coarse reason (protocol, policy, timeout).** That wouldn't separate the
  P3 checks, which is the question that prompted this ADR.

## Migration

None. r1 has no released builds. Storage and the wire are unchanged.

## Amends

- ADR 0022 §3: `Disconnect { link, reason }`.
- ADR 0023 link trace and ADR 0037: `close requested (<reason>)`.
