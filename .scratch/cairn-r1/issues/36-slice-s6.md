# Slice S6: Beacons, discovery and background

Type: task
Status: open
Blocked by: 33, 35

## Question

Implement beacons, discovery duty cycles, rate-limited connects and background operation on Android and iOS, per ADR 0003 and ADR 0008, including beacon-key rotation on contact removal.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
