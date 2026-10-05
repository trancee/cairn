---
status: accepted
date: 2026-10-05
version: pqcble-r1
---

# 0003 — BLE transport: symmetric discovery, GATT with an optional L2CAP CoC upgrade

## Context

`pqcble-r1` runs between Android (API 26+) and iOS (15+) over plain BLE, never Bluetooth pairing. It must work while the apps are backgrounded. The background research ([Android↔iOS background BLE](../research/2026-10-05-android-ios-background-ble.md)) found:

- iOS moves a backgrounded app's service UUIDs into an Apple-only overflow area that Android probably cannot see.
- iOS can scan in the background for a standard service UUID.
- iOS cannot advertise service or manufacturer data.
- Each iOS background wake gets about 10 s.
- No vendor states that L2CAP CoC interoperates between Android and iOS.
- Pairing and ratchet payloads are at most about 2.4 KB, so link throughput is not the bottleneck.

## Decision

**Discovery and roles: symmetric.** Every device advertises and scans whenever the OS allows it, and either side may connect.

- **Advertising.** A fixed `pqcble` 128-bit service UUID.
  - Android also puts the rotating **beacon** in service data.
  - A foregrounded iOS device also advertises the beacon as a rotating 128-bit service UUID.
  - A backgrounded iOS device advertises only the fixed UUID, which iOS places in the overflow area.
- **Scanning.** Filter on the fixed UUID. A peer may also direct-connect to a recently seen address as a fallback.
- **Beacon matching.** A central that did not see the peer's beacon in advertising reads the `beacon` characteristic right after connecting, before anything else. If the beacon matches no contact, it disconnects.
- **Duplicate links.** When two contacts end up with two links, the link on which **pairing role A** is central survives, and the other is closed unused. Neither link carries data before Resume completes.

**GATT service** (vendor 128-bit UUIDs; the peripheral is the GATT server):

| Characteristic | Properties | Purpose |
|---|---|---|
| `beacon` | read | Peripheral's current rotating beacon (8 B) |
| `rx` | write without response | Central → peripheral fragments |
| `tx` | notify | Peripheral → central fragments |
| `psm` | read, only after Resume | L2CAP CoC PSM for the optional upgrade |

**Framing and fragmentation.**
- Every `pqcble` frame begins with the 1-byte header defined by the wire format, which includes a **MORE** bit.
- One ATT value carries one fragment.
- The fragments of a frame are sent back to back in each direction, never interleaved.
- A frame that fits one ATT value costs 0 extra bytes.
- Any negotiated ATT MTU of at least 23 works.

**Size limits and AEAD scope.**
- One AEAD tag per reassembled frame.
- After authentication, a frame may be at most **4096 B**.
- Before authentication (pairing, Resume), only one frame may be in flight, at most **2560 B**, and it must be reassembled within **5 s**. Breaking any limit disconnects the link.

**Flow control and loss.**
- Only platform backpressure is used, with a bounded send queue:
  - iOS central: `canSendWriteWithoutResponse` and `peripheralIsReady`;
  - iOS peripheral: `updateValue` and `isReady(toUpdateSubscribers)`;
  - Android: `onCharacteristicWrite` and `onNotificationSent`.
- There are no transport-level acks.
- On disconnect, a partially received frame is discarded. Recovery is a new Resume plus the message-layer resend from [ADR 0002](0002-store-and-forward.md).

**L2CAP CoC upgrade.**
- Only when both sides support it (Android API 29+, iOS 11+), and only after Resume over GATT.
- The central reads `psm` and opens an LE CoC channel. There, an L2CAP SDU is exactly one frame (the MORE bit is unused); the frame format is otherwise unchanged.
- If the upgrade fails, the session stays on GATT without error.
- A feature flag, **off by default** until a device test proves Android↔iOS interop, controls the upgrade.

**Link tuning.**
- For pairing and ratchet bulk transfers, Android requests 2M PHY, high connection priority and ATT MTU 517, then returns to balanced settings.
- On iOS, the app reads `maximumWriteValueLength` and adapts.

## Alternatives considered

- **Fixed direction (iOS always central to Android).** This is the only path the research shows working with a backgrounded iPhone. It was rejected in favour of symmetric discovery, which includes that path and adds others; the device test lab must measure which path wins in practice.
- **GATT only.** Lowest risk. Rejected so that a faster CoC path stays available, behind a flag that is off by default.
- **A separate transport header with fragment sequence numbers.** Costs 1–2 B per fragment and buys nothing on an ordered, reliable link.
- **An AEAD tag per fragment.** Lets a receiver verify before buffering, but costs 16 B per fragment. The pre-auth limits bound memory instead.
- **Requiring ATT MTU ≥ 185.** Simpler, but excludes Android 8 devices and stacks that stay at 23.

## Risks

- **Linkability.** The fixed service UUID reveals that a `pqcble` app is nearby. Only the beacon is unlinkable.
- **Background reachability.** Android finding a backgrounded iPhone may not work at all. Direct-connect fallback is limited by iOS address rotation. Symmetric discovery hides this risk instead of designing around it, which makes real-device measurement mandatory.
- **Wasted connections.** Reading the `beacon` characteristic costs a connection per candidate peer, which adds battery use and lets a nearby observer count connection attempts.
- **Pre-auth memory.** Each link can hold up to 2560 B for 5 s before authentication. Many simultaneous strangers multiply this, so the number of concurrent unauthenticated links must be capped.
- **CoC on API 29+ only, with unproven interop.** The GATT path must stay fully functional.
- **iOS wake budget.** Over a cold state-restoration launch, connect, discovery, beacon read, Resume and the first frame must all finish within about 10 s.

## Migration

First version, so nothing to migrate. GATT UUIDs and the `beacon`/`rx`/`tx`/`psm` contract are fixed for `pqcble-r1`. Changing them requires a new service UUID, not a change to the existing one.
