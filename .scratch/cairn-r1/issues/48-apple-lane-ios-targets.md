# Apple lane: iOS targets

Type: task
Status: open
Blocked by: 30

## Question

Add the iOS targets to the root Gradle/UniFFI build (iOS 15 deployment floor, which
[ADR 0004](../../../docs/adr/0004-core-architecture.md) still lists as unverified), build the Rust core for the Apple targets, and extend the strict
CodeQL lane to the iOS sources. Moved out of [S0](30-slice-s0.md).

Done when the iOS targets build and test in CI with every applicable gate
green, and the binding is demonstrated on the oldest and newest core-matrix
iPhones.

## Comments
