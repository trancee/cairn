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

2026-10-24: PR 2 merged (#46). Two CI fixes landed with it. Robolectric now
reads the `android-all` jars in place, because copying them broke the strict
lane's 128 MiB file ceiling. Strict Kotlin CodeQL analysis now gets 4 GiB of
evaluator RAM (ADR 0015 amendment). The Linux guest lane is green with label
`s2-radio`, and a mutant with one uncovered branch fails
`:androidBle:koverVerifyDebug`. Next: PR 3, the device demonstration.

2026-10-24: Device demonstration with the debug APK. The phones were the
oldest and newest core-matrix Android devices: the Huawei P10 lite
(`2XJ7N17323004090`, Android 8.0, API 26, Kirin 658, BT 4.2) and the Nothing
Phone (2) (`1f1dad34`, Android 16, API 36). Both negotiated ATT MTU 517.

The first run found a spec bug. §4.3 allowed `ATT_MTU − 4` body bytes, so at
MTU 517 a fragment was 514 B. ATT caps an attribute value at 512 B, and the
Nothing Phone's stack logged `gatt_process_notification: value.len larger
than GATT_MAX_ATTR_LEN, discard`. The handshake stalled and the link closed.
PR 3 caps the body at `min(ATT_MTU − 4, 511)` B (spec §4.3, `fragment`) and
adds a unit test and a fuzz invariant for the 512 B limit.

With the fix, the two phones paired automatically. Both showed "Contact 0
(Unverified)", and messages were delivered in both directions: "Hello from
P10 lite API 26" and "Reply from Nothing Phone 2 API 36". The debug panels
agree:

| Phone | Role | MTU | Out (fragments / bytes) | In (fragments / bytes) |
|---|---|---|---|---|
| Nothing Phone (2) | CENTRAL | 517 | 8 / 1414 | 6 / 1438 |
| P10 lite | PERIPHERAL | 517 | 6 / 1438 | 8 / 1414 |

When both phones launch at the same moment, they dial each other at once and
both connections fail with status 133. The once-per-2-minutes attempt limit
then fires on both phones in step, so the first link takes about two minutes.
The phones linked within seconds when started 5 s apart. Follow-up:
[issue 50](50-simultaneous-dial-backoff.md).

In the fleet trace run, the P10 lite aborted at startup inside AWS-LC's jitter
entropy source. Fixed by building AWS-LC without jitter entropy:
[issue 51](51-aws-lc-jitter-abort.md).
