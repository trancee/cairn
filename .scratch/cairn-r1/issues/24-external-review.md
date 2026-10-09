# External cryptographic review

Type: grilling
Status: resolved
Blocked by: 15, 19

## Question

Should `cairn-r1` get an external cryptographic and implementation review before any non-prototype release, and if so: scope (spec, formal models, Rust core, KMP shell), timing (after the spec freeze? after the prototype?), the type of reviewer (academic vs commercial audit vs public call for review), the budget range, and what blocks on it.

## Comments

## Answer

Decided by the user on 2026-10-05. This is a policy decision with no ADR; it doesn't change the design.

- **When:** an external review is **required before any non-prototype release** (app store or public SDK). It does **not** block the prototype.
- **Scope, in two stages:**
  1. Spec and formal models (Resume, ratchet mixing, SAS). This starts after the spec freeze.
  2. An implementation audit of the Rust core (constant-time, the backend seam, parsers, FFI), then a lighter pass over the KMP storage and BLE code.
- **Reviewers:**
  - academic PQ-protocol researchers for stage 1;
  - a commercial crypto audit firm for stage 2;
  - a public ePrint/spec post in parallel with stage 1.
- **Release gate:** every Critical and High finding fixed; Medium findings fixed or documented; a public report or summary.
- **Budget:** not decided; deferred. Choosing reviewers and a budget happens after this destination (see Out of scope on the map).
