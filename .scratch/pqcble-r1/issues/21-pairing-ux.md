# SAS and QR pairing UX

Type: prototype
Status: resolved
Blocked by: 15

## Question

What do the pairing screens look like and how do they behave: QR show/scan, SAS digits (plus emoji?), the TOFU 'unverified' state and its later upgrade, abort/timeout/mismatch flows, contact naming, and the debug-panel view of a pairing? Produce rough UI variations in Compose Multiplatform (or a mock) to react to.

## Comments

- Prototype `docs/research/prototypes/pairing-ux/pairing-ux-prototype.html` (variants A wizard / B hub / C conversation-first). Grilled Q1–Q7; all recommendations accepted: B hub + C in-chat Verify upgrade; 6 digits only; TOFU as secondary link; upgrade mismatch → Compromised contact (sending blocked, offer removal + re-pairing); 120 s timeout; prefilled editable name; dev-only debug panel without secrets. Recorded in ADR 0009; glossary: Verification widened, Compromised contact added.
