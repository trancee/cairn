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
| Linux/Android | Disposable Linux environment; Rust host tests, Kotlin/JVM integration, Android builds and generated-call execution | Cold networkless build/runtime, protected base start/stop, read-only journal extraction and authorized overlay disposal pass; full namespace immutability remains open |
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

- 2026-10-10: Owner executed explicitly authorized canonical disposal:
  boot log and both image hashes passed; all three raw-journal input markers
  exported and verified, final runtime marker present. Only
  `cairn-proof-canonical` undefined and its `run.qcow2` removed; script's
  absence checks passed and retained base checksum OK. Canonical clone's
  cold-build/runtime, protected base, journal and disposal lifecycle are
  verified. Workspace shells/cache coordination metadata remain writable
  scratch state, not immutable canonical inputs. Full runner acceptance and
  Apple lane remain open; new mapping/scripts/evidence are uncommitted.

- 2026-10-10: Owner raw-journal search found both early canonical read-only/
  same-object mapping PASS markers at8.004821s. Unit-filtered export omitted
  them; no logging loss established. All three input assertions now have
  retained cold-clone evidence. Canonical extraction recipe updated to export
  exact marker lines across the journal, require all three and checksum them.
  Existing journal remains preserved. Writable workspace/cache metadata are
  still explicit state; overlay disposal awaits separate authorization.

- 2026-10-10: Owner's filtered canonical proof log contains the post-build
  canonical manifest PASS, but neither requested early read-only/identity
  marker. Those early assertions are not independently confirmed for this
  cold clone from the retained unit-filtered log. Full raw-journal search
  and possible logging-loss diagnostics remain needed; preparation-guest
  probe passes do not substitute for this missing clone evidence.

- 2026-10-10: Owner confirms canonical clone shut off, base still
  `root:qemu 0640`, and read-only journal extraction PASS with original base
  and pre/post overlay hashes OK. Evidence retained root-only at
  `/var/lib/cairn-proof-evidence/canonical-replay-journal`.
  Assistant retrieved exported live XML and verified sole independent base
  backing, base-only DAC override, dynamic SELinux and no NIC/filesystem/
  hostdev/channel. Early identity/mount probe log extraction still pending;
  canonical overlay disposal not authorized.

- 2026-10-10: Owner's live canonical-clone checks show sole disk `vda`
  attached to `cairn-proof-canonical/run.qcow2`, no interfaces, base
  `root:qemu 0640`, and QEMU-account `O_WRONLY` open denied. Live Unix base
  write denial verified for this new clone. Full backing/share topology,
  post-stop state/hash, journal and disposal remain pending.

- 2026-10-10: Owner supplied canonical clone cold replay PASS:69/69 tasks
  in4m25s, JVM assertions/native packaging, canonical manifest unchanged.
  AAR unchanged; APK
  `f473420b64a2a99896555f432508baff6549a0fcee3a57e2dcfb58aecd2ba76b`.
  Fresh Android instrumentation code-1/marker and final bootstrap PASS.
  Runtime20.032s peak4.5Gzero swap; build1.8M not accepted.
  Excerpt omits early identity/mount probes; full journal still needed.
  New clone topology/live base denial/post-stop ownership+hash/journal/
  disposal pending. Changes uncommitted; final acceptance remains open.

- 2026-10-10: Owner explicitly authorized clean shutdown of only
  `cairn-prep` and a new `cairn-proof-canonical` clone in its own directory,
  retaining prior base/evidence. Added bounded `canonical` selector to
  clone/extraction/disposal recipes; defaults unchanged and other selectors
  rejected. Current supervisors and canonical manifests verified before
  poweroff, neither proof unit active. Shutdown requested over authorized SSH;
  `~/cairn-create-canonical-clone.sh` staged on Fedora for owner sudo.
  Creation/start and new cold-image results pending; disposal of the new
  overlay is not yet authorized.

- 2026-10-10: Complete canonical mapping implemented without changing
  imported Gradle/Rust configs or pins. Trusted preparation creates separate
  root-owned nonwritable canonical source/registry/module contents and a full
  checksum manifest. Build binds each consumed source/config tree and
  downloaded content from canonical objects into writable disposable shells;
  probes assert samefile identity, covering read-only mounts and denied
  canonical additions/file writes. Direct fresh-scratch forced build passed
  69/69 tasks in4m17s, JVM assertions/native packaging, pre/post canonical
  manifest checks. AAR unchanged; APK
  `11958baaad9a61fc26a60511c1a93ae23403095360e3005f99c3cb7baed14d95`.
  Fresh Android runtime passed19.436s, reported peak4.6G zero swap; build1.5M
  not accepted. Updated bootstrap consumes current saved build supervisor.
  New cold VM replay remains pending; writable workspace/cache metadata remain
  explicit state. New scripts/docs are uncommitted.

- 2026-10-10: Owner selected investigation of separated immutable inputs/
  disposable writable workspace without changing pins. Direct preparation-
  guest systemd probe passed: canonical archived source root-owned under
  `/opt/cairn-binding-seeds/source-namespace-probe`, writable shells under
  `/srv/cairn-source-namespace-probe`, read-only binds for build file/Rust
  crate. Covering mount flags `ro`; canonical additions/removals and bound
  source additions failed `EROFS`, existing-file writes failed `EACCES`;
  project shells writable and mounted build/source/lock bytes identical.
  Initial strict errno and exact-mount assumptions failed and were corrected.
  No baseline changes or complete Gradle build in this layout yet. Full
  mapping/cache separation and cold-clone replay remain required before any
  acceptance change.

- 2026-10-10: Committed extraction/disposal as `1fe7471`. Investigated
  remaining project-namespace constraint against pinned upstream Gradle.
  `DefaultSettingsPreparer.java` at v9.7.0 lines307-333 unconditionally checks
  every project's directory exists/is-directory/`canWrite()` after settings
  evaluation. A wholly read-only project directory cannot pass this baseline;
  moving caches/output alone does not bypass the check. Existing actual
  sources/config/dependency files remain read-only; writable scratch project
  shells are explicit state. No validation bypass or pin change proposed.
  Any different workspace layout or acceptance interpretation needs a
  documented decision before implementation.

- 2026-10-10: Owner explicitly approved targeted domain/overlay disposal,
  then supplied successful `dispose-overlay.sh` output. Preserved proof log
  and both pre-disposal image hashes checked OK; both replay markers retained.
  Inactive XML saved with evidence, only `cairn-proof-offline` undefined and
  only `run.qcow2` removed. Script's domain/overlay absence checks passed;
  retained base checksum OK. Journal and base remain intact; original prep
  unaffected by this script. Observed disposal lifecycle is complete.
  Full source/cache namespace and macOS lane remain unresolved; ticket stays
  claimed. Extraction/disposal recipes and evidence are uncommitted.

- 2026-10-10: Owner executed `preserve-journal.sh` successfully with
  guestfish 1.60.1. Read-only extraction retained the journal and filtered
  boot-proof log root-only at
  `/var/lib/cairn-proof-evidence/protected-replay-journal`; both replay
  completion markers were present. Base and overlay checksum comparisons
  passed after extraction. Guest hostname in the log is inherited
  `cairn-prep`, not the libvirt domain identity. Clone-state/path guards target
  the stopped proof overlay. Journal preservation is verified; overlay
  disposal awaits explicit approval. Extraction script/docs are uncommitted.

- 2026-10-10: After the protected replay, owner confirms clone `shut off`,
  base still `root:qemu 0640`, original base checksum OK. Combined with live
  QEMU-account write denial, targeted base ownership protection survives the
  observed start/stop cycle and base bytes remain unchanged. Journal
  preservation/overlay disposal and full namespace/Apple acceptance remain
  open; correction and follow-up evidence are uncommitted.

- 2026-10-10: Owner supplied corrected boot completion: 69/69 build tasks
  executed in 4m17s, JVM assertions/native packaging passed; fresh Android
  instrumentation code `-1` and completion marker passed, followed by final
  cold-build/runtime PASS. Runtime 18.468s, reported peak4.6G, zero swap.
  AAR unchanged; APK SHA-256
  `ad7955fc171d47cc7f9604f7dd7c433e09a182473a12e2b34c9dd66709af08a3`.
  Debug APK differences remain unexamined; build peak1.7M not accepted.
  This boot reused retained VM overlay, while scratch/build outputs and AVD
  were recreated. Live base write denial was already verified; post-stop
  ownership/checksum and journal/disposal remain pending.

- 2026-10-10: Owner defined the protected XML and started the clone
  successfully. While running, base remained `root:qemu 0640`; QEMU-account
  `os.open` with `O_WRONLY` failed with `PermissionError` and printed the
  required PASS. Probe did not truncate/write data. DAC override survives
  this start and Unix-account write denial is observed. Corrected boot
  completion, post-stop permissions/checksum and journal preservation/
  overlay disposal remain pending.

- 2026-10-10: Retrieved owner's inactive XML over authorized SSH.
  `protect-base.py` prepares explicit independent base backing-store with
  DAC-only `relabel='no'`; creation recipe now uses the same override.
  Intended-behavior tests failed before implementation and passed afterwards,
  including rejection without mutation of unrelated/unsafe inputs.
  Generated `~/cairn-proof-protected.xml` on Fedora passed
  `virt-xml-validate ... domain`. No domain definition/start or write-denial
  check has run; original overlay retained. Host owner authentication remains
  the blocker. Changes after `a7b7721` are uncommitted.

- 2026-10-10: Committed cold replay evidence/bootstrap as `a7b7721`.
  Follow-up host inspection finds no `guestfish` or `virt-copy-out`; Fedora
  sudo still requires owner authentication. Official libvirt
  [domain/security-label reference](https://libvirt.org/formatdomain.html#security-label)
  documents per-source labeling overrides, including a DAC-only
  `<seclabel model='dac' relabel='no'/>`. Candidate correction is on the
  base's explicit backing-store source only, retaining dynamic SELinux and
  normal overlay ownership management. No correction or start-survival test
  has been executed. Obtain inactive XML before preparing the guarded change;
  do not globally disable dynamic ownership or SELinux.

- 2026-10-10: With the proof clone stopped, owner restored base ownership/
  mode and supplied `root:qemu 0640`. Current Unix permissions deny QEMU
  writes to the retained base. Durable enforcement across future libvirt
  starts remains unverified; this does not retroactively establish a
  host-enforced immutable base during the completed run.

- 2026-10-10: Owner confirms proof clone `shut off`; directory is
  `root:qemu 0750`, overlay `root:qemu 0660`, base `qemu:qemu 0640`.
  Base ownership differs from the creation script's root-owned intent:
  QEMU has owner-write permission. Unchanged base hashes prove no observed
  mutation, not enforced host-level base immutability. Ownership-change cause
  and durable enforcement across libvirt starts remain unresolved. Overlay/
  journal are retained; no deletion authorized or performed.

- 2026-10-10: Owner supplied another passing base checksum and a successful
  `qemu-img check` of the overlay: no errors, 10,161/2,097,152 allocated
  clusters and image end offset 667,877,376 bytes. The supplied excerpt omits
  `domstate` and host ownership/mode output, so shutdown and permissions are
  not inferred from image-check success. Overlay remains retained for journal
  extraction; disposal is not verified.

- 2026-10-10: Owner supplied `base.qcow2: OK` from the saved checksum
  check, a sole `vda` attachment to `run.qcow2`, and effective live XML showing
  that overlay backed only by the independent `base.qcow2`. No NIC, CD,
  filesystem share, hostdev or guest-agent channel is present. Dynamic
  SELinux/DAC labels are active in the reported XML; VM has 8 vCPUs and
  16 GiB RAM. Base bytes and attachment topology are verified by supplied
  output. Host permission enforcement, clean shutdown and overlay disposal
  remain open; this does not close full namespace or Apple acceptance.

- 2026-10-10: Owner supplied successful cold clone console output. All 69
  actionable build tasks executed in 4m21s, including pinned bindgen
  installation; JVM assertions and ARM64/x86_64 native packaging passed.
  Fresh Android runtime checked loopback/no default routes and filesystem
  capacity 16,729,894,912 bytes, then installed the APK and passed
  instrumentation code `-1` and the value/boundary/error/lifetime marker.
  Runtime exited 0 after 19.828s (reported memory peak 4.4G, zero swap).
  Bootstrap printed `PASS: cold disposable guest build and fresh Android runtime`.
  AAR hash matched the preserved artifact; APK hash changed to
  `1a4bfc129c20baf10669ce6f3b76a6fdcb350e973c516dff8515851bdb04c1de`;
  the difference is unexplained, not byte-identical reproduction.
  Reported build peak 1.6M is not accepted as reliable memory evidence.
  Assistant separately confirmed original prep SSH reachability and inactive
  boot-proof service after restart. Host base-checksum/permissions, effective
  clone XML, shutdown and overlay disposal remain unverified; full source/cache
  namespace immutability and macOS lane remain open. This is partial evidence,
  not resolution or final runner acceptance.

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

- 2026-10-10: The build recipe now uses read-only mounts for Gradle
  configuration files, Rust crate/lockfile and consumer source trees,
  Cargo registry source/archive/index and Gradle downloaded artifact files.
  A probe verified `EROFS` on existing inputs and writable named output
  directories. Whole-project read-only mounts failed Gradle 9.7.0's
  writable-project-directory configuration check; the actual input files
  and source subtrees were mounted individually instead. Project shells,
  coordination/metadata state and scratch outputs remain writable.
  This does not silently waive the final immutable-namespace gate.

  The strengthened `build-offline.sh` includes an input-write-denial
  assertion before Gradle and passed directly over SSH with 69/69 tasks
  executed, 11s build time, 12.040s service runtime and 36.741s aggregate
  CPU. Both AAR/APK hashes matched earlier evidence. All original source
  hashes except the intentionally updated script remained unchanged.
  Exact script SHA-256 is
  `9a53e64fdf898ed5ddd3ab7998d369e3dbca957491f0fa7d560e48d70563577b`;
  a root-owned copy is retained under
  `/opt/cairn-binding-seeds/readonly-input-proof/`.
  This used retained Cargo outputs/dependency caches, not a fresh final VM.
  Final cache/project namespace immutability, offline runtime isolation,
  disposable-image reproduction and Apple runner acceptance remain open.

- 2026-10-10: New `run-isolated-android.sh` runs ADB and the emulator in
  the same `PrivateNetwork=yes` unit, with only loopback, no usable default
  routes and an explicit external-address `ENETUNREACH` assertion.
  An initial `ip route` probe could not open netlink under the AF allowlist;
  it was replaced with fail-closed `/proc` route inspection rather than
  interpreting failed commands as empty routes. The corrected script passed
  directly: Android API 26 x86_64 instrumentation completed, 16.405s service
  runtime, 17.107s CPU and 1.7 GiB reported peak memory. The runtime memory
  measurement is distinct from the implausible historical build-unit peaks.

  The unit exposes only the dedicated AVD home through `ProtectHome=tmpfs`
  plus a bind mount, protects the system, hides `/run` and `/dev/shm`,
  and uses device policy for standard pseudo-devices plus `/dev/kvm`.
  It sets 6 GiB memory/no swap, 256 tasks, 400% CPU, 300s runtime,
  240s per-process CPU and 12 GiB per-file limits. It grants no permanent
  KVM access to the build account. Trap cleanup stops the owned emulator
  and private ADB server; service inactive/dead and no owned emulator process
  were verified afterwards. Existing outside-namespace ADB was untouched.

  Exact script SHA-256 is
  `b9f41ade53fe181c2dd22e8cebc63cb0009daf528189529c149f8673b28da9af`.
  Script/logs and the matching instrumentation transcript hash are retained
  root-owned under `/opt/cairn-binding-seeds/isolated-runtime-proof/`.
  Runtime AVD/private temporary storage still lacks a dedicated total-disk
  quota and persists between runs. Final runtime filesystem/disk acceptance,
  full input namespace immutability, disposable image and Apple lane remain
  open; network-isolated Android execution alone does not resolve the ticket.

- 2026-10-10: Runtime storage is now a disposable sparse 8 GiB ext4 image
  mounted `nosuid,nodev`; a copied AVD, artifacts, `/tmp` and `/var/tmp`
  share its bounded filesystem. Measured capacity is 8,350,298,112 bytes.
  Before emulator launch, over-capacity `posix_fallocate` must fail with
  `ENOSPC`; that assertion and the network/Android FFI assertions passed.
  Final service runtime was 16.467s, CPU 17.234s, reported peak 1.8 GiB.
  Seed AVD is copied sparsely and not intentionally modified.
  The runtime unit was inactive/dead afterwards, with mount directory,
  image and loop-device attachment confirmed removed. Logs/script are
  retained root-owned under
  `/opt/cairn-binding-seeds/disposable-runtime-proof/`.
  Exact script SHA-256 is
  `4f247ab1b0380e0c2dab4045214821c99716149f01d255e46ec1beee1ac3e4fb`;
  transcript hash matches earlier successful instrumentation.
  This supersedes the missing runtime total-disk bound and persistent
  per-run AVD state, not the retained seed or final disposable guest-image
  requirement. Source namespace/metadata immutability, fresh seed/image
  reproduction and macOS lane remain open.

- 2026-10-10: Fresh AVD-seed runtime reproduction passed. A dedicated
  `avdmanager` staging directory created an unbooted API 26 x86_64 image
  revision 16 AVD; its three files were preserved root-owned with checksums
  under `/opt/cairn-binding-seeds/fresh-api26-avd/`. The runtime script
  verifies checksums, sparsely copies this seed and rewrites only the copy's
  registration path. The smoke package must be absent before normal install.

  Initial 8 GiB first boot failed because the emulator requires 12 GiB free
  for userdata creation; the disposable filesystem now has a 16 GiB image
  bound (16,729,894,912 usable bytes), with a separate 20 GiB per-file
  logical-size ceiling so the disk probe reaches `ENOSPC`. That assertion,
  private network checks and first-boot instrumentation passed. A trial
  adding `-no-metrics` crashed before ADB connection; removing the unproven
  flag restored the previously tested launch argument set. No unsupported
  suppression, network fallback or claimed emulator root-cause fix was used.

  Successful service runtime: 19.078s, CPU 25.672s, reported peak 3.1 GiB.
  Seed hashes remained unchanged. Service inactive/dead, disposable image,
  mount and loop cleanup were verified. Exact script SHA-256 is
  `be78f549798a3fd66f53a22a7f5e60cbb87a5c2f1a17e007b612ba7273c9f57c`;
  transcript again matched prior evidence. Root-owned retained results are
  under `/opt/cairn-binding-seeds/fresh-seed-runtime-proof/`.
  Fresh runtime state is now evidenced, not a disposable final guest image.
  Full source/cache namespace enforcement and final VM-image/Apple
  acceptance remain open.

- 2026-10-10: Owner supplied live VM XML and explicitly approved clean
  shutdown of `cairn-prep` plus owner-run host clone commands. Source, Cargo
  registry and Gradle modules were checksum-verified on persistent guest disk
  under `final-image-inputs-e75437d`, excluding compiled build outputs.
  A loopback-only boot service was staged and verified to skip in the
  networked preparation guest. Clean guest poweroff was requested over SSH.
  Fedora noninteractive sudo/libvirt authorization remains unavailable;
  `create-offline-clone.sh` is staged for the owner's terminal authentication.
  It creates an independent qcow2 base and overlay, removes network/sharing
  and restarts the original guest after copying. Clone execution, cold-build
  results and base/overlay integrity remain pending, not passed evidence.
