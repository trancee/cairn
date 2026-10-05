# Data transport and fragmentation

Type: grilling
Status: resolved
Blocked by: 04

## Question

Which BLE transport carries `pqcble-r1` frames between Android and iOS — GATT (which characteristics, notifications vs indications, write-with/without-response) and/or L2CAP CoC — and how are frames larger than one ATT payload (pairing ≈2.4 KB, ratchet chunks) fragmented, reassembled and flow-controlled? Who is GATT client vs server, and how are role conflicts (both sides discover each other) resolved?

## Comments

- 2026-10-05 (charting): minimum Android API 26 → a GATT-only path is mandatory; L2CAP CoC can only be an optional upgrade.

## Answer

Recorded in [ADR 0003 — BLE transport](../../../docs/adr/0003-ble-transport.md) (user, 2026-10-05, two grilling rounds):
- **Discovery:** symmetric; every device advertises a fixed service UUID and scans for it, with direct-connect as a fallback.
- **Duplicate links:** the link where pairing role A is central wins.
- **GATT service:** `beacon` (read), `rx` (write without response), `tx` (notify), `psm` (read after Resume).
- **Fragmentation:** a MORE bit in the 1-byte frame header; works with any MTU ≥ 23.
- **AEAD and limits:** one tag per frame; frames ≤ 4096 B; before authentication, one frame ≤ 2560 B, reassembled within 5 s.
- **Flow control:** platform backpressure only; recovery after link loss is Resume plus the ADR 0002 resend.
- **L2CAP CoC:** upgrade after Resume, behind a flag that is off by default.
- **Link tuning:** Android uses 2M PHY, high priority and MTU 517 during bulk transfers.
