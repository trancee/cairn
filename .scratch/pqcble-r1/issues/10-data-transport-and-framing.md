# Data transport and fragmentation

Type: grilling
Status: open
Blocked by: 04

## Question

Which BLE transport carries `pqcble-r1` frames between Android and iOS — GATT (which characteristics, notifications vs indications, write-with/without-response) and/or L2CAP CoC — and how are frames larger than one ATT payload (introduction ≈2.4 KB, ratchet chunks) fragmented, reassembled and flow-controlled? Who is GATT client vs server, and how are role conflicts (both sides discover each other) resolved?

## Comments

- 2026-10-05 (charting): minimum Android API 26 → a GATT-only path is mandatory; L2CAP CoC can only be an optional upgrade.
