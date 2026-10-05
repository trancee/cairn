# Device test lab

Type: task
Status: open
Blocked by:

## Question

Provision the physical devices needed to validate decisions and the prototype: at least two Android phones (API ≥ 31, ideally different vendors, one with BLE 5 2M PHY + LE CoC), at least one iPhone, a Mac with Xcode, and optionally a BLE sniffer (e.g. nRF52840 dongle + Wireshark). HITL: the human confirms which devices are available; record models/OS versions here.

## Comments

- 2026-10-05: Required measurements from [ADR 0003](../../../docs/adr/0003-ble-transport.md):
  - which discovery path wins with a backgrounded iPhone (iOS-as-central vs Android scanning the overflow UUID vs direct-connect fallback);
  - Android↔iOS L2CAP CoC interop (this gates the CoC flag);
  - connect → beacon read → Resume → first frame inside iOS's ~10 s wake budget;
  - effective MTU and PHY.

  At least one Android device must be API 29+ for CoC, and one should be API 26–28 to test the MTU-23 / no-CoC path.
