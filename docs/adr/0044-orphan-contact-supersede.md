---
status: proposed
date: 2026-11-01
version: cairn-r1
---

# 0044: A new pairing supersedes an orphan contact for the same peer

## Context

[ADR 0043](0043-provisional-contact.md) left one lost frame unhandled. On the
pairing link, A commits the contact at a valid S1 and then sends S2. If S2 is
lost:

- B never commits, and forgets the contact when the link closes.
- A keeps the contact. It holds `CK_0` and the pending `CK_1`, and its Resume
  never completed: it has no message chain, so nothing was sent to the
  contact or received from it.
- Every Resume A starts matches B's beacon to this contact. B finds no
  pseudonym and closes the link as `Unknown`.
- When B dials, it treats A as a stranger and the two pair again. A then holds
  two contacts for B, and the first still wins every beacon match
  ([issue 60](../../.scratch/cairn-r1/issues/60-orphan-contact-after-lost-s2.md)).

A can recognise the orphan from its own state. ADR 0043 rejected replacing
a contact that has the same beacon key in general: the beacon key isn't
secret, so a malicious contact of B could present it.

## Decision

1. When a newly paired contact commits (ADR 0043), the core deletes every
   other contact that:
   - has never completed a Resume, so it has no message chain;
   - has no link: no Resume or session in flight, and it isn't provisional;
   - holds the same peer beacon key as the new contact. The core ratchets the
     earlier of the two keys to the later day (spec §10.2) and compares them
     in constant time.
2. The core removes the contact from memory and emits a new row action,
   `DeleteContact { contact }`, before it persists the new contact and reports
   `ContactAdded`. The platform deletes the contact's row in the same
   transaction. A contact without a message chain has no queued rows, no
   messages and no courier envelopes, so nothing else is deleted or reported.
3. The device beacon key doesn't rotate (spec §10.2). The new contact is the
   same peer, and B never held the deleted contact.

The SDK refreshes its contact list on `ContactAdded`, which follows in the
same result. No byte of any frame changes.

## Consequences

- After a lost S2, the orphan blocks A's Resumes only until B next dials.
  Then the second pairing replaces it, and A holds one contact for B. Resume
  works from either side.
- A needs B to dial once. A's own dials keep failing as `Unknown` until then,
  and nothing on the wire tells A why. The dial policy lets B dial A after the
  failed Resume (spec §10.4).
- The FFI, the SDK row stores (in-memory and SQLDelight) and the row-timing
  wrapper handle the new action. The apps need no change.
- **Accepted risk.** A malicious contact M of B knows B's beacon key. If M
  pairs with A while A's contact for B still has no message chain, A deletes
  that contact. Honest runs reach that state only for the moments between S1
  and B's first DATA frame, or after a lost S2 or a lost first DATA frame.
  If B already holds its contact for A, B's Resumes then fail at A as
  `Unknown`, and a later pairing leaves B with two contacts for A, because
  B's contact has a message chain and isn't superseded. M must be in range
  of A at that moment and win a pairing. A contact with a message chain can
  never be deleted this way.

## Alternatives considered

- **Prefer the newest contact on a beacon match.** The orphan would no longer
  block dials, but it would stay in the list as a duplicate.
- **Expire a contact after N failed Resumes or after T days.** Link drops on
  some radios (issue 57, issue 58) make failed Resumes common for real
  contacts, and a timer leaves the duplicate visible meanwhile.
- **Reuse the orphan's contact ID for the new contact.** Contact IDs are
  threaded through link state, Resume tries and provisional tracking; reusing
  one would need those to be rewritten mid-pairing.
- **Delete any earlier contact with the same beacon key.** Rejected by
  ADR 0043: it would let a malicious contact of B replace A's working contact
  for B.
