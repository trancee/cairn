# Slice S3: Android↔iOS

Type: task
Status: open
Blocked by: 32

## Question

Build the iOS CoreBluetooth adapter in the KMP SDK and the iOS app target, and run S2's flow Android↔iOS. Verify the iOS MTU and Android↔iOS interop facts flagged as unverified.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments
