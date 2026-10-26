# `cairn-r1` threat model and security goals

Status: **accepted** (2026-10-05, ticket *Threat model and security goals*). This document states the goals that [ADRs 0001–0005](../adr/) must meet. Changing it requires a new review. Amended 2026-10-23 for automatic neighbour admission ([ADR 0021](../adr/0021-automatic-neighbour-admission.md)); the owner reviewed and accepted the consequences listed there. Amended 2026-10-26 for couriers ([ADR 0033](../adr/0033-courier-relaying.md)), adding A8.

## 1. System and assets

Two **peers** (phones running `cairn`) **pair** once and become **contacts**. Since [ADR 0021](../adr/0021-automatic-neighbour-admission.md) (2026-10-23), pairing is automatic TOFU with every discovered peer, so every contact is an automatically admitted **neighbour** and starts Unverified. After that, every BLE connection starts with a **Resume** and carries real-time messages and **queued messages** (see [`GLOSSARY.md`](../../GLOSSARY.md)). Since [ADR 0033](../adr/0033-courier-relaying.md), neighbours also act as **couriers**: they carry sealed **envelopes** of queued messages for contacts that are out of range.

The protected assets are:
- message content;
- each contact's chain keys and ratchet state;
- the device beacon key;
- the contact list (who is paired with whom);
- the user's location history as observable over BLE.

## 2. Adversaries

| ID | Adversary | Capabilities |
|---|---|---|
| A1 | Active radio attacker | Reads, injects, replays, relays, drops or delays any BLE traffic; runs many devices |
| A2 | Harvest-now-decrypt-later | Records all traffic today; obtains a cryptographically relevant quantum computer later |
| A3 | Future active quantum attacker | A1 plus a quantum computer at attack time |
| A4a | Device seizure, locked | Holds a locked phone, before or after the first unlock since boot |
| A4b | Device seizure, compromised | Unlocked phone or forensic extraction: reads all app state at a point in time |
| A5 | Malicious contact | A paired peer that acts maliciously, or whose device is A4b-compromised. Under automatic admission this includes any device that was ever nearby, within the admission limits (§5) |
| A6 | Tracking attacker | Passive receivers at many places and times, trying to link a device across them |
| A7 | DoS / battery drain | Floods advertisements, connections, S1 messages or pairing attempts |
| A8 | Malicious courier | A neighbour (A5) that carries envelopes for others: drops, delays, replays, corrupts or injects envelopes, rewrites `copies` and `expiry`, records inventories and timing, and colludes with other couriers |

## 3. Security goals

Rows are adversaries, columns are properties. ✓ = claimed; ✗ = explicitly not claimed; — = not applicable.

| | Confidentiality | Integrity / auth | PQ forward secrecy | PCS (healing) | Unlinkability | Contact graph hidden | Availability |
|---|---|---|---|---|---|---|---|
| A1 | ✓ | ✓ after Verify; ✗ at first contact (every neighbour is TOFU) | ✓ | — | ✓ beacon and pseudonym; ✗ fixed UUID | ✓ | ✗ (best effort, §5) |
| A2 | ✓ (NIST L3) | — | ✓ | — | — | ✓ | — |
| A3 | ✓ | ✓ after Verify; ✗ for Unverified neighbours | ✓ | Conditional fresh honest-epoch healing after compromise (§3 below) | as A1 | ✓ | ✗ |
| A4a | ✓ via OS data protection (§4) | — | — | — | — | via OS | — |
| A4b | ✗ for current state and stored history; ✓ for erased past keys | ✗ until healed | ✓ | ✓ classical at the next Resume (passive attacker); ✓ PQ after a fresh honest epoch whose secrets remain unexposed | — | ✗ | — |
| A5 | ✓ for other contacts' traffic | ✓ cannot impersonate you to others; ✗ KCI toward itself unless the KCI profile is on | ✓ | ✓ | ✗ can track your device beacon | ✓ learns nothing beyond its own pairing | ✗ |
| A6 | — | — | — | — | ✓ beacon and pseudonym; ✗ fixed UUID, ✗ OS address rotation not under app control | ✓ | — |
| A7 | — | — | — | — | — | — | best effort (§5) |
| A8 | ✓ envelopes are sealed under `mk_idx` | ✓ cannot forge, alter or replay a message into the recipient; cannot forge a tombstone | ✓ as queued messages | ✓ as queued messages | ✓ envelope tags (P5, argued); ✗ timing and volume | ✗ first and last couriers together link sender and recipient; one courier learns only its depositor or its fetcher | ✗ redundancy across `L` copies only |

**PCS scope** (spec OI-24): the attacker keeps all state stolen before
recovery. PQ healing requires a genuinely exchanged fresh epoch whose
decapsulation key and shared secret are not exposed. A continuously
active attacker who uses stolen authentication state to replace every
exchange can prevent healing. Neither the default ratchet nor fail-closed
MIX retries guarantee availability or unconditional recovery from that
attacker. Known interception can be addressed by authenticated in-person
re-pairing.

### Per-mode authentication

QR and SAS pairing are retired (ADR 0021). Every neighbour is admitted by TOFU and can be verified later.

- **Verify** (SAS over the stored transcript): commit-then-reveal with 6 digits. A man-in-the-middle present at admission is detected except with probability ≤ 10⁻⁶ ≈ 2⁻²⁰.
- **TOFU** (every admission):
  - PQ confidentiality against passive attackers only.
  - An active attacker at the first pairing can stay in the middle until the users verify by SAS or QR in person.
  - The UI must label the contact **Unverified**.

### Security levels

- **Confidentiality:** NIST category 3 (ML-KEM-768, AES-256, SHA-384).
- **Classical:** ≥ 128-bit security everywhere.
- **Online forgery:** ≤ 2⁻⁶⁴ per attempt for 8 B tags (pseudonym, beacon, doorbell) and ≤ 2⁻¹²⁸ for 16 B tags (MAC, confirm, AEAD).

## 4. Assumptions

- The OS, the hardware keystore and the app sandbox are not compromised.
- The OS CSPRNG is secure.
- **Device seizure:**
  - A locked phone that has not been unlocked since boot does not reveal app state (Android credential-encrypted storage; iOS data protection).
  - After the first unlock, protection is whatever the OS gives against forensic extraction. Beyond that we claim nothing.
- **Verification channel:** users who run Verify share an authentic visual channel for the SAS comparison. Admission itself assumes no authentic channel.
- **Constant time:** the implementation is constant-time with respect to secrets against software timing observation, including timing measured remotely over BLE.

## 5. Availability (best effort)

- Before authentication, an attacker can make the device do at most one MAC per S1. No asymmetric operation happens before the MAC check.
- Rate limits apply per pseudonym, per remote address and globally.
- A connection that has not authenticated within 5 s is dropped. ADR 0003's pre-auth frame limits apply.
- Pairing is automatic but bounded (spec §5.6): one pairing in flight, at most 30 attempts and 10 admissions per rolling hour, at most 256 neighbours, and a back-off per failed address (2 min after a transport failure, doubling up to 1 h; 1 h after a protocol failure). Dropping frames makes a peer retry sooner, but every retry still counts against the 30 attempts. An attacker can use up the hourly budget and delay legitimate admissions.
- Any neighbour can send messages to the user; admission limits bound how many neighbours exist, not what they send.
- Couriers (ADR 0033) hold at most 16 envelopes per depositing neighbour (32 if Verified), 256 envelopes and 1 MiB in total, and refuse deposits when full instead of evicting. Each courier clamps `copies` and `expiry` to its own limits, so one courier cannot make an envelope spread or live longer than the next courier allows.

## 6. Non-goals (explicitly not claimed)

- Hiding that a `cairn` device is present (the fixed service UUID), that two devices are connected, or their timing and traffic volume.
- Proximity or distance bounding. Relay attacks are possible, so "connected" never implies "nearby".
- Protection against a compromised OS or kernel, a sandbox escape, malware with root, physical side channels (power, EM), fault injection, or RF jamming.
- Detecting state rollback by a rooted user or the OS. Backups are excluded by design (ADR 0002).
- Remote revocation of a lost device. Each contact removes it by hand; its state expires with the store-and-forward bounds.
- Protection of locally stored message history against A4b.
- Unlinkability against one's own contacts (the device beacon key is shared with them; ADR 0005). Under automatic admission this covers any device that was once admitted nearby, until the key rotates on a contact removal.
- Sybil resistance: one adversary can be admitted as many neighbours, up to the admission limits.
- Key commitment / multi-key AEAD robustness (ADR 0001).

## 7. Possible later work (out of scope for `cairn-r1`)

- Marking a contact **stale** after N days unseen, with optional automatic removal.
- Per-contact beacons to resist tracking by contacts (rejected for r1 in ADR 0005).
- Messaging a peer that was never a contact through couriers (sealing to a non-adjacent peer; deferred by ADR 0033).
- Resisting traffic analysis of courier traffic (timing, envelope counts per link) in a dense mesh.
