# A lost S2 leaves an orphan contact on A

Type: bug
Status: needs-triage
Blocked by: none

## Question

After [ADR 0043](../../../docs/adr/0043-provisional-contact.md), how should
A detect and remove a contact whose pairing Resume lost S2?

## Observation (2026-10-31, from the core's loopback tests)

On the pairing link, A commits the contact at a valid S1 and then sends S2. If
S2 is lost, the following happens:

- B never commits, and forgets the contact when the link drops.
- A keeps the contact. It holds `CK_0` and the pending `CK_1` and has never
  received a DATA frame.
- When B dials next, it treats A as a stranger. The two pair again, and A holds
  two contacts for B.
- When A dials B, it matches B's beacon to the orphan, because `beacon::find`
  returns the first match. B closes the Resume as `Unknown`. That repeats on
  every dial, even after the second pairing.

## Options

- Delete a contact that is still unconfirmed from its pairing Resume when a
  new pairing brings a card with the same beacon key. This needs a
  `DeleteContact` action through the FFI, the SDK store and both apps.
  - Risk: a malicious contact of B could present B's beacon key and delete
    A's unconfirmed contact for B.
  - That contact would have to be in its first-Resume window.
- Prefer the newest contact when several match one beacon. The orphan would
  stay, but it would no longer block dials. It would still show as a
  duplicate.
- Expire such a contact after it fails to resume N times, or after T days.

## Done when

- A contact orphaned by a lost S2 no longer blocks Resume in either
  direction.
- The user never sees two contacts for one peer from this cause.
