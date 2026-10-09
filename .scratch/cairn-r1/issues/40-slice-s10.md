# Slice S10: Doorbell and KCI profile

Type: task
Status: open
Blocked by: 36, 37

## Question

Implement the connectionless doorbell (Android rings, round-robin per ADR 0008) and the KCI profile variants of Resume.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
