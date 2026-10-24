# Slice S2: Android↔Android over BLE

Type: task
Status: open
Blocked by: 31

## Question

Build the Android BLE adapter (central plus GATT server per ADR 0003), carrying S1 between two phones with fragmentation per ADR 0005. Add a minimal chat screen and the first debug-panel fields. Switch on the on-device timing smoke test.

Done when every applicable gate is green, tests were written first (TDD), the relevant spec sections are referenced, and the slice is demonstrated on the oldest and newest core-matrix devices of each platform pair involved, with results noted here. Strict formal-model gate: a slice blocked by a model ticket doesn't start until that ticket resolves.

## Comments

2026-10-24: [ADR 0023](../../../docs/adr/0023-android-ble-adapter.md) records
the owner's choices:
- Robolectric host tests in a separate Android module, with Kover at 100%;
- in-memory persistence until S5;
- Material 3;
- the timing smoke test moves to [issue 49](49-on-device-timing-smoke-test.md).

The GATT UUIDs are in spec §12 (draft 0.8). S2 ships as stacked PRs:
1. the ADR and the platform-neutral `LinkDriver` with the Kover gate;
2. the Android radio module, permissions and the chat screen;
3. the device demonstration.

2026-10-24: PR 1 merged (#45). PR 2 adds `:androidBle` (`AndroidRadio`,
both GATT roles, permissions) and the Compose chat screen in `:androidApp`.
Robolectric host tests run on API 26 and 37, and Kover is at 100% lines and
branches in both modules. The owner chose to exclude `@Composable` code from
coverage, because some Compose compiler branches cannot be reached
(ADR 0023 §4). The Linux guest lane is not rerun yet: the guest VM is down.
