# Linux/Android binding proof fixture

This standalone fixture captures the owner's passing 2026-10-10 Ubique
debug binding experiment. It is not the Cairn SDK, a Compose app, a protocol
implementation or an accepted final runner. No cryptographic API is exported.

## Source and observed evidence

Gradle/Cargo/Kotlin/Rust/manifest files are imported unchanged from
`android-source.tar.gz`, SHA-256
`b64dcbea8f0b1d374f39cb64c06cc14e8b1d124fd7c387735631ad502effbdf2`.
The task-discovery log was excluded. No generated bindings, native binaries,
APK, debug signing key or downloaded dependencies are checked in.

The root build owns Kotlin `2.4.20`, AGP `9.3.1` and Ubique `1.3.1`;
UniFFI is exactly `0.32.0` in the Rust manifest/lockfile. The generator source
must be Ubique revision `b819fb4ea33d0ddeb3f1970e5b0d7367c3c7d300`.
The preserved upstream `Cargo.lock` hash is
`f98610fdac2c98c54e4720656003db31fd1706692bc25b4e1be3c7653e84495a`.
Cargo package/library are `cairn-binding-smoke` / `cairn_binding_smoke`;
the generated Kotlin package is `ch.trancee.cairn.smoke`.

| Module | Target/host | Task and proof | Limitations |
| --- | --- | --- | --- |
| `sdk` | JVM/Linux x86_64 | `jvmJar`; generated API and native JVM resources | Host-specific debug artifact |
| `consumer` | JVM/Linux x86_64, JDK 21 | `interopSmoke`; value, integer boundary, typed overflow, string roundtrip and close behavior | Not Android or Compose |
| `sdk` | Android API 26+, Linux build host | `bundleAndroidMainAar`; ARM64/x86_64 Rust compilation and native packaging | No ARM64 execution |
| `androidConsumer` | API 26 x86_64 emulator | `assembleDebug`, then platform instrumentation; packaged FFI calls and lifetime checks | No physical device, release/R8 or Compose |

The owner-reported APK hash was
`3359a8c51448bcac3039401924235b5a7cb671a38b76485863a7c158a6a8d2ea`;
AAR hash was
`9876666c5f0eee81389463db7845deb14a69ced46764652fca82f0490d430658`.
These identify preserved artifacts, not reproducible-byte expectations:
debug signing and build environment can change APK bytes.
The instrumentation transcript hash supplied in `SHA256SUMS` was
`5f08708a8a1f1aaad51d9adac7f79350d3fe1488a8a02434d7a215871fd44c7b`;
the transcript itself was not transferred to this checkout.
See [binding evidence](../../../.scratch/cairn-r1/issues/44-ubique-binding-smoke-test.md)
and [runner limitations](../../../.scratch/cairn-r1/issues/45-provision-isolated-build-runner.md).

## Replaying on the provisioned Ubuntu guest

These scripts capture the tested invocation in reusable form. The combined forced build and replacement-install script were replayed over
owner-authorized SSH on the preparation guest from commit `8deda79`.
All 69 actionable build tasks executed successfully in 3m46s; JVM assertions
and native packaging checks passed. The rebuilt AAR/APK hashes matched the
preserved artifacts above. Android instrumentation passed on API 26 x86_64;
its transcript hash also matched. The owned emulator was stopped afterwards.
These are not general provisioning tools or default CI gates; retained Cargo
and dependency caches were used, not a fresh disposable image.

Prerequisites must be prepared through trusted downloads before any build:

- The dedicated `cairn-build` account, systemd controls and a mounted 6 GiB
  scratch tmpfs at `/srv/cairn-generator-scratch`.
- Rust `1.97.1` at `/opt/cairn-toolchains/rust-1.97.1`, with Linux host and
  Android standard libraries; Gradle `9.7.0` and Temurin `25.0.4.1` under the
  matching `/opt/cairn-toolchains/` names; JDK 21 at
  `/usr/lib/jvm/java-21-openjdk-amd64`.
- Root-owned Android SDK at `/opt/cairn-toolchains/android-sdk`, platforms
  26/37, Build Tools `36.0.0` and `37.0.0`, NDK `30.0.16248370`.
- Pinned generator source at `/opt/cairn-binding-seeds/ubique`, and complete
  offline Cargo/Gradle caches at the paths in `build-offline.sh`.
  Separate graphs include Android runtime/JNA AARs, lint `32.3.1` and
  Linux AAPT2 `9.3.1-15703166`. Cache preparation uses Google Maven and Maven
  Central; the build itself may not fetch dependencies.

Deploy this directory's source and scripts to
`/srv/cairn-generator-scratch/android-interop`, owned by `cairn-build`.
Do not overwrite an existing working fixture: preserve it first. The fixed
guest paths in the imported build configuration are intentionally retained.
The root Gradle project name remains the historical `cairn-jvm-interop`.
The fixture uses a trusted preinstalled Gradle distribution, not a wrapper.

As the preparation administrator, use the absolute script path: private
scratch is not traversable by `builder` without sudo.

```bash
sudo bash /srv/cairn-generator-scratch/android-interop/build-offline.sh
```

It forces the three proof tasks to rerun in one offline, allowlisted
systemd unit, executes the JVM assertions and checks the delivered native
entries. It does not install packages, boot an emulator or retry online.
The build now mounts all Gradle build/settings/properties files, the Rust
crate tree and consumer source trees read-only. Cargo's entire registry
(source/archive/index) and Gradle's downloaded `files-2.1` artifacts are
read-only too. The unit checks representative existing inputs for `EROFS`
before invoking Gradle; an unexpectedly writable input fails the proof.
The strengthened forced build passed with all 69 actionable tasks executed
and unchanged AAR/APK hashes. Original source hashes were unchanged.

Gradle 9.7.0 rejected whole-project-directory read-only mounts because it
requires writable project directories during configuration. Project-directory
shells therefore remain writable inside bounded scratch, with the actual
configuration files and source subtrees mounted read-only. Named
`.gradle`, `.kotlin` and module/root `build` directories are writable.
Cargo target outputs and cache coordination/Gradle metadata remain writable
state; this is downloaded-input immutability, not an entirely immutable
cache namespace or a complete immutable project namespace. The root-owned
generator/toolchain sources remain protected by `ProtectSystem=strict`.
Final disposable-image and full namespace acceptance remain open.
A dedicated eight-worker saturation probe measured 4.008 effective CPU
cores under the exact 400% quota; see the runner evidence. Implausible
historical systemd memory peaks are not accepted.

For runtime proof, first boot the dedicated `cairn-api26-x86_64` AVD outside
the build unit. The observed setup used emulator `37.2.12.0` (build
`16428233`), Google APIs API 26 x86_64 image revision 16, nested KVM, headless
SwiftShader, two CPUs and 2 GiB emulator RAM. KVM is granted only to
`builder`, not the build account. Android boot, SDK, ABI and package-manager
readiness must pass; an ADB transport alone is insufficient.

As `builder`, with that AVD running:

```bash
bash run-android.sh emulator-5554
```

This replaces only `ch.trancee.cairn.consumer` on user 0 of the dedicated
AVD. It grants no blanket permissions and does not clear app data or logs.
The script requires both the instrumentation success code and the completion
marker; process exit alone is insufficient. All ADB commands bind the target
explicitly and disconnect stdin to avoid consuming enclosing shell scripts.
Results are retained under `$HOME/cairn-emulator/artifacts/`.
Stop the owned emulator afterwards:

```bash
sudo systemctl stop cairn-api26-emulator
```

This runtime recipe is not yet an enforced offline/no-network test unit.
The additional dependency-only APK ABI directories do not expand supported
ABIs. The [bounded allocator audit](ALLOCATOR-AUDIT.md) checked resolved source and
default allocator forwarding in all six delivered Linux/Android Rust ELFs.
Remaining gates include clean-run reproduction, allocator evidence for new targets/artifacts,
Unicode-specific coverage, Compose, ARM64 hardware, release/R8/page alignment,
iOS 15 device/simulator linkage and runtime, and final runner acceptance.
