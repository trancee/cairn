# `pqcble-r1` threat model and security goals

Status: **accepted** (2026-10-05, ticket *Threat model and security goals*). This document states the goals that [ADRs 0001–0005](../adr/) must meet. Changing it requires a new review.

## 1. System and assets

Two **peers** (phones running `pqcble`) **pair** once and become **contacts**. After that, every BLE connection starts with a **Resume** and carries real-time messages and **queued messages** (see [`GLOSSARY.md`](../../GLOSSARY.md)).

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
| A5 | Malicious contact | A legitimately paired peer that acts maliciously, or whose device is A4b-compromised |
| A6 | Tracking attacker | Passive receivers at many places and times, trying to link a device across them |
| A7 | DoS / battery drain | Floods advertisements, connections, S1 messages or pairing attempts |

## 3. Security goals

Rows are adversaries, columns are properties. ✓ = claimed; ✗ = explicitly not claimed; — = not applicable.

| | Confidentiality | Integrity / auth | PQ forward secrecy | PCS (healing) | Unlinkability | Contact graph hidden | Availability |
|---|---|---|---|---|---|---|---|
| A1 | ✓ | ✓ (TOFU: ✗ at first contact) | ✓ | — | ✓ beacon and pseudonym; ✗ fixed UUID | ✓ | ✗ (best effort, §5) |
| A2 | ✓ (NIST L3) | — | ✓ | — | — | ✓ | — |
| A3 | ✓ | ✓ for QR/SAS; ✗ for unverified TOFU | ✓ | Conditional fresh honest-epoch healing after compromise (§3 below) | as A1 | ✓ | ✗ |
| A4a | ✓ via OS data protection (§4) | — | — | — | — | via OS | — |
| A4b | ✗ for current state and stored history; ✓ for erased past keys | ✗ until healed | ✓ | ✓ classical at the next Resume (passive attacker); ✓ PQ after a fresh honest epoch whose secrets remain unexposed | — | ✗ | — |
| A5 | ✓ for other contacts' traffic | ✓ cannot impersonate you to others; ✗ KCI toward itself unless the KCI profile is on | ✓ | ✓ | ✗ can track your device beacon | ✓ learns nothing beyond its own pairing | ✗ |
| A6 | — | — | — | — | ✓ beacon and pseudonym; ✗ fixed UUID, ✗ OS address rotation not under app control | ✓ | — |
| A7 | — | — | — | — | — | — | best effort (§5) |

**PCS scope** (spec OI-24): the attacker keeps all state stolen before
recovery. PQ healing requires a genuinely exchanged fresh epoch whose
decapsulation key and shared secret are not exposed. A continuously
active attacker who uses stolen authentication state to replace every
exchange can prevent healing. Neither the default ratchet nor fail-closed
MIX retries guarantee availability or unconditional recovery from that
attacker. Known interception can be addressed by authenticated in-person
re-pairing.

### Per-mode authentication

- **QR**:
  - A is authenticated to B by `H(ek_A)` in the QR.
  - B is authenticated to A by the QR `token` plus a **4-digit confirmation code**. Both phones show the code, which is derived from the transcript like the SAS, and A taps confirm.
  - An attacker who photographed the QR wins with probability ≤ 10⁻⁴ per attempt.
- **SAS**: commit-then-reveal with 6 digits. A man-in-the-middle wins with probability ≤ 10⁻⁶ ≈ 2⁻²⁰ per attempt.
- **TOFU**:
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
- **Pairing channel:** pairing users share an authentic visual channel (QR display or SAS comparison) during pairing.
- **Constant time:** the implementation is constant-time with respect to secrets against software timing observation, including timing measured remotely over BLE.

## 5. Availability (best effort)

- Before authentication, an attacker can make the device do at most one MAC per S1. No asymmetric operation happens before the MAC check.
- Rate limits apply per pseudonym, per remote address and globally.
- A connection that has not authenticated within 5 s is dropped. ADR 0003's pre-auth frame limits apply.
- Pairing is accepted only while the user has a pairing screen open.

## 6. Non-goals (explicitly not claimed)

- Hiding that a `pqcble` device is present (the fixed service UUID), that two devices are connected, or their timing and traffic volume.
- Proximity or distance bounding. Relay attacks are possible, so "connected" never implies "nearby".
- Protection against a compromised OS or kernel, a sandbox escape, malware with root, physical side channels (power, EM), fault injection, or RF jamming.
- Detecting state rollback by a rooted user or the OS. Backups are excluded by design (ADR 0002).
- Remote revocation of a lost device. Each contact removes it by hand; its state expires with the store-and-forward bounds.
- Protection of locally stored message history against A4b.
- Unlinkability against one's own contacts (the device beacon key is shared with them; ADR 0005).
- Key commitment / multi-key AEAD robustness (ADR 0001).

## 7. Possible later work (out of scope for `pqcble-r1`)

- Marking a contact **stale** after N days unseen, with optional automatic removal.
- Per-contact beacons to resist tracking by contacts (rejected for r1 in ADR 0005).
