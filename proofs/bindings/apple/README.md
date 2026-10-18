# Apple isolation probes

Hosted binding-build probes and a separately approved functional simulator lane
for [issue 45](../../../.scratch/cairn-r1/issues/45-provision-isolated-build-runner.md),
not an accepted strict Apple runtime runner. See
[ADR 0014](../../../docs/adr/0014-hosted-apple-isolation-probes.md).

## Current owning lanes

`apple-toolchain-preparation.yml` retains the dedicated-UID, frozen-input,
offline build cell and its existing resource/network controls. It no longer
boots CoreSimulator under the disabled-login account. Its final owning task
is `:sdk:linkDebugExecutableIosSimulatorArm64`, using the same canonical
`consumer/src/jvmMain/kotlin/Smoke.kt` as the JVM proof through an Apple-only
source mapping. The executable must have simulator ARM64 architecture and
Mach-O minimum OS `15.0`; root exports verified bytes before scratch detach.
Only successful build, cleanup and immutable-input checks permit upload.

The dependent `functional-runtime` job receives that same-run executable,
its SHA-256 manifest and exact source revision on a fresh `macos-26` VM.
It rejects extra files, symlinks, malformed manifests, oversized or changed
binaries and revision mismatches before execution. It uses the normal runner
user's CoreSimulator services and a new private device set, creates one
`iPhone-17` with iOS `26.4.1`, boots ARM64 and executes the canonical Kotlin
consumer through `simctl spawn --standalone`. Success requires its arithmetic/boundary,
typed-error, string and deterministic object-lifetime assertions, followed
by exact recorded-device shutdown/deletion. The job has a ten-minute ceiling,
a 480-second/64 MiB execution collector, 300-second bootstatus ceiling,
60-second generated-call ceiling and a separate 75-second cleanup collector.

This runtime lane is **functional-only**: simulator helper process/disk/network
limits and access outside the private set are not strictly contained. No
project secrets or signing are supplied, but this is not a credential-free
host boundary. Strict issue-45 acceptance, intermittent scratch-eject
reliability, physical iPhone execution and production PQC/BLE remain open.
Hosted functional execution passed in
[run 38228998011, attempt 2](https://github.com/trancee/cairn/actions/runs/38228998011/attempts/2)
at `19c35ba000a17f734ce04b1685d28d0c40d64e74`. The initial attempt passed
preflight, strict offline build, immutable-input checks, scratch teardown and
payload delivery, but timed out during 30-second simulator creation and
15-second cleanup inventory. Only the failed runtime job was replayed on a
fresh VM, using the same delivered payload and unchanged limits; no automatic
retry or timeout increase was added. ARM64 boot, both canonical smoke `PASS`
markers, successful delivered-consumer exit and exact-device shutdown/deletion
passed. Downloaded payload SHA-256 verification passed:
`1c1f429e9c7bb47814070f871ff24e6a896dfdeac7ff9a84c8a175cce8cdb229`.
Its recorded revision matches the run and Mach-O inspection reports
`IOSSIMULATOR`, ARM64 and minimum OS `15.0`. The creation-timeout cause and
deterministic first-attempt reliability remain unproven; this is real generated
simulator execution, not strict runtime containment or hardware evidence.

## Scratch teardown

The hosted resource fixture's exit trap uses `detach-scratch.py` for ordinary
verbose ejection of its owned `/private/tmp/cairn-resource-<suffix>/scratch`
volume and the current owned `scratch.dmg` or `build-scratch.dmg` image passed
by the caller. Noncanonical or mismatched paths fail before any native command.
Successful ejection returns zero without querying optional disk state or open-file holders.
Prior workload/account-cleanup failures remain failures in the caller.

Failed or unavailable ejection returns nonzero. Only then collect the five
device/mount/ejectability fields with `diskutil info -plist` and identify the
exact owned image through `hdiutil info -plist`. Both metadata commands share
one five-second monotonic deadline. Filter the inventory before logging:
only validated devices belonging to that image and its reported assigned
mount points are emitted, never unrelated image records. Missing or ambiguous
inventory is explicit; missing mount records are not proof of successful unmount.

Filesystem holders (`lsof -Fpc +f --`) and exact image/device holders
(`lsof -Fpc --`) share one 15-second deadline. Only validated PID/command
fields are emitted. Native `lsof -Fpc` also produces mandatory `f` descriptor
records; validate their nonempty printable values but do not log them.
Empty/control-bearing descriptors, malformed PID/command records and
unselected field types still reject with `invalid-holder-fields`, without
logging their values. Partial valid results remain visible when a query
returns nonzero, with an explicit diagnostic error.
Unavailable, malformed or timed-out diagnostics remain explicitly observable
and cannot turn failed ejection into success. If unmount already succeeded,
the mount-path query may be unavailable; no whole-disk state is inferred.
No retry, forced detach, unrelated process termination or limit/permission
change is included. This fixes a success-path diagnostic dependency, not
intermittent busy-eject reliability or strict runtime acceptance.

The existing benign-preflight test discovery includes the OS-boundary
regressions. The focused command is:

```sh
xcrun python3 -B -m unittest discover -s proofs/bindings/apple \
  -p 'test_scratch*.py'
```

These simulations establish failure propagation and diagnostic behavior,
not native disk-ejection reliability. The macOS-only holder regression also
reads actual `lsof` records for one temporary file owned by the current test
process, then exercises failed-ejection diagnostics through the OS boundary.
It requires PID/command retention and descriptor omission; it neither mounts
nor ejects a native disk. See
[the decision and observed regression](../../../docs/adr/0014-hosted-apple-isolation-probes.md#failure-only-scratch-detach-diagnostics).

## Frozen-input manifest generation

The four `freeze-*.sh` entry points create their existing SHA-256 manifests
with `tool-input-manifest.py` after unchanged root ownership/read-only setup.
Its CLI accepts an input root and an optional normalized relative directory
scope (default `.`). It emits byte-sorted regular-file records in the existing
`shasum` format, including escaped backslash/newline names and unchanged
root/scoped prefixes. Symbolic links and special files are not hashed.
Root/scope symlinks, path escapes, empty regular-file inventories and read
failures return nonzero with a redacted reason and no manifest on stdout.
File contents are read in 1 MiB chunks; the manifest is emitted after every
selected file has been hashed successfully.

The workflow's independent `shasum -a 256 --check` gates remain unchanged for
tools, Gradle, Cargo and Native inputs after the bounded cell.
`verify-frozen-inputs.py --root ROOT --jobs N --check MANIFEST LOG ...` runs
those same checks over contiguous manifest chunks in parallel and writes each
log byte-identical to a serial check; any failed chunk fails the step after
every log is written. No check,
fresh compilation, archive verification, resource limit or copy/permission
operation is removed. Nothing is cached by this change.

`benchmark-tool-manifest.py INPUT_ROOT [--repetitions N]` compares the actual
CLI with the manifest pipeline from committed baseline `a6b0767`. The default
is three alternating-order comparisons; fewer than three are rejected.
Every manifest must match byte-for-byte and remain unchanged across samples.
JSON records source hashes, platform/Python/OpenSSL/CPU metadata, workload
file/byte counts, manifest hash and all timings. A median candidate/baseline
ratio above `0.9` fails; this is a local component benchmark, not a noisy
shared-runner latency gate.

From the repository root, on macOS with an installed Rust toolchain:

```bash
rustc --version
xcrun python3 -I proofs/bindings/apple/benchmark-tool-manifest.py \
  "$(rustc --print sysroot)"
```

Local measurement on 2026-10-13 used Rust `1.99.0`, 451 files,
1,206,736,728 bytes, eight-core ARM64 macOS `27.0.1`, Xcode Python `3.9.6`
and LibreSSL `2.8.3`. The median fell from `3.79s` to `0.68s` (about 82%);
all manifests matched. The performance test first failed at ratio `1.03`.
This is not a measurement of the full pinned Apple preparation tree, the
GitHub `macos-26` runner or end-to-end CodeQL latency. Those require hosted
comparison. The full-tree hosted result below supersedes that local-only
limitation. See [ADR 0014](../../../docs/adr/0014-hosted-apple-isolation-probes.md#manifest-generation-optimization).

Initial hosted validation at `d17aded` does not establish a speedup:
the whole freeze step took `162s` in PR run `38450721754` and `242s` in
branch run `38450715255`, against the earlier `139s` baseline. Every one
of the baseline's 80,635 paths remains in both tool manifests; five digest
differences are confined to Rust component metadata and Ubique Git metadata.
Both strict cells failed before actual Kotlin extraction/post-cell integrity
acceptance: the PR supervisor rejected unexpected dedicated-UID processes
before Native cinterop; the branch exhausted the unchanged 60-second
tool/startup/selection command ceiling. Causes remain unestablished.

The same-VM full-tree comparison in
[run 38460658960](https://github.com/trancee/cairn/actions/runs/38460658960)
at `a8fff9e` passes with identical manifests for 80,635 files and
5,860,115,366 bytes. Environment: the supplied three-CPU ARM64 `macos-26`
VM, macOS `26.6.2`, Xcode Python `3.9.6`, LibreSSL `2.8.3`.
Baseline generation samples were `76.27s`, `59.31s`, `78.51s`; candidate
samples were `50.15s`, `38.27s`, `46.17s`. Median generation changed from
`76.27s` to `46.17s`, about 39.5% lower, with the unchanged `0.9` threshold.
The manifest SHA-256 is
`5f5759844b54cc702180eed95cd29167098004ba7514e39cad9d5af65cb99b6a`.
The public benchmark baseline commit must be present locally; the temporary
hosted probe fetched only that exact object into the shallow checkout.

Tagged phase measurement on that VM recorded copying `77s`, ownership/
permissions `19s`, and initial generation `39s`. Other observed runs varied
substantially. The six-command comparison itself took about six minutes;
the subsequent full diagnostic exceeded the unchanged 30-minute job ceiling.
It therefore proves the measured component only, not a complete diagnostic
build or end-to-end CodeQL speedup. Independent ordinary PR/push runs
`38460667964`/`38460659594` at the same revision pass all strict extraction,
coverage/query, immutable-input, cleanup and upload gates; Rust/formal gates
also pass. Earlier intermittent failures are not shown to be fixed.

Temporary timing and manual workflow instrumentation have been removed.
The retained local benchmark is opt-in and never adds profiling overhead
to normal CI. Its existing 120-second per-command ceiling is unchanged.
The supervisor's existing-UID rejection now reports only owned PID/parent,
state, CPU time and command basename before refusing; it neither launches
nor cleans those pre-existing processes. No retry or boundary/budget change
is introduced. The unexpected-process failure did not reproduce in subsequent
runs, so its identity and root cause remain unestablished.

### Final-head diagnostic follow-up

Cleanup head `db68586` passes Rust/formal gates and the final
Actions/Python/Rust scans, but not Kotlin acceptance. PR run `38465374925`
first fails ordinary scratch detach; its unchanged failed-job replay fails
the existing one-shot process-snapshot test. Push run `38465367937` passes
tool/selection probes but expires the separate 60-second offline Apple
target/dependency-metadata invocation. No root cause or reliability fix is
established for those failures.

`check-fixture-targets.sh` now streams both Gradle output channels through
`tee` to the existing bounded collector while retaining its scratch log.
Partial diagnostics survive command expiry; `pipefail` preserves Gradle's
failure status. The 60-second command, 64 MiB collector, 128 MiB child-file
and 8 GiB scratch ceilings remain unchanged. The real-script/collector
regression was red on missing partial output, then green after streaming:

```sh
xcrun python3 -B -m unittest discover -s proofs/bindings/apple \
  -p test_fixture_target_output.py
```

This controlled subprocess test proves output/exit propagation, not a timing
fix. Manual hosted probes `38514098575` pass all six supervisor cases and all
boundary/resource assertions; their eight retained artifact checksums verify.
PR run `38513991094` at diagnostic head `6ad4bb9` passes offline effective
targets/dependency metadata and later refuses a `distnoted` process under UID
59000, parent PID 1. Its origin/lifetime remains unestablished; it is neither
trusted nor pre-cleaned. The earlier missing-snapshot failure does not recur.
Formal run `38513991093` separately fails unchanged mutation-certificate replay
with Tamarin `<<loop>>`, not a reported security counterexample.
Push run `38513985911` completes Kotlin extraction, coverage and security
queries, then fails ordinary scratch detach (`Resource busy`) before mandatory
post-cell input checks and result delivery. It is not accepted Kotlin CI.
Temporary tagged bootstrap/snapshot tracing is removed after collection.
Controlled child-log failure context remains, with unchanged assertions and
timers. The cleanup-head results below supersede that earlier acceptance gap.

At cleanup head `8b4c2d6`, PR CodeQL `38515603675`, Rust `38515603697`
and formal `38515603660` pass; all four PR scans process without errors at
`47a9c5207514ea28f5ab7393233148ced60dc5b5`. Duplicate push `38515598161`
fails both attempts. These results do not establish deterministic reliability.

## Generator reuse evaluation

The experiment at
[`75c5623`](https://github.com/trancee/cairn/commit/75c56232fd6c3d65d00e88c4f0e9709325b9c287)
shared the owning bindgen Cargo directory and selected an explicit Darwin
host target. Three complete paired comparisons replayed committed baseline
`8b4c2d6`, using both orders and matching source/lock/environment hashes.
Both generators compiled freshly as ARM64; independent post-cell input checks
passed in all three accepted runs. Normal CI had no measurement workload.

| Accepted run (attempt 2) | Order | Baseline | Candidate | Ratio |
| --- | --- | --- | --- | --- |
| `38525913102` | baseline first | `255.42s` | `271.24s` | `1.06195` |
| `38529286247` | candidate first | `153.29s` | `166.98s` | `1.08933` |
| `38529289684` | baseline first | `260.23s` | `240.64s` | `0.92474` |

Median paired ratio `1.06195` is about **6.2% slower**, not a speedup.
36 reused Cargo artifact records and fewer compiled records (103 to 72)
did not establish faster elapsed time. The ordinary Native/framework/
executable and delivered functional simulator assertions passed in the third
run; PR CodeQL/Rust/formal and four processed scans passed at `75c5623`.
First attempts failed pre-existing UID-helper refusal or a five-second disk
query; one explicit unchanged failed-job replay each passed. No reliability
fix, automatic retry or limit/permission increase is implied.

The experiment is not adopted. Its compiler/task configuration, benchmark/
test files and dispatch selector are removed; all owning files match
`8b4c2d6` again. The committed
[benchmark source](https://github.com/trancee/cairn/blob/75c56232fd6c3d65d00e88c4f0e9709325b9c287/proofs/bindings/apple/benchmark-bindgen-reuse.py)
retains the reproducible three-report comparison. Evidence and current
final-head acceptance are recorded in [PR #8](https://github.com/trancee/cairn/pull/8).
The independently approved duplicate-scheduling fix remains.

## Earlier probe evidence

### Opt-in Kotlin CodeQL diagnostic

Dispatch `apple-toolchain-preparation.yml` with `codeql=true` to test direct
manual tracing inside the same strict build cell. CodeQL `2.27.2` and the
Android API `37.0` platform JAR are checksum-verified and frozen tool inputs.
The analysis-only init script includes Android consumer Kotlin in the JVM
compilation against that compile-only API; ordinary builds remain unchanged.
Only CodeQL commands add the owner-approved read of the literal `/opt` parent
directory for importer canonicalization; unrelated child contents and input
writes stay denied. Real native sandbox parent-read red/green and negative
child-read/input-write/ordinary-profile tests pass locally.
Initialization, actual compilation/tracing and finalization share the existing
300-second JVM command ceiling and bounded scratch. Export requires successful
finalization. Hosted run `38263225443` at `799d758` passes actual Kotlin
database finalization; downloaded metadata and source archive agree.
The mandatory analysis gate queries compiled Kotlin compilation units,
requires every tracked `.kt` source plus generated binding evidence, and runs
the unchanged bundled Java/Kotlin security suite offline. Analysis has its
own existing 300-second command ceiling, two threads and 2 GiB requested
evaluator RAM; all caches/results remain in bounded scratch. Coverage and
SARIF export require success. Compiled coverage and suite execution pass in
run `38268914707`; mapped export passes in run `38274027100`, attempt 2.
Processed GitHub results remain unverified. This is not yet a deployed
replacement scan or Android packaging
proof; default Actions/Python/Rust scanning stays enabled. See
[ADR 0015](../../../docs/adr/0015-build-backed-kotlin-codeql.md).

`.github/workflows/codeql.yml` runs existing Actions/Python/Rust default
suites; `.github/workflows/codeql-kotlin.yml` calls this strict Kotlin lane.
PRs run it only when strict-lane inputs change; `main` pushes, weekly and manual
runs are unfiltered. `test_codeql_kotlin_triggers.py` fails if a referenced
repository path escapes that filter. A manual `upload=false`
dispatch validates without publishing scans while default setup stays enabled.
Feature branches without a PR use manual dispatch; main pushes, PRs targeting
main and weekly runs remain automatic. Feature pushes no longer duplicate a
PR's full strict-cell build. Only superseded PR runs are cancelled; main,
weekly and manual runs are preserved. Automatic uploads require the separately
approved setting cutover. Only mapped `java-kotlin.sarif` is uploaded; raw SARIF and compiled
source inventory remain diagnostic artifacts. Generated paths retain their
owning untracked build location, not a fabricated handwritten annotation.
CodeQL mode skips the unrelated functional simulator runtime; ordinary
binding-proof dispatch still requires it. No deployment/cutover success is
claimed until processed replacement results are observed.

Run `38268914707` passes the three existing language analyses and actual
Kotlin compilation-unit coverage (three tracked files and both generated
common/JVM files), then executes the bundled suite. Mapping fails on an
implicit URI base before successful export. The mapper now handles CodeQL's
standard undeclared `%SRCROOT%` using the known frozen database source root;
other unknown bases remain errors. Failed reports are retained separately
with a failed status. The built-in `3 out of 9` diagnostic is not substituted
for the explicit compiled-source gate.
CodeQL mode also omits native-only framework/executable tasks and simulator
payload export after its JVM/analysis gates; ordinary mode retains them.
No resource, filesystem, network, integrity or cleanup boundary is relaxed.

The complete upload-free replacement passes in
[run 38274027100, attempt 2](https://github.com/trancee/cairn/actions/runs/38274027100/attempts/2)
at `6618ecb`: existing-language analyses, Kotlin compilation-unit coverage,
bundled queries, mapped export, frozen-input integrity and cleanup.
Downloaded Kotlin SARIF records a successful CodeQL `2.27.2` invocation,
76 rule metadata entries and zero results. Actual raw-to-mapped replay and
the tracked-source guard agree. Attempt 1 fails preflight scratch-device lookup
(`diskutil info -plist`, five-second deadline) before target work; only
failed/skipped jobs are replayed with the same
revision and unchanged limits. Scratch-eject reliability remains open.
The owner subsequently approved PR #6 merge and coordinated scanning cutover.
Default setup is disabled; PR run `38279234281` passed and GitHub processed
all four language analyses. Concurrent branch run `38279051559` completed
Kotlin analysis but failed scratch teardown; only failed jobs are replayed
with unchanged controls. Deployment and processed scans on `main` remain pending.

On macOS with Xcode Python available:

```bash
bash proofs/bindings/apple/run-probes.sh /absolute/unused/probe-output
```

The output directory must not exist. Logs, environment observations and SHA-256
checksums remain there after success or failure. The workload checks input
write denial, a designated host sentinel read, network bind/outbound TCP,
Unix-socket IPC, scratch symlink escape denial, child inheritance,
writable scratch and a 1 MiB per-file ceiling. TCP/Unix fixtures first
connect outside the sandbox; the supervisor owns/closes them.
Use a short output path so the Unix socket pathname remains below 104 bytes.

The unprotected CLI went red on allowed input mutation. The protected local
CLI passed. An initial narrow read profile aborted process startup; the current
profile permits system reads and denies other `/Users` data plus the sentinel.
This does not prove a complete filesystem/network boundary, total disk,
memory/CPU/process limits or Xcode/Kotlin compatibility.

`.github/workflows/apple-isolation-probe.yml` runs only these probes on the free
standard `macos-26` runner, with the approved 30-minute job timeout and seven-day artifacts.
No secrets, signing, dependencies or target-controlled build are involved.
Hosted results must be observed before claiming any hosted probe passed.

The initial process-memory probe failed while setting the limit. The owner
selected a whole-VM boundary instead: `probe-memory.py` checks observed RAM
against a candidate 7 GiB ceiling and requires zero configured swap.
Any mismatch fails with checksummed `memory.log`; this is not a process cap.
Wider dedicated-user/
disk/process probes run separately even when memory fails; no target build
is authorized.

`run-resource-probes.sh` requires root and `GITHUB_ACTIONS=true`; it creates
a disabled-login UID only in the disposable hosted VM, enables ownership on
a fixed 256 MiB scratch image and runs real capacity/process/CPU exhaustion.
The user/volume are removed/detached afterwards; diagnostics remain retained.
These are benign test thresholds, not build budgets or memory acceptance.
A tool root must be followed by a scope argument (`full`, `codeql` or
`isolation`) selects the probes that `cell-plan.py` lists for that cell.
The `codeql` scope skips the boundary probes (resource exhaustion, PF and
launch); the `isolation` cell runs them. Before any cell, the strict
preparation job runs `await-preflight.py` and
requires the same run's benign preflight to have succeeded.

The shared Linux collector now supports optional `--seconds` deadlines.
`python3 -B -m unittest discover -s proofs/bindings/apple -p 'test_*.py'`
checks partial output retention, closed-output waiting and invalid deadlines.
The hosted sandbox command uses a 30-second deadline and 64 MiB output cap;
the collector log is included in the checksummed artifact. Whole-VM memory
requires 7 GiB RAM and disabled/unloaded dynamic pager with zero swap.
The bounded supervisor now composes these controls for benign probes, not an
accepted binding build.

The separately authorized `apple-toolchain-preparation.yml` requires benign
preflight before downloading the existing Rust/Gradle/JDK/Ubique pins and
locked Cargo inputs on a fresh hosted VM. It does not compile the fixture.
Fixture/dependency caches are not yet frozen or replayed offline. The selected
Kotlin/Gradle/Ubique versions are unchanged; Xcode 26.6 is a separately
recorded hosted environment. Further compiler/Maven/Native preparation and
binding-build acceptance remain pending.
Trusted preparation
[run 38090961772](https://github.com/trancee/cairn/actions/runs/38090961772)
passed with the exact daemon JDK `25.0.4.1+1` after correcting an erroneous
version selector. Its artifacts contain versions, logs and input hashes,
not a reusable frozen cache.

`uid-supervisor.py` is a hosted-root-only CLI seam for the fresh
`cairnbenignprobe` account. It rejects existing UID processes and non-private
proof-output directories, applies approved CPU/process/file/core limits,
drops supplementary groups and executes with an explicit environment.
Completion, deadline and catchable interruption perform PID-specific UID
cleanup. It does not itself apply the sandbox or provision build scratch.
Hosted [run 38093375336](https://github.com/trancee/cairn/actions/runs/38093375336)
passed actual child-limit/access-group assertions and detached-descendant
deadline cleanup; all eight retained log checksums passed.

The hosted resource script next provisions an exactly 8 GiB root-owned image,
fully backs every logical byte and verifies private HFS+ scratch. Its usable
capacity is `8,245,960,704` bytes after filesystem/partition overhead. It runs
the existing sandbox probes through the dedicated supervisor and rechecks
backing/capacity afterwards. `build.sb` uses named data-read roots, unlike the
initial broad-read `probe.sb`; global metadata and root-directory enumeration
are allowed, but unrelated host file data is denied.

Trusted tool preparation
[run 38095349642](https://github.com/trancee/cairn/actions/runs/38095349642)
passed pinned Rust/Cargo, both JDKs and Gradle version startup in that cell,
then verified all frozen tool-file hashes unchanged. Tool copies are read-only
under `/opt/cairn-apple-tools`; this does not freeze fixture/Maven/Native caches.
The next compatibility probe runs `help` on a script-owned empty Groovy Gradle
project, still offline. No Ubique/Kotlin plugin or fixture is compiled.
That probe
[failed](https://github.com/trancee/cairn/actions/runs/38095639900) on the
required wildcard UDP lock-service bind. The preparation workflow remains
failed at that IPC gate until the separately owner-approved PF experiment.

Trusted empty Gradle `help` now passes in
[run 38124841659](https://github.com/trancee/cairn/actions/runs/38124841659).
The compiler socket profile is usable only within `run-pf-probes.sh`:
its fresh named anchor/private `127.0.0.2` alias supplies the precise UID/
address restriction and is removed afterwards without replacing main rules.
Live same-UID TCP/UDP roundtrip, external TCP and cross-UID TCP denial in
both directions pass inside/outside the sandbox. External/cross-UID UDP
negative coverage, frozen fixture/Maven/Native caches and binding builds
remain open. Do not run this root/PF setup on a shared local Mac.
The live UDP negative controls subsequently exposed and fixed a reverse
cross-UID state-creation gap. Corrected
[run 38125239632](https://github.com/trancee/cairn/actions/runs/38125239632)
passes same-UID roundtrip, cross-UID TCP/UDP in both directions and non-loopback
delivery denial with live positive controls. Empty Gradle initialization and
tool integrity still pass. Frozen fixture/Maven/Native inputs and actual
binding compile/runtime proof remain incomplete.

The owner-approved shared fixture selection uses
`-PcairnProofPlatform=apple` on macOS; default `linux-android` keeps the existing
Linux SDK/consumer/Android consumer configuration. Unknown values fail in
settings before project plugins. Apple selects `sdk/apple.gradle.kts` with
JVM/iOS device/simulator ARM64, the same Rust source/lock and root version
owners. Its Cargo outputs require assigned `CARGO_TARGET_DIR`; JDK 21 paths
must be supplied by the hosted supervisor rather than the Linux-only default.
Settings selection passed in
[run 38127148746](https://github.com/trancee/cairn/actions/runs/38127148746)
at `5016e70` using actual settings and empty scripts at canonical build
filenames, without loading fixture plugins. The selection is not yet an
accepted binding-build command: Maven/Native dependency preparation and
effective target checks remain pending. An earlier ordinary scratch detach
failed with `Resource busy`; later cleanup passed, but its cause remains
unverified. Failed detach retains PID/command-only holder diagnostics and
still fails the job without retry or force.

The settings-only selection probe streams each Gradle invocation to its
scratch log and the bounded collector. Real-script/collector regressions
cover partial default-selection progress at deadline and child exit-status
propagation. This closes diagnostic loss, not the startup deadline itself:
the invalid/default/explicit-platform assertions, 60-second aggregate
tool-cell limit and all isolation controls are unchanged. Current-source
hosted selection and compiled CodeQL acceptance must still pass.

Pinned plugin preparation and offline effective target configuration passed in
[run 38130344648](https://github.com/trancee/cairn/actions/runs/38130344648)
at `2472082`. Networked preparation runs only `help` with sanitized environment
and no Cargo compilation output; the copied Gradle `modules-2` seed is
root-owned/read-only, consumed through `GRADLE_RO_DEP_CACHE`, and hash-checked
after replay. Generated transforms/coordination metadata stay in scratch.
The approved child per-file ceiling is now 128 MiB, independently tested at
the boundary and next byte; output remains capped at 64 MiB. The instrumented
Kotlin plugin measures 67,326,033 bytes. Pager disable/zero-swap verification
precedes tool provisioning. Native/Cargo cache completeness, allocator audit,
binding generation, simulator runtime and physical-device proof remain open.

Further preparation now seeds external configuration artifacts and uses
`transformNativeMainCInteropDependenciesMetadata` for the synthetic commonizer
path, rather than directly resolving an unpublished Maven variant. Locked
Cargo inputs are vendored from fixture/bindgen/runtime manifests, frozen
read-only and tested by metadata for all three Apple Rust targets with blanket
socket denial. The official Kotlin/Native `2.4.20` ARM64 distribution is
checksum-verified and frozen with the tools.
[Run 38133904604](https://github.com/trancee/cairn/actions/runs/38133904604)
at `adc22c5` passed these inputs, tool startup and isolated script-owned
arithmetic KLIB compilation for device/simulator ARM64, with unchanged hashes.
SDK cinterop/linker access, allocator audit, fixture compilation and generated
runtime calls remain unverified. KLIB output alone is not ABI/runtime evidence.

Trusted C-header cinterop passes offline for device/simulator ARM64 in
[run 38136851477](https://github.com/trancee/cairn/actions/runs/38136851477)
at `74673d1`. Extracted LLVM/libffi inputs are root-owned/read-only and
hash-verified after replay; Native airplane mode and blanket socket denial
remain active. SDK lookup reads only the exact existing Xcode preferences
file, without accepting/modifying licenses or opening Mach services.
The next trusted CLI probe links arithmetic frameworks and checks their
actual Mach-O platform and deployment floor `15.0`. Fixture bindings,
allocator audit and generated runtime calls remain gated.

Trusted arithmetic framework linkage and actual device/simulator Mach-O
deployment-floor `15.0` checks pass offline in
[run 38137529578](https://github.com/trancee/cairn/actions/runs/38137529578)
at `f7f4eca`, with unchanged hashes and cleanup. The source-closure/runtime
archive diagnostic that follows does not itself accept allocator compatibility:
candidate classification and delivered allocator-thunk inspection must pass
before fixture FFI.

[Apple allocator evidence](ALLOCATOR-AUDIT.md) records package-scoped sources
and actual allocator forwarding in delivered ARM64 runtimes.
Shared-fixture Rust compilation passes Darwin/device/simulator ARM64
(`38143726072`), followed by fixture default-allocator/generated-Rust scans
(`38144367463`, `38145166981`). No generated FFI calls have run.
Pinned generator compilation expires the 60-second command ceiling even
with fingerprinted Cargo scratch reuse. This blocks binding generation;
changing the build ceiling or introducing an immutable generator seed
requires an explicit owner decision. Other budgets and network denial remain
unchanged. Earlier busy-detach failures and full runner acceptance remain open.

The owner approved 300-second actual build/generation cells. Diagnostic
debug bindgen compilation then passed offline in 3m09s (`38146169370`);
the plugin's actual optimized `installBindgen` expired its 300-second ceiling.
No bindings were generated. The debug diagnostic binary is not injected
into the plugin's source-fingerprinted installation.

The approved optimized-install ceiling is now 600 seconds only; other
build/generation cells retain 300 seconds and trusted probes 60 seconds.
Runs `38147417409`/`38149099333` still expired installation. The latter
passed bounded owned-process diagnostic regressions and observed runnable
`rustc` with 6m56s CPU at 540 seconds. Exact compile-JDK archive/hash/version
`21.0.12.1+1` also passed. UID cleanup passed; scratch detach again failed
`Resource busy`, without an identified holder. Bindings/runtime remain
incomplete; no optimizer weakening or further deadline increase is applied.

The owner subsequently approved debug profile for the generator only.
Its immutable Cargo adapter scopes that change to installation of the exact
pinned generator source; other Cargo calls/SDK profiles pass through unchanged.
Owning installation/fingerprints and binding generation pass (`38150603530`).
Actual immutable JVM smoke calls pass (`38151849548`), including values,
integer boundary, typed error, string transfer and deterministic close.
Generated device/simulator/common Native compilation passes (`38154100996`);
only commonizer generated output/locks are writable in the scratch Native
distribution shell, whose inputs point to the immutable seed.

Actual fixture framework linkage and Mach-O device/simulator deployment floor
`15.0` pass in
[run 38155697269](https://github.com/trancee/cairn/actions/runs/38155697269)
at `ef2302e`, with unchanged hashes and ordinary cleanup. These do not prove
simulator execution or physical-device behavior. A trusted runtime-inventory
probe now tests simctl access under blanket socket/Mach denial with a scratch
device set; it does not boot a device or execute generated calls.

That inventory failed in
[run 38157170214](https://github.com/trancee/cairn/actions/runs/38157170214)
at `f62938f`: CoreSimulator service connection and device-set subscription
were refused. Earlier JVM/Native/framework gates and ordinary cleanup passed;
final input-hash checks were not reached. The inventory now runs before
expensive fixture work and retains targeted `simctl` sandbox-denial diagnostics
without widening access. Simulator runtime and final acceptance remain open.
The narrowed replay `38158407544` explicitly identifies denied Mach lookup
of CoreSimulatorService and simdiskimaged; UID cleanup/ordinary detach passed.
No service allowance was added, and helper containment remains unverified.
The owner then approved exactly those two lookups for the trusted inventory
invocation only, using a separately composed profile. Helper identity and
sampled memory/CPU observations and scratch capacity are recorded; all other
services remain denied. No boot or generated-call allowance is included.
Run `38159023923` reached JSON inventory but found no available iOS runtime.
It observed root-owned simdiskimaged after caller-UID cleanup and additional
SimLaunchHost/Disk Arbitration/IOKit denials; necessity is not established.
Scratch capacity/ordinary detach passed. Structured inventory count and
availability diagnostics are now retained before the unchanged assertion.
After replay `38159746830` timed out before JSON, the owner approved exactly
the observed SimLaunchHost-arm64 lookup for a further trusted inventory-only
experiment. All other denials and the 60-second limit remain unchanged.
No boot/generated calls or helper-containment acceptance is implied.
The three-lookup inventory passed in
[38162040714](https://github.com/trancee/cairn/actions/runs/38162040714)
at `cd7f2ae`, returning 12 records including available iOS `26.2`, `26.4.1`
and `26.5`. Actual JVM/Native/framework gates, input hashes and ordinary
cleanup also passed. Root-owned simdiskimaged remained observable; inventory
success does not establish helper containment or simulator runtime.
Trusted device creation passed `38165989640`; boot probes `38167434234`/
`38168165135` expired 60 seconds without shutdown completion. Dedicated-UID
cleanup failed and scratch detach was busy. The diagnostic observed
launchd-parented simulator services and a remaining distnoted process.
Trusted lifecycle and runtime containment remain incomplete; no app ran.
Exact disposable-domain removal and empty-UID verification now pass
`38204550881`, `38215350684`, `38216685239` and `38220908711`.
Owner-approved trusted inventory and boot ceilings are separately 300 seconds.
The actual bootstrap-context regression passes `38220908711`, but boot still
stalls in LaunchServices migration. A 120-second snapshot contained 166 UID
processes: the 128-process caller limit is not inherited by launchd services.
Failed stack sampling was removed after bounded attempts. Root-helper and
full runtime resource/filesystem/network containment remain unproven.

| Module | Target | Owning proof task | Evidence/limitation |
| --- | --- | --- | --- |
| `sdk` | Darwin JVM | `buildBindings` | Generated bindings; generator debug profile only |
| `consumer` | Darwin JVM, JDK `21.0.12.1+1` | `interopSmoke` | Actual values/errors/string/close; not iOS runtime |
| `sdk` | iOS device ARM64 | `compileKotlinIosArm64`, `linkDebugFrameworkIosArm64` | Generated compile/link and deployment `15.0`; no physical device |
| `sdk` | iOS simulator ARM64 | `compileKotlinIosSimulatorArm64`, `linkDebugFrameworkIosSimulatorArm64` | Generated compile/link and deployment `15.0`; no simulator calls |
| `sdk` | Shared Native metadata | `compileNativeMainKotlinMetadata` | Commonization/compile; not runtime |
