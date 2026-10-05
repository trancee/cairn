# Kotlin Multiplatform + Rust core + BLE toolchain viability

Type: research
Status: open
Blocked by:

## Question

What is the most viable, maintained toolchain for a Rust crypto/protocol core consumed from a Kotlin Multiplatform + Compose Multiplatform app on Android and iOS? Compare UniFFI-based KMP bindings (e.g. Gobley, uniffi-kotlin-multiplatform-bindings), hand-written cinterop/JNI, and alternatives; build integration (Gradle + cargo, XCFramework), debugging, maturity, and pitfalls. Also: which KMP BLE libraries (e.g. Kable, Blue Falcon) support central **and** peripheral roles, GATT server, L2CAP CoC, iOS state restoration, and Android foreground-service operation — or must BLE be platform-specific `expect/actual` code?

## Comments

- 2026-10-05 (charting): minimum targets are **Android 8 (API 26) / iOS 13** — verify that Kotlin/Native, Compose Multiplatform, the chosen UniFFI binding generator and the BLE library still support these floors, and what breaks if not.
