# Minimum OS versions

Type: grilling
Status: resolved
Blocked by:

## Question

Which minimum Android API level and iOS version does the prototype target, given the chosen FIPS module (e.g. CryptoKit ML-KEM needs iOS 26), BLE feature needs (2M PHY, extended advertising, L2CAP CoC, foreground service types), and the KMP toolchain's support matrix?

## Answer

**Android 8 (API 26) / iOS 13** (user, 2026-10-05; recommendation was Android 12 / iOS 17 and was overridden).

Consequences carried into other tickets:
- Android LE CoC public API is API 29+ → GATT-only transport path is mandatory; L2CAP CoC at most an optional upgrade (*Data transport and fragmentation*).
- Android 8–11 scanning needs location permission; 12+ needs Nearby Devices.
- CryptoKit ML-KEM (iOS 26) cannot be the only iOS backend → ML-KEM ships in the Rust core.
- KMP/CMP/UniFFI support for iOS 13 must be verified (*Kotlin Multiplatform + Rust core + BLE toolchain viability*).

## Comments

- 2026-10-05: **Reopened.** *Kotlin Multiplatform + Rust core + BLE toolchain viability* found that iOS 13 is unsupported by the chosen KMP/CMP toolchain (Kotlin/Native needs iOS 15, CMP iOS 14). The iOS floor must be re-decided.
- 2026-10-05: **Re-decided: iOS 15 / Android 8 (API 26)** (user). This is the lowest floor the KMP/CMP toolchain supports; the Android consequences above still hold.
