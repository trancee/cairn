# Slice S2: Android↔Android over BLE

Type: task
Status: open
Blocked by: 31

## Question

Build the Android BLE adapter (central plus GATT server per ADR 0003), carrying S1 between two phones with fragmentation per ADR 0005. Add a minimal chat screen and the first debug-panel fields. Switch on the on-device timing smoke test.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
