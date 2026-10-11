# Apple isolation probes

Internal benign probes for [issue 45](../../../.scratch/cairn-r1/issues/45-provision-isolated-build-runner.md),
not a binding build or accepted Apple runner. See
[ADR 0014](../../../docs/adr/0014-hosted-apple-isolation-probes.md).

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

| Module | Target | Owning proof task | Evidence/limitation |
| --- | --- | --- | --- |
| `sdk` | Darwin JVM | `buildBindings` | Generated bindings; generator debug profile only |
| `consumer` | Darwin JVM, JDK `21.0.12.1+1` | `interopSmoke` | Actual values/errors/string/close; not iOS runtime |
| `sdk` | iOS device ARM64 | `compileKotlinIosArm64`, `linkDebugFrameworkIosArm64` | Generated compile/link and deployment `15.0`; no physical device |
| `sdk` | iOS simulator ARM64 | `compileKotlinIosSimulatorArm64`, `linkDebugFrameworkIosSimulatorArm64` | Generated compile/link and deployment `15.0`; no simulator calls |
| `sdk` | Shared Native metadata | `compileNativeMainKotlinMetadata` | Commonization/compile; not runtime |
