# Linux/Android binding proof fixture

This standalone fixture captures the owner's passing 2026-10-10 Ubique
debug binding experiment. It is not the Cairn SDK, a Compose app, a protocol
implementation or an accepted final runner. No cryptographic API is exported.

## Source and observed evidence

Linux runner acceptance is assessed against issue 45, not against an entirely
read-only Gradle working directory. Canonical inputs must be immutable;
project shells, generated sources, cache coordination and compiler outputs
may be writable only in assigned disposable scratch. The canonical replay
proves that distinction. Remaining reconciliation is effective resource-limit
assertions for the integrated units and an explicit retained proof-log bound;
the successful replay alone does not establish those checks or Apple support.

### Pending integrated resource and output checks

`check-resources.py build|runtime` observes its own cgroup v2 membership and
checks effective memory/swap/tasks/CPU quota plus inherited CPU/file/core
rlimits. The `--snapshot` option checks saved observations for CLI regression
tests; proof units always use live observations. Both resource profiles passed
direct guest execution, including the actual build/runtime units.

The owner approved a 64 MiB per-replay proof-output budget, failing explicitly
on overflow. `bounded-proof.py OUTPUT COMMAND...` retains and mirrors combined
command output up to that bound, propagates child failures and terminates its
owned process group on overflow. `run-bounded-replay.sh` wraps the bootstrap
and stops the two proof units if the command fails. The updated boot unit uses
this supervisor. This limits captured proof output, not all guest system
journals, emulator side logs or aggregate multi-replay evidence retention.
The new boot unit is installed and passed `systemd-analyze verify`; its
loopback-only condition correctly skips replay on the networked preparation
guest. It has not been cold-clone verified.

CLI tests passed intended red/green cases for invalid resource ceilings and
output overflow, exact-budget output and child-error propagation. The direct
fresh-scratch build passed all 69 tasks in 4m24s with live limits and canonical
checks. AAR hash matched; APK hash was
`cd3ab60c801a021caf4468663402f2fdc95a3c4362110aa3a4da9816a424effc`.
Its combined collector retained 8,689 bytes but the following fresh runtime
timed out at 300 seconds, despite the emulator reporting boot completion in
18,098 ms. A comparison without the collector failed differently: the emulator
segfaulted before ADB connected. No cause is established, and no retry or
limit weakening was added. Integrated runtime/collector acceptance is
incomplete; the earlier canonical cold-clone pass remains separate evidence.
The stage-instrumented runtime subsequently passed under the same collector
and unchanged limits in 19.159s, with live resource assertions and Android
instrumentation success (reported peak3.2G, zero swap). Runtime cleanup was
confirmed. The earlier failures remain unresolved; this pass is not evidence
of a root-cause fix or a new automatic retry policy.
An actual guest overflow test emitted 64 MiB plus one byte: the collector
failed explicitly and retained exactly 67,108,864 bytes. The synthetic output
file was removed. All current supervisors/runtime/unit files are covered by
the saved `replay-scripts.sha256` manifest. Per-replay collector behavior and
individual integrated units are verified, but full networkless boot-wrapper
execution and reliability acceptance remain open.
The owner authorized a new independent `cairn-proof-bounded` cold clone.
`create-offline-clone.sh bounded` preserves previous bases and evidence in a
new directory; preparation inputs/service readiness were verified before the
approved prep poweroff request. Host creation/start is pending.
`preserve-journal.sh bounded` additionally extracts `/var/lib/cairn-proof-logs`
read-only, validates the saved per-boot output checksum and 64MiB ceiling,
and requires build/runtime effective-resource and completion markers.
These new selector paths are syntax-checked, not yet execution-verified.
No disposal authorization is implied by creating this clone.
The owner supplied successful bounded-clone boot output:69 tasks executed in
4m28s, JVM/native packaging and canonical manifest checks passed. AAR hash
matched; APK hash was
`9f20309fcc9445073e762bee13c8261f904e9d74b12f0fa045299629d1dbec17`.
Fresh runtime passed effective resource assertions, startup stages and
instrumentation in18.675s (reported peak4.5G,zero swap), followed by the final
bootstrap PASS. Reported build peak1.7M is not accepted. The excerpt omits
the earlier build-resource assertion; retained bounded-log checksum/size and
both resource markers still require extraction. New-clone lifecycle checks
remain pending; the prior emulator failures remain unexplained.
Subsequent stopped-clone extraction passed: the saved replay checksum and
64MiB size check, both effective-resource markers, completion marker and all
canonical input markers are retained. Base/overlay hashes stayed unchanged.
The exported live XML was independently checked for sole overlay, independent
base-only DAC override, dynamic SELinux and no network/shares/passthrough/
channel. Base ownership/write-denial output for this clone has not been
supplied; it is not inferred from the hash. Bounded evidence is root-only at
`/var/lib/cairn-proof-evidence/bounded-replay-journal`. Disposal is pending
separate authorization.
The owner's subsequent bounded-base check failed: ownership was
`qemu:qemu 0640` and QEMU could open it for writing. Despite the exported
DAC-only override and unchanged hashes, durable Unix write denial is not
established for this new clone. The cause is unresolved. The earlier protected
clone's passing cycle does not generalize to all newly created clones;
bounded runner acceptance remains blocked. Keep the stopped overlay intact.
Controlled synthetic extraction reproduced `root:qemu 0640` becoming
`qemu:qemu 0640` under guestfish's default libvirt backend. The same synthetic
image retained `root:qemu 0640` with `LIBGUESTFS_BACKEND=direct`.
The extraction recipe now explicitly selects direct backend and compares
ownership/modes as well as bytes before/after both appliance operations.
This avoids the demonstrated extraction-side ownership change without global
libvirt/SELinux changes. Corrected full extraction is still pending, and the
bounded proof's live base permissions cannot be reconstructed from this test.
The owner then executed the corrected extraction on the stopped bounded
overlay. Starting base was `root:qemu 0640`; bounded log checksum/size,
resource/canonical/completion markers, image hashes and before/after
ownership/mode comparisons all passed. Separate evidence is retained at
`/var/lib/cairn-proof-evidence/bounded-replay-journal-direct`.
The extraction-side correction is verified end-to-end; it does not establish
live base permissions during the original bounded boot. Overlay remains
retained pending separate disposal authorization.
An owner-authorized resumed replay on the retained overlay passed all69tasks
in4m31s and fresh Android instrumentation in18.502s. AAR hash matched; APK was
`bbc1266053ca8728b0179f8f4d1c34002ebe468f96b3e1cf84e8f2e88a599dec`.
Owner then observed live base `root:qemu 0640` and QEMU write-open denial,
followed by shutoff with ownership unchanged. Direct extraction preserved both
boots' log checksums/64MiB bounds, effective-resource and canonical assertions,
completion markers, unchanged image bytes and unchanged ownership/modes.
Evidence is retained at
`/var/lib/cairn-proof-evidence/bounded-replay-journal-live-verified`.
This closes the observed live-protection/preservation gap for the resumed
run, not retroactively for the first bounded boot. Disposal still requires
approval; earlier intermittent emulator failures remain unresolved.

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
- Root-owned canonical inputs under
  `/opt/cairn-binding-seeds/final-image-inputs-e75437d/canonical-inputs`,
  prepared once with `sudo bash prepare-canonical-inputs.sh` from the verified
  preserved archives. Preparation rejects an existing destination, extracts
  source/registry/modules, creates a content checksum manifest and removes
  write permissions. Canonical content is not a writable Gradle cache.

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
The build now binds all Gradle build/settings/properties files, the Rust
crate tree and consumer source trees read-only. Cargo's entire registry
(source/archive/index) and Gradle's downloaded `files-2.1` artifacts are
read-only too. Bind sources are separate root-owned canonical inputs, not
the workspace's copied files. The unit verifies every mapped object resolves
to the canonical inode and its covering mount is read-only, checks canonical
namespace additions and representative existing-file writes are denied with
`EROFS` or `EACCES`, and requires project shells remain writable. The complete
canonical content manifest is checked before and after the build.
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
The pinned upstream
[`DefaultSettingsPreparer.validate`](https://github.com/gradle/gradle/blob/v9.7.0/subprojects/core/src/main/java/org/gradle/initialization/DefaultSettingsPreparer.java#L307-L333)
unconditionally rejects any project directory whose `File.canWrite()` is
false, after settings processing. Moving only `.gradle` or module outputs
does not remove that check. A fully read-only Gradle project directory is
therefore incompatible with this baseline; disabling validation or changing
the Gradle pin is not part of this proof.
An owner-selected separated-input investigation passed a bounded systemd
probe on the preparation guest. The archived fixture was restored root-owned
at `/opt/cairn-binding-seeds/source-namespace-probe`; writable project shells
were created separately at `/srv/cairn-source-namespace-probe`. Read-only
binds exposed the canonical root build file and Rust crate inside those shells.
The unprivileged probe verified the covering mounts were read-only, canonical
file writes were denied (`EACCES`), canonical additions/removals and Rust
source additions were denied (`EROFS`), and workspace project directories
remained writable. Mounted build/Rust/lockfile bytes matched canonical inputs.
An initial probe incorrectly required `EROFS` for every denial despite Unix
permissions producing `EACCES`; another incorrectly required an exact mount
entry rather than the read-only covering mount. Both assertions were corrected
before the recorded pass. This is filesystem feasibility evidence only:
that initial probe did not execute the complete Gradle fixture/cache mapping.
Writable project shells/cache metadata remain state, not canonical inputs.
The full mapping subsequently passed direct preparation-guest execution with
all 69 tasks executed in 4m17s, JVM assertions and native packaging checks.
The AAR hash matched; APK hash was
`11958baaad9a61fc26a60511c1a93ae23403095360e3005f99c3cb7baed14d95`.
All canonical input identities/read-only mount checks and pre/post content
manifest checks passed. Fresh Android instrumentation then passed in 19.436s
with reported 4.6G peak memory and zero swap. The reported 1.5M build peak is
not accepted. This new layout has not yet run in a newly cloned networkless VM.
The replay bootstrap now requires a saved `build-offline.sh` and generated
`replay-scripts.sha256` manifest in addition to canonical inputs. It restores
scratch from the original archives but installs the current trusted build
supervisor before invoking it. Writable workspace/cache metadata are not
claimed immutable; generated sources are build outputs, not canonical inputs.
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
An explicit `canonical` argument selects `cairn-proof-canonical` and
`/var/lib/libvirt/images/cairn-proof-canonical`, preserving the previous
offline proof's base/evidence. The same selector on `preserve-journal.sh` and
`dispose-overlay.sh` selects the canonical clone and
`/var/lib/cairn-proof-evidence/canonical-replay-journal`; deletion still
requires separate explicit owner approval. Unknown arguments are rejected.
The owner authorized this new clone and clean preparation-guest shutdown.
Persistent canonical inputs and current supervisor checksums were verified,
proof units were not active, and poweroff was requested. Host creation/start
is pending owner sudo; no new cold-image pass is claimed.
The owner subsequently supplied the new canonical clone's successful replay:
all 69 tasks executed in 4m25s, JVM assertions/native packaging passed, and
the canonical manifest remained unchanged after the build. The AAR hash
matched prior evidence; APK SHA-256 was
`f473420b64a2a99896555f432508baff6549a0fcee3a57e2dcfb58aecd2ba76b`.
Fresh Android instrumentation returned code `-1` and its completion marker,
followed by the final cold-build/runtime PASS. Runtime was 20.032s with
reported peak4.5G and zero swap; build peak1.8M is not accepted.
The supplied excerpt starts after the mount-identity probes; their output
has not yet been recovered from this clone's journal. New-clone live topology,
base write denial, post-stop checks, journal preservation and disposal remain
pending. This extends cold-image behavior evidence without claiming full
namespace or final runner acceptance.
Subsequent owner live checks confirm the canonical clone's sole disk is its
`run.qcow2`, interface list is empty, base remains `root:qemu 0640`, and
QEMU-account write-open is denied. Full backing/share topology and post-stop
state/hash/journal/disposal remain pending.
The owner then confirmed the canonical clone shut off with base still
`root:qemu 0640`, and read-only journal extraction passed with unchanged
base/overlay hashes. Evidence is root-only under
`/var/lib/cairn-proof-evidence/canonical-replay-journal`.
The exported live XML was independently checked over authorized SSH: sole
independent backing base, base-only DAC override, dynamic SELinux, and no
network/shared filesystem/hostdev/channel. Early mount-identity log confirmation
and separately authorized canonical-overlay disposal remain pending.
Searching the exported unit log returned only the post-build manifest marker,
not the two early input-probe markers. Their absence is unresolved; raw-journal
search and logging diagnostics are required before treating them as retained
cold-clone evidence.
The owner subsequently found both early markers in the preserved raw journal
at boot time 8.004821s. The unit-only export omitted these entries, so the
canonical extraction recipe now exports exact input-probe markers across
the journal and requires all three. No logging loss is established.
Together with the post-build manifest marker, retained cold-clone evidence
confirms read-only canonical input mapping and unchanged content. This does
not make writable workspace shells or cache coordination metadata immutable.
The owner then explicitly authorized and executed canonical disposal.
The boot log and both image hashes checked OK, all three input markers were
exported/verified, and the final runtime marker was present. Only
`cairn-proof-canonical` was undefined and its overlay removed; domain/overlay
absence checks and retained-base checksum passed. Canonical base and journal,
including `input-probes.txt` and its checksum, remain retained. This completes
the new canonical clone's observed lifecycle without closing the remaining
workspace/cache-state or Apple acceptance questions.

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

### Preserving the stopped clone's journal

`preserve-journal.sh` requires the clone to be shut off and a new root-only
evidence directory. It uses installed `guestfish` with explicit qcow2 format
and `--ro` to copy `/var/log/journal` through a libguestfs appliance, without
host-mounting guest filesystems or enabling appliance networking. It exports
only the boot-proof unit's entries to `boot-proof.txt`, requires a completion
marker, and compares both image hashes before/after extraction.

The owner executed it successfully with guestfish 1.60.1 on Fedora. Both
cold-replay completion markers were present, and base/overlay hash checks
passed. Evidence is retained root-only under
`/var/lib/cairn-proof-evidence/protected-replay-journal`, including the raw
journal, filtered proof log and checksum manifests. The journal hostname
remains the preparation image's `cairn-prep`; it is not a claim that the
networked preparation domain ran these boots. The extraction checks the
stopped `cairn-proof-offline` domain's fixed overlay path. The owner explicitly authorized targeted disposal and executed
`dispose-overlay.sh`. It verified the preserved proof log and both image
hashes, saved inactive domain XML with the evidence, undefined only
`cairn-proof-offline`, and removed only `run.qcow2`. Domain absence and overlay
absence checks passed, followed by a passing retained-base checksum.
The independent base, original preparation guest and root-only journal remain
retained. This completes the observed disposable-overlay lifecycle, not full
source/cache namespace immutability or final cross-platform runner acceptance.

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
