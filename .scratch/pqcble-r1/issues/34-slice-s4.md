# Slice S4: QR pairing and pairing hub

Type: task
Status: open
Blocked by: 32

## Question

Add QR pairing (QR payload plus the 4-digit confirmation on A) and the pairing hub UX from ADR 0009, including the TOFU fallback link, Unverified badge, 120 s timeout, abort flows and contact naming.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
