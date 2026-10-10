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

## Lane acceptance

The owner approved independent Linux/Android and macOS/iOS proof lanes on
2026-10-10. The baseline tuple above is unchanged and must be revalidated
before execution; the Rust foundation's newer compiler does not silently
replace the interop pin.

| Lane | Binding evidence required | Current state |
|---|---|---|
| Linux/Android | Generated call, typed error and Rust-object lifetime through the planned KMP/app boundary; JVM tests, Android API 26+ build, packaged native/runtime inspection and Android execution | Standalone JVM and Android debug/emulator proof passed; Compose, allocator, release/hardware and final runner acceptance remain open |
| macOS/iOS | Generated call, typed error and Rust-object lifetime through the planned KMP/app boundary; device/simulator-arm64 builds, packaged native/runtime inspection, iOS 15 deployment floor and corresponding execution evidence | Blocked on issue 45's macOS lane |

An accepted runner lane in issue 45 permits only its matching proof here,
even while the other lane remains blocked. Record commands, tool versions,
source revision, artifact inspection and actual execution results separately.
Host JVM execution is not Android device proof; simulator execution is not
physical iOS device proof. This ticket resolves only after all original
acceptance conditions are met across both lanes. S0 remains blocked until
then; no protocol implementation is authorized by this split.

## Comments

- 2026-10-10: Owner-executed unified-plugin JVM smoke also passed offline.
  Ubique plugin 1.3.1 ran `cargoBuildX64LinuxGnuDebug`, `installBindgen`
  against the preserved pinned local source, `buildBindings` and
  `mergeUniffiJvmResources`; no manual binding or library copies were used in
  this fixture. The separate consumer reported both value/error/lifetime
  `PASS` markers, with `BUILD SUCCESSFUL`, exit 0 and 5m10.725s service
  runtime (7m36.971s aggregate CPU). The initial fixture script needed an
  explicit `java.io.File` import because Gradle's `java` accessor shadowed
  the package name; no version or isolation change was required.
  This supersedes the earlier lack of unified-plugin JVM evidence, not the
  remaining Compose, Android, iOS, allocator-audit or runner acceptance
  gaps. Subsequent packaged SDK JAR inspection found
  `linux-x86-64/libcairn_binding_smoke.so` (6,550,680 bytes). The preserved
  `/opt/cairn-binding-seeds/unified-jvm-source.tar.gz` has SHA-256
  `93d4d91d47cdd655f0e10513a0d295223f7b91c035f25124610aef38ed694a3b`.
  Service memory peaks are still not accepted as reliable
  compilation-memory measurements.

- 2026-10-10: Owner-executed manual-generation JVM smoke passed offline in
  the restricted Ubuntu guest. A standalone Rust arithmetic/Greeter fixture
  generated common/JVM bindings with Ubique revision
  `b819fb4ea33d0ddeb3f1970e5b0d7367c3c7d300`, UniFFI 0.32.0 and Rust 1.97.1.
  Kotlin 2.4.20 compiled the bindings in a KMP `sdk` module; a separate KMP
  `consumer` JVM module executed `:consumer:interopSmoke` using JDK 21,
  Gradle 9.7.0 on JDK 25.0.4.1 and runtime 1.3.1/JNA 5.19.1.
  The consumer checked addition and its integer boundary, a typed overflow,
  string roundtrip, explicit object close, rejection of a post-close call
  and repeat close. Both `PASS` markers were reported, with exit 0 and
  `BUILD SUCCESSFUL` (7.037 seconds service runtime).

  External networking remained disabled, with writes restricted to bounded
  scratch. Java required
  `JAVA_TOOL_OPTIONS=-Djava.io.tmpdir=/srv/cairn-generator-scratch`;
  `TMPDIR` alone left Kotlin's temporary file under read-only `/tmp`.
  Missing compiler/runtime downloads were populated separately outside
  build execution, without enabling sandbox networking. Generated
  expect/actual-class beta warnings were reported and not suppressed.
  Reported service memory peaks are implausibly low and are not accepted as
  build-memory measurements.

  This is owner-supplied host execution evidence, not a unified Ubique plugin
  integration or Compose app proof. Android packaging/device calls, iOS
  builds/deployment-floor/runtime proof, default-allocator dependency audit,
  reproducible fixture retention and final disposable-runner acceptance
  remain open. This ticket and S0 are not resolved.

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

- 2026-10-10: Owner-executed Android debug packaging and runtime proof passed
  with the pinned unified plugin in the restricted offline Ubuntu build unit.
  `:sdk:bundleAndroidMainAar` completed in 3m48s (20 executed tasks, four
  up-to-date); `sdk.aar` contains classes, manifest, AAR metadata and
  `libcairn_binding_smoke.so` for `arm64-v8a` and `x86_64`. Its SHA-256 is
  `9876666c5f0eee81389463db7845deb14a69ced46764652fca82f0490d430658`.
  The separate `androidConsumer` uses AGP's built-in Kotlin and platform
  instrumentation, not Compose. `:androidConsumer:assembleDebug` completed
  in six seconds (23 executed tasks, 30 up-to-date); APK SHA-256 is
  `3359a8c51448bcac3039401924235b5a7cb671a38b76485863a7c158a6a8d2ea`.
  Both ARM64 and x86_64 APK directories contain the smoke crate,
  `libuniffi_runtime.so` and `libjnidispatch.so`. Other dependency-only ABI
  directories lack the smoke crate and are not supported-platform evidence.
  AGP reported that debug native symbols were packaged unstripped.

  Outside the build unit, the owner booted the dedicated API 26 x86_64
  Google APIs image revision 16 with emulator 37.2.12.0 (build 16428233).
  Nested KVM acceleration passed; Android boot completion, ABI and package
  manager were checked explicitly. APK installation into user 0 succeeded.
  `adb -s emulator-5554 shell -T am instrument --user 0 -w -r
  ch.trancee.cairn.consumer/.SmokeInstrumentation` returned
  `INSTRUMENTATION_CODE: -1` and the assertion-completion marker
  `PASS: Android value, boundary, typed error and object lifetime`.
  Assertions covered addition, `Int.MIN_VALUE`, typed `Int.MAX_VALUE + 1`
  overflow, Greeter string roundtrip, explicit close, post-close rejection
  and repeat close. No Unicode-specific test was run.

  The owner checksum-verified preservation of the APK, instrumentation
  output and source archive under
  `/opt/cairn-binding-seeds/android-runtime-passed/`; archive and log digests
  remain in the guest's `SHA256SUMS` and have not been supplied here.
  The emulator-stop command was issued; no subsequent service-state output
  was supplied. Source import and reusable repository invocation are pending.
  This is owner-reported debug emulator evidence, not an independently
  replayed clean build, Compose integration, ARM64 hardware, release/R8,
  default-allocator audit, iOS or complete S0/runner acceptance.

- 2026-10-10: The owner transferred the exact preserved source archive and
  its checksum manifest. Archive SHA-256
  `b64dcbea8f0b1d374f39cb64c06cc14e8b1d124fd7c387735631ad502effbdf2`
  matched locally. Source/configuration and Cargo.lock were imported unchanged
  into [the standalone fixture](../../../proofs/bindings/linux-android/README.md);
  the task-discovery log and binary/generated artifacts were not imported.
  The supplied transcript hash is
  `5f08708a8a1f1aaad51d9adac7f79350d3fe1488a8a02434d7a215871fd44c7b`;
  the transcript was not transferred. The UniFFI lock checker confirmed
  0.32.0 for all eight recognized packages, not allocator compatibility.
  Reusable build/runtime scripts capture the previous commands with forced
  task execution and explicit target/result checks. Their combined replay
  still requires execution on the capable guest; no new platform pass is
  claimed from local source checks.

- 2026-10-10: Owner authorized direct SSH through the Fedora host to the
  preparation guest. The assistant deployed commit `8deda79`, preserving
  the previous scratch fixture as `android-interop-before-8deda79`.
  `sudo bash /srv/cairn-generator-scratch/android-interop/build-offline.sh`
  passed: 69 actionable tasks executed, `BUILD SUCCESSFUL` in 3m46s,
  service exit 0, 3m46.235s runtime and 5m57.247s aggregate CPU.
  JVM assertions and both ARM64/x86_64 native packaging checks passed;
  AAR/APK hashes matched the earlier preserved artifacts exactly.
  The committed `run-android.sh emulator-5554` also passed after explicit
  API 26 x86_64 boot readiness, with instrumentation code -1 and completion
  marker. Transcript SHA-256 matched
  `5f08708a8a1f1aaad51d9adac7f79350d3fe1488a8a02434d7a215871fd44c7b`.
  APK/transcript were retained root-owned under
  `/opt/cairn-binding-seeds/repository-replay-8deda79/`.
  Emulator shutdown ran through an exit trap. This is directly observed
  replay, not merely owner-pasted output; retained Cargo/dependency caches
  were used and no fresh disposable image, allocator audit or additional
  platform gate is claimed.

- 2026-10-10: Direct SSH inspection completed bounded
  [Linux/Android allocator evidence](../../../proofs/bindings/linux-android/ALLOCATOR-AUDIT.md).
  Locked offline metadata plus package-scoped normal/build trees covered
  Linux x86_64 and both packaged Android targets. Identified custom
  allocator declarations were standalone dependency test targets, not
  production library overrides. Actual delivered smoke/runtime ELFs for
  all three targets were inspected: all four global allocator entry points
  forward to Rust default `__rdl_*` functions. APK/JAR entries matched the
  inspected bytes. No runtime replacement or feature change was made.
  This does not attest reproducible upstream builds, Apple allocator/linkage,
  new feature graphs, or overall memory safety. The full ticket remains open.

- 2026-10-10: The strengthened offline build with read-only actual source,
  configuration and downloaded dependency mounts passed all 69 actionable
  tasks and the same artifact hashes. Automated input probes require `EROFS`
  before Gradle. Writable project shells/metadata and retained build outputs
  remain limitations; see issue 45. No new runtime/platform coverage was
  claimed from this build-only replay.
