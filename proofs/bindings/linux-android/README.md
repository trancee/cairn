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

The manual runtime recipe above does not enforce offline/no-network execution.
The preferred bounded runtime replay is now:

```bash
sudo bash run-isolated-android.sh
```

Run it as root through sudo from a trusted copy of this directory.
It verifies the unbooted seed's checksum manifest at
`/opt/cairn-binding-seeds/fresh-api26-avd/SHA256SUMS`, creates a sparse
16 GiB ext4 loop-backed filesystem, and copies that fresh AVD
into it without modifying the seed, and stages the built APK there. AVD state,
artifacts and both `/tmp` and `/var/tmp` are confined to this bounded volume.
An over-capacity `posix_fallocate` probe must fail with `ENOSPC`.
It then runs
emulator and ADB together in a private network namespace. It requires only
loopback, rejects usable default routes and checks an external documentation
address fails with `ENETUNREACH` before booting Android. The unit hides other
home directories and guest service sockets, exposes only the dedicated AVD
home, restricts devices to standard pseudo-devices plus KVM, and bounds memory,
CPU, process count, per-file size and runtime. No blanket permissions or
network fallback are enabled.

The disk-bounded script passed directly on the guest: API 26 x86_64
instrumentation succeeded, service runtime was 19.078s, and its result
transcript matched the previous hash. The unit was inactive/dead afterwards
and no owned emulator process remained. Exact script SHA-256 is
`be78f549798a3fd66f53a22a7f5e60cbb87a5c2f1a17e007b612ba7273c9f57c`;
script, logs and checksum manifest are retained root-owned under
`/opt/cairn-binding-seeds/fresh-seed-runtime-proof/`.
The existing outside-namespace ADB server is not stopped; cleanup targets
only the private server and owned emulator. The volume is unmounted and its
exact temporary image removed after results are retained; mount directory,
image and loop attachment cleanup were verified. Concurrent reuse of the
fixed disposable path is rejected. The measured filesystem capacity was
16,729,894,912 bytes (less than the image's 16 GiB bound).
First boot requires 12 GiB free for the default userdata partition; the earlier
8 GiB volume supported only an already initialized AVD. `LimitFSIZE=20G`
allows the over-capacity disk probe to exercise `ENOSPC` rather than fail first
at the per-file limit. Aggregate allocated storage remains bounded by the
16 GiB filesystem; sparse file logical length has a separate per-file ceiling.
This is disposable runtime-state and network/disk-boundary evidence, not a
fresh guest-image reproduction. Before APK installation, the smoke package must
be absent; installation does not use replacement mode. The source/toolchain
guest and trusted administrator remain part of the preparation environment.
Final VM image acceptance remains open.

## Disposable VM replay preparation

`create-offline-clone.sh` is an owner-run Fedora root operation. It requires
`cairn-prep` to be cleanly shut off, refuses an existing proof domain/directory,
and independently converts its qcow2 disk into a root-owned base. A writable
overlay is attached to `cairn-proof-offline`; the clone XML removes all NICs,
cloud-init CD, guest-agent channels, host devices and filesystem sharing.
SELinux remains enabled. The original preparation disk is not a backing file
and the original guest is restarted after the conversion.

The staged `cairn-disposable-boot-proof.service` runs only with loopback as
the sole guest interface. Its condition was verified to skip execution in
the networked preparation guest. `replay-disposable-guest.sh` then mounts
fresh 6 GiB scratch, restores source and downloaded dependencies from
checksum-verified archives, runs the forced build without retained Cargo
outputs, and executes the fresh-seed runtime. Results go to journal/console.
The owner supplied the clone's successful console output on 2026-10-10.
The cold build completed in 4m21s with all 69 actionable tasks executed,
including compilation/installation of the pinned generator. JVM value,
boundary, typed-error and object-lifetime assertions passed. Native packaging
checks passed for Android ARM64/x86_64. The AAR SHA-256 matched
`9876666c5f0eee81389463db7845deb14a69ced46764652fca82f0490d430658`;
the newly built APK SHA-256 was
`1a4bfc129c20baf10669ce6f3b76a6fdcb350e973c516dff8515851bdb04c1de`,
different from the historical APK. The cause of that difference has not been
examined; this is behavior/build-closure proof, not byte-identical APK proof.

The fresh Android runtime passed the loopback/no-default-route and
16,729,894,912-byte filesystem-capacity checks, normal APK installation,
instrumentation code `-1` and value/boundary/error/lifetime completion marker.
The runtime unit exited successfully after 19.828s with reported peak memory
4.4 GiB and zero swap. The final bootstrap marker was
`PASS: cold disposable guest build and fresh Android runtime`.
The 1.6 MiB reported build-memory peak remains implausible and is not accepted
as compilation-memory evidence. The original preparation guest was separately
confirmed reachable over SSH after restart, with its boot-proof unit inactive.
The owner subsequently supplied a passing base checksum and effective live
clone XML. Its sole disk is `run.qcow2`, backed only by the independent
`base.qcow2`; no NIC, CD, filesystem share, host-device passthrough or
guest-agent channel is present. Live XML shows dynamic SELinux/DAC isolation,
8 vCPUs and 16 GiB RAM. This verifies the reported attachment/topology and
unchanged base bytes, not host permission enforcement or completed disposal.
Host base permissions and overlay shutdown/disposal evidence remain pending.
The owner supplied a subsequent passing base checksum and error-free overlay
`qemu-img check` (10,161 allocated clusters, image end offset 667,877,376 bytes).
That excerpt did not include domain state or ownership/modes; neither is
inferred from the image-check result. The overlay remains retained for logs.
Subsequent owner output confirms the clone is `shut off`. Directory mode/
ownership is `root:qemu 0750`, overlay is `root:qemu 0660`, but the base is
`qemu:qemu 0640`, not the requested `root:qemu 0640`. The QEMU account owns
the base and has owner-write permission. The unchanged checksum establishes
no observed mutation during this run, not host-enforced base immutability.
The ownership change's cause has not been verified; future starts must not
assume the creation-time ownership survives libvirt management.
With the clone stopped, the owner restored and confirmed `root:qemu 0640`
on the base. This removes QEMU's Unix write permission for the retained base
now; persistence of that protection across future starts remains unverified.
Full namespace immutability and final runner
acceptance are not established by this successful replay.

### Preparing base ownership protection

The creation recipe now explicitly declares the independent backing store and
sets `<seclabel model='dac' relabel='no'/>` only on its source.
The [libvirt security-label reference](https://libvirt.org/formatdomain.html#security-label)
documents per-source overrides. Dynamic SELinux labeling remains enabled;
overlay ownership handling is unchanged. The owner defined and started the
corrected clone, then confirmed the base remained `root:qemu 0640` and an
actual `os.open(..., os.O_WRONLY)` as QEMU failed with `PermissionError`.
The probe did not truncate or write data. Start-survival and Unix-account
write denial are verified by supplied output; post-stop ownership/checksum
remain pending.
The corrected boot subsequently passed: all 69 actionable tasks executed in
4m17s, JVM assertions and native packaging passed, and fresh Android
instrumentation returned code `-1` and its completion marker. Runtime finished
successfully in 18.468s (reported peak 4.6G, zero swap), followed by the final
cold-build/runtime PASS. AAR hash again matched; APK SHA-256 was
`ad7955fc171d47cc7f9604f7dd7c433e09a182473a12e2b34c9dd66709af08a3`.
The varying debug APK bytes remain unexplained. The reported build-memory
peak 1.7M is not accepted. This reused the retained VM overlay with newly
restored tmpfs build inputs and a fresh AVD, not a newly created VM overlay.
The owner subsequently confirmed `shut off`, base ownership/mode
`root:qemu 0640` and a passing original base checksum. The targeted DAC
override therefore survived the observed start/stop cycle without changing
base bytes. Journal preservation and overlay disposal remain open.

For the existing stopped clone, `protect-base.py INPUT.xml OUTPUT.xml` prepares
the same override from its inactive XML. It rejects other domain names,
unexpected disks/paths, networking/sharing/passthrough and an existing
backing-store override before mutation. The output file must not already
exist. Run `python3 -B proofs/bindings/linux-android/test_protect_base.py` for
its behavior tests. The owner's exported inactive XML was transformed and
`virt-xml-validate OUTPUT.xml domain` passed on Fedora. Definition, live
permissions and QEMU-account write denial subsequently passed as above;
noninteractive host sudo remains unavailable. Do not globally disable libvirt
dynamic ownership or SELinux, and do not discard the retained overlay.

Before the owner-approved shutdown, persistent inputs were saved under
`/opt/cairn-binding-seeds/final-image-inputs-e75437d/`. Cargo registry and
Gradle modules archives exclude compiled Cargo outputs. The fixture archive
excludes Gradle build/state directories. Scratch was a nonpersistent mount,
so the original guest's previous tmpfs state will not survive shutdown.
The clone console is reached through libvirt, not a network connection.
After the proof, final acceptance requires its actual output, original/base
integrity and overlay lifecycle checks; do not infer success from domain
creation. Failed host clone preparation leaves exact files for diagnosis;
it does not destructively remove them or weaken host permissions.

The unbooted seed was created through the installed `avdmanager create avd`
for `system-images;android-26;google_apis;x86_64`, with a dedicated staging
`ANDROID_USER_HOME`/`ANDROID_AVD_HOME` and the name `cairn-api26-x86_64`.
Only the custom hardware-profile prompt was answered `no`. The resulting
`avd/` directory was copied root-owned into the seed path above; a SHA-256
manifest covers its three initial files (AVD registration, config and userdata
image). The script rewrites only the disposable copy's registration path.
The seed manifest passed before and after execution.
One trial adding `-no-metrics` segfaulted before ADB connected; reverting that
unproven launch argument yielded the recorded pass. No general emulator bug
or metrics-option compatibility claim is made; external networking remains
blocked by the namespace independent of emulator metrics settings.

The additional dependency-only APK ABI directories do not expand supported
ABIs. The [bounded allocator audit](ALLOCATOR-AUDIT.md) checked resolved source and
default allocator forwarding in all six delivered Linux/Android Rust ELFs.
Remaining gates include final image/lifecycle acceptance, allocator evidence for new targets/artifacts,
Unicode-specific coverage, Compose, ARM64 hardware, release/R8/page alignment,
iOS 15 device/simulator linkage and runtime, and final runner acceptance.
