# Ubique KMP target compatibility

Type: research
Status: resolved
Blocked by: none

## Question

Does `UbiqueInnovation/uniffi-kotlin-multiplatform-bindings` support the
project's required Android API 26+ and iOS 15+ build targets with its current
release, and is it compatible with the planned KMP/Compose Multiplatform app
and library module split?

Verify the project's documented Kotlin, Gradle, AGP, Rust, UniFFI and Xcode
requirements; Android and iOS target architectures and deployment floors;
the generated Kotlin source-set/API layout; Rust artifact linking for Android
and iOS; and any restrictions relevant to ADR 0004's binding role. Use primary
sources only. Report unverified compatibility rather than inferring support
from general Kotlin/Native claims. Do not run builds or change implementation
code; the project owner selected the binding separately after the research.

## Answer

Selected Ubique `1.3.1` with UniFFI `0.32.0` instead of Gobley, by explicit
user direction on 2026-10-08. Primary-source research confirms Android API 26+,
the required iOS device/simulator architectures, and the KMP library/app
module split. Kotlin `2.4.20`, Gradle `9.6.1`–`9.7.0`, and AGP `9.3.1` are the
verified toolchain overlap.

The iOS 15 deployment floor is not verified: Ubique's release CI builds its
published Apple runtime with `IPHONEOS_DEPLOYMENT_TARGET=16.4`, and no
documentation clarifies whether that minimum reaches consumers. No build was
run. The selected integration remains unvalidated until the isolated
generated-call/platform proof in [issue 44](44-ubique-binding-smoke-test.md)
passes. Detailed evidence: [Ubique compatibility research](../../../docs/research/2026-10-08-ubique-compatibility.md).
