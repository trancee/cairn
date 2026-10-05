---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0009: Pairing UX

## Context

The [threat model](../spec/threat-model.md) defines three pairing modes:
- QR, with a 4-digit confirmation on role A (10^-4).
- SAS, 6 digits (2^-20).
- TOFU, which only resists a passive quantum attacker and is shown as Unverified.

[ADR 0005](0005-wire-format.md) fixes the messages: P1–P4, the QR payload, and the peer card carried in P3/P4. The [pairing-UX prototype](../research/prototypes/pairing-ux/pairing-ux-prototype.html) compared three structures:
- A: a linear wizard.
- B: a single hub showing my QR and a scanner.
- C: conversation-first, TOFU by default, verify later.

## Decision

1. **Structure.** First pairing uses a single hub screen: my QR and the scanner side by side. Roles are assigned by who scans: the phone showing the QR is A. Comparing a code (SAS) and skipping verification are fallback links on the hub. An Unverified contact can be upgraded later through a **Verify** action in its chat. That action runs an SAS comparison in a bottom sheet.
2. **SAS** is shown as 6 digits, grouped 3+3. There is no emoji rendering.
3. **TOFU** is a secondary link labelled as not recommended. A confirmation warning explains that someone nearby could intercept. The resulting contact carries an **Unverified** badge until it is verified.
4. **Mismatch.**
   - During pairing (QR 4-digit or SAS): abort. Nothing is persisted, and the user sees "possible interception".
   - During a later Verify of an existing contact: the contact becomes **Compromised**. Sending to it is blocked, and the user is offered Contact removal followed by Re-pairing.
5. **Timeout.** A pairing session times out 120 s after the QR is shown or the search starts, if P4 hasn't completed. Nothing is persisted. Cancelling behaves the same way.
6. **Naming.** The contact name is prefilled from the peer card's display name. It is editable and stored locally only; the peer never sees the local name.
7. **Debug panel.** Developer settings only: debug builds, or a hidden toggle in release builds. It shows the mode, pairing role, the transcript-hash prefix, per-message sizes and timings, and the outcome. It never shows key material, full transcript hashes, or SAS values after completion.

## Alternatives

- **A, the wizard.** It adds a "how are you together?" step and more taps. QR is the right default, so the extra step buys nothing.
- **C, conversation-first.** This makes the weakest mode the default. A2/A3 attackers would get an active-MITM window on every pairing that users never upgrade.
- **Digits plus emoji, or emoji only.** Emoji glyphs differ between Android and iOS vendor fonts, which causes false "different" answers. With two representations, users compare only one. Emoji-only would need a word list of at least 20 bits.
- **Equal-weight TOFU, or no TOFU.** Equal weight encourages unverified contacts. Removing TOFU strands users who have no camera and can't compare codes in person.
- **Upgrade mismatch: warn only, or auto-remove.** Warning only lets users keep sending over an intercepted session. Auto-remove loses the history and evidence without the user's consent.
- **60 s timeout.** Too tight on the slowest lab devices (Android 8, iPhone SE 1st gen) for P1/P2 at 1251/1137 B.

## Risks

- The hub crowds a small screen (SE 1st gen, 4"). The layout must collapse to tabs below a height threshold.
- Users may tap "They match" without comparing (SAS fatigue). This is mitigated only by keeping SAS the exception and QR the default.
- A Compromised contact blocks sending, so a user error during Verify (pressing the wrong button) forces a Re-pairing. The confirmation dialog must name that consequence.
- The debug panel's hidden toggle must not be reachable by an A4b attacker in a way that leaks more than the threat model already concedes. It shows no secrets, by construction.

## Migration

None; this is the first UX decision. The Compromised state adds a contact flag to the `state` table ([ADR 0006](0006-key-storage.md)). Changing the SAS representation later would need a protocol version bump only if the SAS length changes.

## Amendments

2026-10-05, from *Formal model: SAS pairing* ([`pqcble-r1` spec §13](../spec/pqcble-r1.md#13-consolidation-issues-resolved-2026-10-05)):
- In SAS and TOFU modes, the phone whose user picks the peer from the nearby list is pairing role B; the picked phone is A. This mirrors QR mode, where the scanning phone is B (OI-20).
- The mode the user taps is authoritative: B aborts if `P1` carries a different mode (OI-19).
