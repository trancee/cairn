# On-device timing smoke test

Type: task
Status: open
Blocked by: 32

## Question

Build the pre-release on-device timing smoke test from
[ADR 0007](../../../docs/adr/0007-ct-conformance-gates.md): a dudect-style
harness in an instrumented test app, run on the arm64 Android and iPhone
devices of the [core matrix](13-device-test-lab.md). It covers X-Wing and
ML-KEM decapsulation and MAC verification. Decide the hidden, test-only FFI
entry points it needs, without exporting them from release builds.

Done when the harness runs on the oldest and newest core-matrix device of
each platform, its results are recorded here, and the release checklist names
it as a blocking pre-release gate.

## Comments

- 2026-10-24: split out of [Slice S2](32-slice-s2.md) by the owner, so that
  S2 covers the BLE adapter, the chat screen and the debug panel
  ([ADR 0023](../../../docs/adr/0023-android-ble-adapter.md) §6).
