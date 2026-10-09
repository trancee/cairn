# Kotlin Multiplatform + Rust core + BLE toolchain viability

Type: research
Status: resolved
Blocked by:

## Question

What is the most viable, maintained toolchain for a Rust crypto/protocol core consumed from a Kotlin Multiplatform + Compose Multiplatform app on Android and iOS? Compare UniFFI-based KMP bindings (e.g. Gobley, uniffi-kotlin-multiplatform-bindings), hand-written cinterop/JNI, and alternatives; build integration (Gradle + cargo, XCFramework), debugging, maturity, and pitfalls. Also: which KMP BLE libraries (e.g. Kable, Blue Falcon) support central **and** peripheral roles, GATT server, L2CAP CoC, iOS state restoration, and Android foreground-service operation — or must BLE be platform-specific `expect/actual` code?

## Comments

- 2026-10-05 (charting): minimum targets are **Android 8 (API 26) / iOS 13** — verify that Kotlin/Native, Compose Multiplatform, the chosen UniFFI binding generator and the BLE library still support these floors, and what breaks if not.
- 2026-10-05 (research): [Findings](../../../docs/research/2026-10-05-kmp-rust-ble-toolchain.md). Gobley (UniFFI-based, fork of the now-unmaintained Trixnity `uniffi-kotlin-multiplatform-bindings`) is the only actively maintained toolchain producing real shared `commonMain` Kotlin with automated Gradle/Cargo/Android-ABI wiring; manual JNI+cinterop remains a viable fallback. **Android 8/API 26 floor is fine everywhere (NDK floor is API 21), but iOS 13 is not achievable** — current Kotlin/Native (2.4.20) defaults to iOS 15.0 minimum and Compose Multiplatform's own matrix states iOS 14 minimum, with no supported override path; this contradicts ticket 06's resolved floor and needs re-decision. For BLE, Kable (central-only, mature) and blue-falcon (peripheral/GATT-server/L2CAP, newer/less proven) are the two real KMP options; neither fully covers central+peripheral+GATT-server+L2CAP, so platform-specific `expect`/`actual` code is recommended for the peripheral/server side regardless of library choice.

## Answer

Bindings: Ubique `1.3.1` / UniFFI `0.32.0` is selected instead of Gobley per [ADR 0004](../../../docs/adr/0004-core-architecture.md). Source research confirms the Android API 26+ and required iOS architecture targets, but the iOS 15 deployment floor and generated-call integration remain unverified pending [issue 44](44-ubique-binding-smoke-test.md). BLE: Kable is central-only; blue-falcon adds a peripheral role but is immature. Plan on platform `expect/actual` code for at least peripheral/GATT server, state restoration and the foreground service. The original comparison remains in [the dated research note](../../../docs/research/2026-10-05-kmp-rust-ble-toolchain.md).
