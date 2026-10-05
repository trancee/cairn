# Threat model and security goals

Type: grilling
Status: resolved
Blocked by: 

## Question

Which adversaries does `pqcble-r1` defend against, and which security properties does each mode claim? Cover: active MitM at pairing (per QR/SAS/TOFU), a passive recorder with a future quantum computer, device seizure (unlocked/locked, with or without forensic tools), a malicious or compromised contact, a tracking adversary (multi-sensor RF, cross-contact), DoS/battery drain, rollback via backup/restore, and a malicious OS/app sandbox escape (out of scope?). Output: `docs/spec/threat-model.md` with an adversary × property table (confidentiality, PQ-FS, PCS, mutual auth, KCI, unlinkability, metadata hiding, availability), and non-goals.

## Comments

## Answer

Recorded in the [threat model](../../../docs/spec/threat-model.md); the user accepted all recommendations over two rounds on 2026-10-05.

**In scope:**
- A1–A7: an active radio attacker; harvest-now-decrypt-later; a future active quantum attacker; device seizure (locked phone / compromised); a malicious contact; a tracking attacker; DoS.
- Constant-time against timing side channels.

**Out of scope:** a compromised OS, physical side channels, jamming, proximity, detecting rollback on rooted devices, and remote revocation.

**Claims:**
- Forward secrecy, plus post-compromise recovery: classical at the next Resume, PQ after the next PQ epoch.
- TOFU: passive-PQ only, shown as Unverified.
- Metadata: identities and the contact graph are hidden; the presence of `pqcble` is visible.
- Security levels: NIST L3 and 2^-64/2^-128 tag bounds.

**New:** QR mode gets a 4-digit confirmation on A, which defeats an attacker who photographed the QR. It is local only, and ADR 0005 and the wire draft are updated.
