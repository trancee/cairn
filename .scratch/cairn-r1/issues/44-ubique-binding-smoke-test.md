# Ubique binding smoke test

Type: prototype
Status: claimed
Blocked by: 45

## Question

Prove or reject the selected Ubique UniFFI integration before completing Slice
S0. Use the exact supported baseline: plugin/runtime/bindgen `1.3.1`, UniFFI
`0.32.0`, Rust `1.97.1`, Kotlin `2.4.20`, Gradle `9.7.0`, AGP `9.3.1`,
JDK 25 for the Gradle daemon, and JDK 21 for JVM compilation.

The proof must use a generated Rust API through the planned KMP library and
Compose app module boundary, with an Android API 26+ build and iOS device and
simulator-arm64 builds whose deployment floor is verified as iOS 15. Exercise
at least one real generated call, typed error, and Rust-object lifetime. Inspect
the packaged Rust library/runtime artifacts; report any module, allocator, or
deployment-target incompatibility rather than weakening the target matrix.

Run builds/tests only in an OS-enforced sandbox with no external network, an
empty allowlisted environment, read-only source/toolchain, scratch-only writes,
and explicit CPU, memory, process, file-size, disk, and wall-clock limits. Use
only dependencies already available locally. If those controls cannot be
enforced, keep this ticket open and record the exact blocker; do not claim the
integration works from configuration or source inspection alone.

## Comments

- 2026-10-08: The current checkout has no Gradle wrapper/build files or Cargo
  manifest. The installed Gradle is `9.7.1`, above the verified Kotlin
  `2.4.20` maximum of `9.7.0`; installed Rust `1.99.0` has only
  `aarch64-apple-darwin` installed as a target. The local shell reports
  unlimited CPU, memory, virtual-memory and file-size limits and a maximum
  user-process count of 1333; no enforceable disk quota was established.
  Although `sandbox-exec` exists, no environment enforcing all required
  no-network, empty-environment, read-only-source, scratch-only and resource
  limits was established. No target-controlled build/test was run.

- 2026-10-08: Resumed this prototype ticket. Its concrete artifact is an
  executable Gradle/Cargo interop proof, but the required sandbox is not
  available in this environment. The ticket remains unresolved pending a
  compliant runner; no integration files or builds were produced.

- 2026-10-08: Per user direction, this ticket now waits on
  [Provision isolated build runner](45-provision-isolated-build-runner.md).

- 2026-10-09: PR #2 merged the host-only `core/` Cargo workspace and library
  cross-build evidence for Apple and Android. Earlier missing-manifest and
  missing-target observations above describe the 2026-10-08 checkout.
  No Gradle/KMP binding proof or packaged runtime/deployment-floor proof was
  added. Ordinary cross-builds do not establish the required isolation.
  This ticket still waits on the runner; its pinned interop tuple has not
  been revalidated or changed by the Rust 1.99.0 foundation increment.
