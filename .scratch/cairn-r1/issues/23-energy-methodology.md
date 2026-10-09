# Energy and airtime measurement methodology

Type: research
Status: resolved
Blocked by: 

## Question

How do we measure the energy and airtime of `cairn` on the device-test-lab phones without a BLE sniffer and without lab power monitors? Evaluate: Android Battery Historian/batterystats, `dumpsys bluetooth_manager` activity energy info, ODPM/PowerStats HAL availability on non-Pixel devices, HCI snoop logs for airtime, Perfetto power rails, iOS Instruments Energy Log/MetricKit, and whether a cheap USB power meter or an nRF PPK2 is needed. Output a reproducible protocol: idle background cost per hour, cost per Resume, cost per message, and the pairing cost.

## Comments

## Answer

Findings: [energy measurement methodology](../../../docs/research/2026-10-05-energy-measurement-methodology.md).

- With this lab (no Pixel, no sniffer, no power monitor), true energy in joules cannot be measured.
- **Airtime:** Android HCI snoop logs (btsnoop) give precise per-packet airtime accounting with no extra hardware, and they cover both ends of an Android↔iOS link.
- **Energy:** only a relative estimate, from repeated, baseline-subtracted battery-percentage or coulomb-counter drain with airplane mode (Bluetooth on) and the screen off.
- **Not useful here:**
  - batterystats is a model, not a measurement;
  - `BluetoothActivityEnergyInfo` is unverified per vendor;
  - ODPM rails are Pixel-only;
  - MetricKit has no Bluetooth metrics;
  - the PPK2 can't measure phones.
- Energy claims must therefore be labelled *relative*.
