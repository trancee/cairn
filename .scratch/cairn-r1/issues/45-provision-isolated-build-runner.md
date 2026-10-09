# Provision isolated build runner

Type: task
Status: claimed
Blocked by: none

## Question

Provision or identify a disposable build runner capable of safely proving the
selected Ubique integration in [Ubique binding smoke test](44-ubique-binding-smoke-test.md).
This is a human-in-the-loop infrastructure task; do not run target-controlled
builds until the acceptance conditions below are established.

The runner must support the pinned Kotlin/Gradle/AGP/JDK/Rust tuple and provide
the macOS/Xcode, Android SDK/NDK, Rust targets, and linker tools needed for
JVM, Android, iOS-device, and iOS-simulator-arm64 compilation. Pre-provision
required dependencies through a trusted process, then make toolchains and
caches read-only and disable network access during target-controlled work.

Acceptance:

- Builds run in an OS-enforced, disposable environment with external network
  disabled and only an explicit safe environment-variable allowlist.
- Source and installed toolchains are read-only; only the assigned scratch
  directory is writable by Gradle, Cargo, tests, and subprocesses.
- CPU, memory, process count, per-file size, total disk use, and wall-clock
  limits are explicitly enforced.
- Gradle and Cargo can resolve only from pre-provisioned offline caches; no
  dependency installation or network fallback occurs during the proof.
- The environment can expose compiler/build results and bounded logs without
  exposing credentials, host home directories, other workspaces, or shared
  services to build processes.
- Record the runner identity, enforcement mechanism, resource limits, available
  toolchain/target versions, exact offline invocation, and any unsupported
  target or runtime proof. Do not claim a build or platform passed without its
  corresponding output.

When complete, unblock the dependent smoke-test ticket with the runner
instructions and evidence needed to execute it.

## Comments

- 2026-10-08: Assessed the current host. It is a Mac mini M1 with 8 GB RAM and
  15.6 GB free disk, Xcode 27 / iOS SDK 27, Android SDK platforms 21 and
  33–37, and no Android NDK directory found. It has Rust 1.99.0 with only the
  host target installed, Gradle 9.7.1, no container runtime, and no configured
  Git remote. `sandbox-exec` is present but deprecated; shell hard limits are
  not a complete resource-control boundary, and the current host has unlimited
  CPU time, memory and file-size limits. No target-controlled build was run.

  **Conclusion:** this host is not currently a compliant runner. Its free disk
  is also insufficient evidence for installing and caching Xcode/Android/Rust
  cross-target toolchains and Gradle/Cargo dependencies. Recommended route:
  provision a disposable macOS VM/runner with enforced CPU, memory, process,
  filesystem/disk and wall-clock limits, then pre-provision the exact pinned
  toolchain and offline dependency caches. Creating or modifying a hosted
  runner is an external-service action and needs the owner's infrastructure
  choice and authorization.

- 2026-10-08: Apple-primary-source follow-up is in
  [macOS VM sandbox feasibility](../../../docs/research/2026-10-08-macos-vm-sandbox-feasibility.md).
  Apple Virtualization.framework can run a macOS guest on this M1 and provides
  VM-level network omission, CPU/memory partitioning, and a read-only base disk
  with a disposable writable overlay. Apple's sample sizes a guest disk at
  128 GB; this host has 15.6 GB free. More storage alone would not settle
  feasibility: the 8 GB host-memory headroom is unverified and likely tight,
  and process/file/wall-clock limits need an additional guest/host supervisor.
  No VM or builds were run.

- 2026-10-08: A macOS guest on Linux is not a supported alternative:
  Apple's macOS SLA permits virtualized macOS only on Apple-branded computers
  and prohibits running the OS on non-Apple hardware. QEMU/KVM does not
  document macOS guest support; community Hackintosh setups are unofficial and
  unsuitable as Xcode/Simulator proof. See
  [macOS guest on Linux](../../../docs/research/2026-10-08-macos-guest-on-linux.md).

- 2026-10-09: The merged foundation now has Apple and Android library
  cross-build evidence, including Android NDK r30 and Rust mobile targets.
  Docker/Colima was also used for bounded Linux checks. The missing-tools
  and missing-remote observations above are historical, not current setup
  claims. No compliant isolated macOS/KMP runner with all acceptance controls
  was established. These additions do not unblock the binding smoke test.
