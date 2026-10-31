---
status: accepted
date: 2026-10-31
version: cairn-r1
---

# 0043: A paired contact stays provisional until its first Resume message

## Context

Pairing ends with P4, from B to A (spec §5). B then starts a Resume on the
same link: B sends S1, A answers S2, and B confirms the new key with an empty
DATA frame (spec §6, [ADR 0022](0022-cairn-core-contract.md)).

Until now, each side stored and reported the contact as soon as it had the
other's card: B before sending P4, A on receiving it. If the link dropped
between those two points, only one side kept the contact.
[Issue 58](../../.scratch/cairn-r1/issues/58-crossed-dial-link-loss.md)
recorded this between an iPhone X (B) and a Galaxy Xcover 4s (A):

- the iPhone sent P4 and stored the contact;
- the Xcover never got P4, and its pre-auth deadline closed the link.

From then on, neither side could recover:

- The iPhone found the Xcover's beacon among its contacts and sent S1. The
  Xcover matched no pseudonym and closed the link (`Unknown`). Nothing on the
  wire told the iPhone why.
- When the Xcover dialed, it treated the iPhone as a stranger and sent P0. If
  that pairing completed, the iPhone held two contacts for one peer. The first
  still matched the Xcover's beacon, so every Resume the iPhone started
  failed.

No extra frame removes the asymmetry. Whichever frame comes last, losing it
leaves one side committed and the other not. A side can only commit at a point
where the frames it has received prove the other side has the contact or will
recover it.

## Decision

1. A contact paired on a link is **provisional** until that link carries a
   valid Resume message from the peer:
   - B, once a valid S2 arrives. S2 proves that A had P4 and accepted S1.
   - A, once a valid S1 arrives. S1 proves that B got P3 and sent P4.
2. A provisional contact lives only in the core's memory:
   - it isn't persisted;
   - `ContactAdded` isn't reported for it;
   - `contacts()` doesn't list it;
   - no other link may resume it. A beacon hit or S1 for it on another link
     closes that link as `Duplicate`.
3. At its commit point, the core persists the contact and then reports
   `ContactAdded`:
   - B does this before sending its first DATA frame;
   - A does this before sending S2.
4. If the pairing link goes down while the contact is still provisional, the
   core forgets the contact. This covers a drop, the pre-auth deadline, and a
   close for an invalid S1 or S2. The device row's contact counter has already
   moved on, so the contact's ID isn't reused.

No byte of any frame changes, and nothing changes in the radios or the SDK.

## Consequences

Each lost frame on the pairing link now ends as follows:

| Lost frame | B | A | Result |
| --- | --- | --- | --- |
| P4 (issue 58) | forgets | never had it | Both strangers; the next meeting pairs again. |
| S1 | forgets | forgets | Both strangers. |
| S2 | forgets | keeps | A holds a contact that B lacks. |
| B's first DATA | keeps | keeps | Recovered by key alternation (ADR 0022). |

A frame that arrives but fails to open closes the link. So does a frame that
arrives corrupted. That close counts as the frame being lost.

Further consequences:

- The P4 loss in issue 58 can no longer leave a one-sided contact.
- **S2 loss remains.** After it, A holds a contact whose Resume never
  completed, and B treats A as a stranger:
  - When B next dials, it sends P0 and the two pair again, so A ends with two
    contacts for B.
  - Until then, every Resume that A starts fails with `Unknown` at B.
  - A can recognise the orphan, because it still holds the pending key from
    its pairing Resume and has never received a DATA frame. Removing it needs
    a contact-deletion action that the core doesn't have yet. That is
    [issue 60](../../.scratch/cairn-r1/issues/60-orphan-contact-after-lost-s2.md).
- ADR 0022's ordering rule changes for new contacts. B persists the contact
  before its first DATA frame instead of before P4, and A persists it before
  S2. "R persists its pending `CK_{n+1}` before S2" still holds.
- An app that crashes before the commit point loses the pairing on that side
  only. The other side then sees the link drop before its own commit point,
  unless the crash hit A after it sent S2, which is the S2-loss case above.
- Admission counts the pairing when the card arrives, as before (spec §5.6).
  A provisional contact that is forgotten still counts against the hourly
  limits and the 256-contact cap until it is forgotten.

## Alternatives considered

- **A commits only at B's first DATA frame.** That frame is the last one
  sent, so losing it would leave B with a contact that A lacks. B's orphan
  looks like any other contact and can't be recognised. The current rule
  leaves the orphan with A instead, which can recognise it.
- **A confirmation frame after P4.** This would change the wire format. The
  last frame could still be lost, so the asymmetry would only move.
- **Replace an earlier contact whose card has the same beacon key.** The
  beacon key isn't secret: every contact of a peer holds it. A malicious
  contact of B could pair with A, present B's key, and replace A's real
  contact for B.
