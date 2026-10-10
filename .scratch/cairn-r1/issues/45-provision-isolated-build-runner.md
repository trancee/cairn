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
JVM, Android, iOS-device, and iOS-simulator-arm64 compilation across the two
proof lanes below. A single machine need not support both lanes. Pre-provision
required dependencies through a trusted process, then make toolchains and
caches read-only and disable network access during target-controlled work.

## Proof lanes

| Lane | Required scope | Current state |
|---|---|---|
| Linux/Android | Disposable Linux environment; Rust host tests, Kotlin/JVM integration, Android builds and generated-call execution | Preparation VM/probes, measured CPU quota and committed offline JVM/Android replay pass; immutable source/cache, runtime network isolation and disposable final image incomplete |
| macOS/iOS | Isolated environment on Apple hardware; Xcode, iOS-device and simulator-arm64 builds, generated-call execution and packaged deployment-floor inspection | No compliant runner established |

The owner approved splitting the work on 2026-10-10. Each lane must satisfy
every isolation acceptance condition below independently. Linux success
allows the Linux/Android portion of issue 44 to run; it does not resolve this
ticket or authorize iOS proof on Linux. Resolve only when both lanes have
recorded enforcement evidence. No GitHub self-hosted runner registration is
required for a local offline proof; registration is a separate owner-approved
external-service change.

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

For partial completion, record the accepted lane and its instructions here.
Issue 44 may execute only that accepted lane; issue 30 and the full binding
gate remain blocked until both lanes and all binding acceptance conditions
are complete.

## Comments

- 2026-10-10: Owner-executed Linux setup uses Fedora 44 x86_64 with
  KVM/libvirt and SELinux enforcing. The dedicated Ubuntu 24.04.5 preparation
  guest has 8 vCPUs, 16 GiB configured RAM and a 128 GiB virtual disk, with
  NAT for trusted provisioning and no configured host-directory sharing.
  Installed tools: Temurin 25.0.4.1, Ubuntu JDK 21.0.12.1, Gradle 9.7.0,
  Rust 1.97.1 with all three Android target libraries, Android CLI tools
  15859902, platform 26 revision 2, platform 37.0 revision 2, build-tools
  37.0.0, NDK 30.0.16248370 and platform-tools 37.0.1. Downloaded Ubuntu,
  Temurin, Gradle and Rust archives passed their selected published SHA-256
  checks. Android packages were installed through the official SDK tools.
  SDK/toolchain provisioning is not compatibility or cross-build proof.

  Owner reports successful systemd sandbox probes with an unprivileged
  `cairn-build` account: writes outside scratch denied, guest service sockets
  hidden, 8 MiB per-file limit rejected writes with `EFBIG`, and 16 MiB
  scratch tmpfs rejected writes with `ENOSPC`. A 64 MiB memory limit caused
  `Result=oom-kill` with zero swap; a two-second runtime limit caused
  `Result=timeout`. Private loopback succeeded, external networking failed
  without a route, and `TasksMax=16` rejected additional processes with
  `EAGAIN`. These are owner-supplied outputs, not independently executed
  measurements. Subsequent integrated launches and standalone generated-call
  proofs passed as recorded below. CPU-budget verification, immutable
  source/cache mounts, reusable repository invocation and disposable
  final-image execution remain outstanding.

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

- 2026-10-10: Subsequent owner-executed restricted offline builds passed
  manual and unified-plugin JVM consumers, Android AAR packaging and the
  separate Android debug APK consumer. Exact results and artifact hashes
  are recorded in [issue 44](44-ubique-binding-smoke-test.md).
  Trusted preparation populated separate plugin/compiler, Android runtime,
  lint 32.3.1 and Linux AAPT2 9.3.1-15703166 dependency graphs online, then
  verified their offline resolution before copying the modules cache.
  Google Maven was required for AndroidX/tool artifacts. Build Tools 36.0.0
  was installed alongside 37.0.0. No sandbox network fallback or task
  disabling was used to bypass the missing artifacts.

  Build units used `env -i`, private loopback without an external route,
  read-only system/home protection, scratch-only writes, `MemoryMax=12G`,
  zero swap, `TasksMax=256`, `CPUQuota=400%`, `RuntimeMaxSec=900`,
  `LimitCPU=600`, `LimitFSIZE=2G` and a 6 GiB scratch tmpfs. Java temporary
  files and Android user state were redirected into scratch. Source and
  copied caches were inside writable scratch: these successful exploratory
  builds do not meet the final read-only-source/cache requirement.
  Reported service memory peaks of approximately 1.7M are not accepted as
  reliable build peak measurements.

  Android runtime execution occurred outside the restricted build unit in
  the preparation guest. Only `builder` received KVM group access;
  `cairn-build` did not. The dedicated emulator used API 26 x86_64 image
  revision 16 and emulator 37.2.12.0 with nested KVM, headless software
  graphics, no audio/snapshots, 2 GiB guest RAM and two virtual CPUs.
  Its supervisor specified a 30-minute runtime and 6 GiB memory limit.
  The actual generated calls passed through installed APK libraries.
  This runtime unit is not proof of offline/no-network test execution:
  the final device/emulator isolation and lifecycle recipe remains open.
  The owner preserved source/artifacts/results root-owned under
  `/opt/cairn-binding-seeds/`; repository import is pending.
  Neither runner lane nor this ticket is resolved.

- 2026-10-10: Owner-authorized SSH replay of the committed fixture passed
  both the combined forced offline build and Android instrumentation.
  The previous scratch source was preserved rather than overwritten.
  The initial preparation-account `cd` into private scratch was correctly
  denied; using `sudo bash` with the absolute script path required no
  permission widening. The emulator ran outside the build sandbox and was
  stopped via an exit trap; subsequent service inspection confirmed
  `ActiveState=inactive`, `SubState=dead`. Retained APK/transcript hashes
  were checked directly. Read-only-source/cache, fresh-image,
  runtime network isolation, CPU enforcement and macOS acceptance remain
  open. See issue 44 for exact results.

- 2026-10-10: Dedicated CPU saturation probe directly verified the build's
  `CPUQuota=400%`. The unit's cgroup `cpu.max` was `400000 100000`.
  Eight CPU-bound subprocesses ran for five seconds each, consuming
  20.290267493 worker CPU seconds over 5.062122952 wall seconds
  (4.008 effective cores). The automated check required 2.5-4.5 effective
  cores and the configured four-core cgroup quota; it passed. The observed
  quota bounded the eight-worker load, not an application performance budget.
  Result JSON is root-owned at
  `/opt/cairn-binding-seeds/allocator-audit-8deda79/cpu-quota-proof.json`.
  CPU quota enforcement is no longer an unmeasured gate for this preparation
  setup. Final read-only-source/cache enforcement, runtime network isolation,
  disposable-image reproduction and macOS acceptance remain open.
