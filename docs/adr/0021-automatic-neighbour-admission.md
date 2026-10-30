---
status: accepted
date: 2026-10-23
version: cairn-r1
---

# 0021: Automatic neighbour admission (always-on TOFU)

## Context

`cairn-r1` admits a contact only through a user-run pairing ceremony. The
spec (§5) and the threat model (§5) accept pairing only while the local user
has the pairing screen open. [ADR 0009](0009-pairing-ux.md) makes QR the
primary mode and TOFU a discouraged fallback.

On 2026-10-23 the owner redirected the product toward a peer-to-peer,
end-to-end encrypted BLE mesh: "pairing should begin as soon as a new peer
has been found, user does not need to initiate it, the new peer becomes part
of the network instantly", and "once a peer is connected, it can participate
in the network". The owner chose always-automatic TOFU over a pairing
screen or a discoverable toggle, after reviewing the consequences listed
below.

The [BLE mesh research](../research/2026-10-23-ble-mesh-design.md) compared
Bluetooth Mesh, Briar, Bridgefy (and its two published breaks), BitChat and
Meshtastic. The owner selected the **contacts-graph mesh** (research §3,
option iii): every pair of adjacent phones runs an unchanged `cairn-r1`
pairwise relationship, and multi-hop reach goes only through chains of such
neighbours. That keeps the verified Pairing, Resume and SAS models valid and
confines new cryptographic design to a separate courier and routing layer.

Automatic admission leaves three gaps in the spec:

- Nothing tells the picked phone (A) which incoming link to send P1 on: a
  contact's Resume arrives on an identical incoming central link.
- OI-20 assigns roles by which user picks the peer; there is no user.
- Two devices can discover each other and connect to each other at the same
  moment.

## Decision

The owner accepted every rule below on 2026-10-23.

1. **Neighbours.** Every contact is now admitted automatically and is called
   a **neighbour** when the distinction matters. The pairwise state,
   Resume, DATA, store-and-forward, ratchet and beacons are unchanged.
2. **Strangers.** A peer is a stranger when its advertised beacon matches no
   contact and its `beacon` read (spec §4.1) also matches none. The connect
   policy (spec §10.4) may connect to a stranger to admit it.
3. **Roles.** On an admission link the GATT central is pairing role B and the
   peripheral is pairing role A. This replaces OI-20 for automatic
   admission.
4. **P0 admission request** (spec §5.1, OI-27). After a non-matching `beacon`
   read, B sends `P0 = hdr ‖ r(16)` (PAIR, sub 0; 17 B) on the same link,
   with `r = rand(16)`. A answers with P1 only if rule 6 allows; otherwise it
   closes the link without a response. P0 is not part of the transcript
   `th`, and `r` carries no secret.
5. **One pairing in flight; tie-break.**
   - A device has at most one pairing in flight, as A or as B. While it has
     one, it sends no P0 and closes any further incoming P0 link.
   - If a device receives a P0 (as A) while its own P0 (as B) is
     unanswered, it compares the two `r` values as unsigned big-endian
     integers. If the incoming `r` is larger, it closes its own outgoing
     link and answers the incoming P0. If it is smaller, it closes the
     incoming link. If they are equal, it closes both.
   - When both attempts are with the same peer, both devices reach the same
     decision, so exactly one link survives. When they are with different
     peers, the rule still keeps one pairing in flight; the loser retries
     later under the connect policy. No peer identification is needed.
6. **Admission limits** (per device, both roles):
   - at most **10** neighbours admitted per rolling hour;
   - at most **30** pairing attempts answered or started per rolling hour,
     so failed attempts also cannot force unbounded X-Wing work;
   - at most **256** neighbours in total. At the cap, automatic admission
     stops. Nothing is evicted; the user can remove neighbours.
   - An address whose pairing attempt failed or was refused is not tried
     again for **1 h**, reusing the ADR 0008 back-off.
   - Existing pre-auth rules stay: one frame in flight per direction,
     2560 B, 5 s per frame and 5 s to complete pairing on the link.
7. **Mode.** Automatic admission always uses TOFU: P1 `mode` MUST be `0x03`,
   and B aborts on any other value, preserving OI-19's no-downgrade check.
   QR and SAS pairing are removed from r1: the QR message, `token` and
   `QRC` are no longer used, and `confirm_B` always uses an empty `token`.
   Mode values `0x01` and `0x02` abort. No P1–P4 layout changes.
8. **Verification.** Every neighbour starts **Unverified**. The in-chat
   **Verify** (spec §5.3, SAS over the stored `th` and `nB`) is the only way
   to verify one; a mismatch marks it **Compromised**, as before.
9. **Display name.** The card's name is empty by default (`name_len = 0`).
   The user may opt in to sharing a display name with every new neighbour.
   The local name of a neighbour is the shared name if any, otherwise a
   locally generated label.
10. **Multi-hop.** Relaying for, or messaging, a non-neighbour is out of
    scope for this ADR. It is the courier and routing layer of
    [issue 47](../../.scratch/cairn-r1/issues/47-mesh-courier-routing.md),
    which needs its own ADR and formal model before implementation.

## Formal models

No model changes are required for admission. The SAS pairing model already
covers the TOFU branch, and restricting the modes to TOFU removes branches
without adding transitions. P0 and the tie-break are unauthenticated
availability mechanisms outside the transcript; an attacker who tampers with
`r` can at most refuse or delay a pairing, which A1 can already do by
dropping frames.

## Consequences

- Spec draft 0.7: §2.3, §4.2, §5, §10.4 and §13 (OI-27).
- Threat model: every contact starts unauthenticated; any nearby device can
  become a neighbour and learns the device beacon key, so it can recognise
  the device later; the pre-auth bound moves from "pairing screen open" to
  rule 6.
- [ADR 0009](0009-pairing-ux.md) is superseded for first contact: no hub,
  no QR, no SAS pairing and no 120 s pairing session. Verify,
  Compromised, mismatch handling, naming and the debug panel remain.
- [ADR 0008](0008-beacon-discovery-tuning.md)'s connect policy gains the
  stranger-admission case.
- Slices: S1 builds automatic admission, basic Resume and CHAT; S4 (QR
  pairing and hub) is withdrawn; S8 keeps only the in-chat Verify.

## Alternatives considered

- **Pairing screen as today, with a P0 request.** Smallest threat-model
  change; rejected by the owner because peers must join without user
  action.
- **A global "discoverable" toggle.** One consent instead of none; rejected
  for the same reason.
- **A sends P1 on every incoming link while admission is open.** No new
  frame, but contacts' Resumes fail during the window and every connecting
  device receives a 1216 B key.
- **A separate GATT characteristic for admission.** Moves intent into
  Kotlin, outside the core's checks.
- **Open flooding mesh with a shared network key** (research option ii).
  Cheap per hop, but every member can forge network-layer traffic, which is
  the Bridgefy failure mode.
- **Hop links plus a mesh-wide end-to-end envelope** (research option i).
  Needs mesh-distributed identity keys and new cryptography before any
  messaging works.
- **Evict old neighbours at the cap.** Rejected: Meshtastic documents
  eviction as an impersonation vector.

## Risks

- **Sybil and spam.** Any nearby device can become a neighbour and message
  the user. Rule 6 bounds the rate and total, not the intent.
- **Tracking by neighbours.** Each neighbour holds the device beacon key
  and can recognise the device until the key rotates on a removal.
- **First-contact interception.** An active attacker present at admission
  can stay in the middle until the users run Verify.
- **Availability.** An attacker can use up the hourly attempt budget and
  delay legitimate admissions (best effort, threat model §5).

## Amendments

2026-10-25, from the S2 fleet test ([issue 52](../../.scratch/cairn-r1/issues/52-preauth-fleet-timing.md), spec OI-29):
- Every refusal of a P0 in rules 4 and 5 (limits, a pairing in flight, a
  smaller or equal incoming `r`) is a 1 B **BUSY** frame (PAIR step 5)
  instead of closing the link. On Android, a peripheral can't drop a link
  that the remote central opened, so B used to wait for its 5 s deadline,
  with its own pairing in flight, and then backed off A for 1 h. With equal
  `r`, the device still closes its own outgoing link.
- A sends BUSY, then waits for B to close the link, closing it itself at the
  pre-auth deadline. B closes the link on BUSY.
- In rule 6, a BUSY is not a failed attempt: B doesn't back off the address
  and the attempt doesn't count against the 30 per hour, since no X-Wing
  operation ran. B dials again under the connect policy (2 min per address).
  The 1 h back-off stays for failed attempts.
- Formal models: unchanged. BUSY is an unauthenticated availability signal
  outside `th`, like P0; forging one only delays a pairing.

2026-10-25, from the fleet pairing plateau ([issue 53](../../.scratch/cairn-r1/issues/53-fleet-pairing-plateau.md), spec OI-30):
- In a 12-phone, 180 s run, 20 pairing attempts failed. None failed a
  protocol check: 11 reached the 5 s deadline without a reply and 9 lost
  the link. Each backed off its address for 1 h, and each later refused
  dial re-armed that hour; 14 of 69 central links were refused that way.
  One radio hiccup blocked a pair of phones for the rest of the encounter.
- Rule 6's back-off now depends on the failure:
  - a **transport failure** (the link dropped, or the pre-auth deadline
    passed, with the pairing in flight) backs off the address for 2 min
    after the first, doubling with each further one up to 1 h;
  - a **protocol failure** (a malformed, unexpected or invalid frame or
    value, or a card more than a day old) keeps the 1 h back-off;
  - an address's failures are forgotten 1 h after its back-off ends, or
    when a pairing with it completes.
- A dial that the limits refuse is not a failed attempt and no longer
  backs off the address. Three such refusals back it off for 1 h, as
  ADR 0008's connect policy says; refusals while backed off don't count.
- The 30 attempts per hour still bound X-Wing work. An attacker who drops
  frames makes a peer retry the address sooner, but every retry counts
  against that budget, as before.
- Formal models: unchanged; no model covers admission. No wire change.

2026-10-29, proposed in [ADR 0040](0040-redial-after-supervision-timeout.md) (spec OI-42):
- The first link drop with a pairing in flight is forgiven when the address
  has no earlier failure on record: it backs nothing off, and the next
  transport failure backs off 2 min. A missed pre-auth deadline still backs
  off from the first. The forgiven drop is forgotten after 1 h or when a
  pairing with the address completes.
