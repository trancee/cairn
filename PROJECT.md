# PROJECT

state=protocol research/specification/formal models + host-only Rust foundation; SDK/application=not implemented.

## Standalone binding proof

The [Linux/Android fixture](proofs/bindings/linux-android/README.md) preserves
the exact owner-tested standalone Ubique source and Cargo lockfile. It is
separate from `core/`, exports only arithmetic/Greeter test APIs and does not
implement protocol or SDK behavior. Its README records the
`{module,target,host,prerequisites,task,proof,limitations}` matrix and the
interop-specific Rust 1.97.1/Kotlin 2.4.20/Gradle 9.7.0/AGP 9.3.1 tuple.
Owner-reported offline JVM calls and Android debug APK execution on an API 26
x86_64 emulator passed. Repository scripts from commit `8deda79` also passed
an owner-authorized SSH replay: 69 actionable tasks executed, followed by
Android instrumentation, with matching AAR/APK/transcript hashes. Retained
dependency/Cargo caches were used; this is not a fresh disposable image. No default CI
gate, accepted final sandbox, Compose, ARM64 hardware,
release/R8 or iOS binding proof is implied. The foundation-specific platform
claims below are unchanged.
The [bounded allocator evidence](proofs/bindings/linux-android/ALLOCATOR-AUDIT.md)
covers the fixture and delivered Linux/Android runtime ELFs, not Apple or
future dependency graphs.
The standalone build script now self-checks read-only actual source,
configuration and downloaded dependency mounts; its forced 69-task build
passed with unchanged artifacts. Writable Gradle project shells/metadata and
retained outputs remain explicit limitations, not final runner acceptance.
Android instrumentation also passes in a private runtime network namespace
with explicit route-denial assertions and verified emulator cleanup. A
disposable 16 GiB loop-backed runtime volume bounds fresh AVD/artifact/temp writes;
over-capacity allocation fails with `ENOSPC`, and cleanup is verified.
The unbooted root-owned AVD seed passes checksum checks before/after runtime;
the smoke package is absent before installation. Owner-supplied console output
also records a cold networkless clone replay: all 69 build tasks executed,
JVM assertions and fresh Android instrumentation passed, and the AAR hash
matched. The APK hash differed from the historical artifact; byte-identical
APK reproduction is not established. Owner-supplied host checks verify unchanged
base bytes and a sole overlay disk backed by the independent base, with no
NIC/shares/passthrough/guest-agent channel in live XML. A base-specific DAC
override passed live QEMU-account write denial and start/stop ownership/hash
checks. Read-only journal extraction and explicitly authorized proof-domain/
overlay disposal passed, retaining base and evidence. Full namespace
immutability and final runner acceptance remain open.
The separated canonical-input layout also passed a new networkless clone:
69 forced tasks, read-only/same-object source and dependency mapping assertions,
unchanged canonical manifest and fresh Android instrumentation. Its base
write denial, shutdown, read-only journal preservation and explicitly
authorized overlay disposal passed. Canonical inputs are immutable in the
build namespace; project shells and cache coordination metadata remain
writable disposable state. This does not close full runner or Apple acceptance.
The bounded supervisor also passed cold and resumed replay with live cgroup/
rlimit assertions and checksum-verified captured output below 64 MiB. The
resumed run's live base write denial and shutdown/extraction metadata checks
passed. Direct-backend extraction avoids the reproduced libvirt appliance
ownership change. The stopped bounded overlay is retained by owner choice.
Emulator diagnostics and instrumentation now stream into the shared 64 MiB
collector. A real preparation-guest red/green routing proof passed, with
7,307 bytes captured after the change; saved current script/manifest are
updated. No new cold-clone routing proof is claimed. Earlier emulator
timeout/segfault and aggregate journal/evidence retention remain limitations;
successful replay is not a deterministic reliability claim.
New host extraction now uses the owner-approved 1 GiB ext4 evidence-image
boundary with explicit failure and preserved incomplete output.
Real synthetic CLI tests pass on the preparation guest and Fedora direct
guestfish synthetic integration passes. Owner-run stopped bounded-VM journal
extraction in the new format also passes, preserving image bytes/ownership
and both boot logs with complete status and unmount cleanup.
Existing evidence stays unchanged. See
[ADR 0013](docs/adr/0013-bounded-host-proof-evidence.md) for access-format
migration and the excluded guest/appliance/aggregate storage surfaces.
The owner subsequently approved 8 GiB NEW host aggregate storage, 4 GiB
appliance scratch and 1 GiB guest logging, without eviction, plus a separate
new clone. Host scripts now reserve full images inside the aggregate store;
profile/composition tests pass on Ubuntu and Fedora. Fedora direct guestfish
synthetic extraction with bounded scratch also passes with unchanged source
bytes/ownership. V4 subsequently verified new-clone extraction and guest
logging controls as recorded below. Apple stays paused. The retention clone has a separate 1 GiB
raw log disk; its supervisor reserves replay output before execution and
disables duplicate persistent logging only inside that networkless clone.
Linux collector reservation and no-command-on-ENOSPC tests pass.
Supervisors are installed on preparation; its boot condition correctly skips.
Earlier retention boots failed before target work as recorded below.
The first retention boot failed before target work because kernel disk
enumeration reversed proof/root devices. It is stopped and preserved.
The corrected supervisor resolves the unique `CAIRN_PROOF_LOGS` ext4 label,
validating 1 GiB capacity; real Linux identity/failure tests pass.
The `retention-v2` boot resolved the log disk but failed before target work:
active `syslog.socket` reactivated rsyslog during cutover. Both failed clones
are preserved. Trigger-first stopping/masking and runtime-mask identity
checks pass a shared-helper real synthetic systemd test.
V3 failed before replay on retained `logrotate.timer` failed state after
masking; disks/evidence are preserved. Explicit prior-failure reporting and
post-disable state normalization pass real synthetic failed-unit tests.
The timer's original boot failure remains unverified.
The owner approved a separate V4 clone, preserving V1/V2/V3. Startup cutover
now uses the existing reserved 64 MiB collector on the 1 GiB proof disk,
before journald changes; replay retains its separate unchanged 64 MiB limit.
Real synthetic systemd output-capture red/green passed, including retained
failure diagnostics and child exit. Owner-run V4 passed all 69 cold-build tasks,
JVM assertions and fresh Android instrumentation (20.565s, 4.6G peak, zero swap).
Live topology/base write denial and graceful shutdown passed. Read-only
extraction verified matching startup/replay records for boot
`67e02a91-1f25-4721-b9a9-31cae6343de2`, resource/logging markers and unchanged
base/overlay/log-disk bytes and metadata. Complete root-only 1 GiB evidence is
`bounded-store/retention-v4-replay-volume.ext4`; bounded appliance scratch was
removed and all clones retained. This closes the retention-control integration,
not earlier emulator instability or full Linux runner acceptance.

## Verified profile

Apple isolation assessment has resumed using benign
[hosted probes](proofs/bindings/apple/README.md) under
[ADR 0014](docs/adr/0014-hosted-apple-isolation-probes.md). The unprotected
local CLI failed intended input denial; sandboxed probes passed locally.
Hosted [run 38088954525](https://github.com/trancee/cairn/actions/runs/38088954525)
at `608dee0` passed the same benign probes on ARM64 macOS 26.6.2/Xcode 26.6;
downloaded log/environment checksums passed. Full isolation/resource
enforcement and binding builds remain unverified. Subsequent
[run 38090454490](https://github.com/trancee/cairn/actions/runs/38090454490)
at `3db7ee7` verified unprivileged sandbox/fixed-scratch composition,
real disk/process/CPU enforcement, and a 7 GiB whole-VM RAM envelope
with dynamic pager disabled/unloaded and zero swap. Shared collector
deadline regressions passed; downloaded artifact checksums passed.
Build-tool compatibility and whole-process-tree containment remain open.
Trusted preparation subsequently passed in
[run 38090961772](https://github.com/trancee/cairn/actions/runs/38090961772)
at `3ffd8cf`: pinned Rust/iOS targets, checksum-verified Gradle and exact
Temurin 25.0.4.1+1, plus locked fixture/Ubique Cargo downloads. No fixture
compiled; frozen inputs, offline completeness and build-scale controls
remain unverified.
The dedicated hosted supervisor subsequently passed
[run 38093375336](https://github.com/trancee/cairn/actions/runs/38093375336)
at `3e19313`: deadline cleanup removes a deliberately detached descendant,
retains partial output and confirms the UID is empty. A child observed hard/
soft CPU 900s, NPROC 128, per-file 64 MiB, zero core limits, only primary GID
20 and an explicit environment. These CLI tests are not yet composed with
the sandbox, reserved 8 GiB build scratch or an actual compiler.
No production Apple
acceptance is implied.

- **Public documentation:** [README.md](README.md) introduces the current
  scope; [the documentation entry point](docs/README.md) links the runnable
  wire tutorial, contributor validation guide, foundation API reference and
  compact-PQ/BLE design explanation. Local Markdown links are checked with
  the activated Diataxis skill's `scripts/check-links.py`; no repository
  Markdown formatter or spelling gate is configured. All three Mermaid
  diagrams render with `@mermaid-js/mermaid-cli` 12.0.0 and the installed
  Chrome browser. This is a local documentation check, not a new CI gate.
- **Purpose:** specify and verify `cairn-r1` before implementing the SDK.
- **Languages/toolchains:** Markdown specification and Tamarin `.spthy` models;
  model commands use Tamarin 1.12.0 and Maude 3.5.1.
  The `core/` Cargo workspace pins Rust 1.99.0 for the public wire codecs and
  partial SHA-384/HMAC/HKDF backend seam (AWS-LC and RustCrypto).
  [Core documentation](core/README.md) lists the feature selection, vectors,
  dependencies, commands and remaining gates; [ADR 0012](docs/adr/0012-rust-foundation-increment.md)
  bounds this increment. No protocol state machines or FFI exist yet.
- **Platforms:** formal checks have run on macOS/Apple silicon. Android/iOS
  are intended application targets, not implemented or runtime-tested here.
  Both foundation crates/all backends now cross-compile as release libraries
  for iOS device/simulator ARM64 with Xcode 27 SDKs; this is not linked-app,
  packaged-binding, deployment-floor or device proof. Both crates/all backends
  also cross-compile as release libraries for Android API 26 arm64-v8a,
  armeabi-v7a and x86_64 with cargo-ndk 4.1.2 and NDK r30
  (`30.0.16248370`). No APK, linked shared-library or Android runtime proof
  exists.
  Rust foundation gates pass locally on macOS ARM64 and in all 11 jobs of
  [hosted run 37963154963](https://github.com/trancee/cairn/actions/runs/37963154963)
  at `4ba4955`, including Linux x86-64/ARM64, macOS and mobile cross-builds.
- **Prerequisites/setup:** tool installation is documented in
  [`docs/spec/models/README.md`](docs/spec/models/README.md#tooling).
- **Environment:** before running Tamarin, replay or `act`, read
  [`docs/spec/models/ENVIRONMENT.md`](docs/spec/models/ENVIRONMENT.md);
  `scripts/check.sh` runs the fast gates (also the pre-commit hook and CI).
  `bash scripts/check-rust.sh` runs Rust format/clippy/tests and cargo-deny;
  the pre-commit hook additionally calls it. Miri/careful use the pinned
  nightly in the Rust workflow. Local source line/branch coverage is now
  100% for both crates; error-propagation regions remain uncovered.
  Other ADR 0007
  gates remain incomplete ([issue 46](.scratch/cairn-r1/issues/46-rust-foundation-gates.md)).
  The standalone `core/ct` Memcheck driver (`bash scripts/check-ct.sh`)
  passes both primitive adapters in Linux x86-64/Rosetta and native ARM64
  containers, with required branch/address controls and output-taint checks.
  Hosted native taint jobs also pass with Valgrind 3.22.0.
  Mobile constant-time behavior and unimplemented protocol glue remain
  outside that result.
- **Targeted validation:** from the repository root,
  `tamarin-prover docs/spec/models/ratchet.spthy --open-chains=0 --saturation=0 --derivcheck-timeout=30`
  checks model loading/wellformedness, not lemma verification.
  `--prove=lemma_name` selects a proof obligation.
- **Full validation:** the model README gives full Resume/SAS profiles and
  regression commands. A prior reduced-model diagnosis incorrectly removed
  the `LockStage` marker from release because its `Finish` rule omitted the
  stage increment present in the assembled theory. The marker has been
  restored. The last completed assembled replay verified 55/59 obligations on
  the same marker behavior; a fresh strict replay timed out at 360 seconds.
  The isolated `lock_stage_order` search also timed out at 300 seconds, so
  current full-theory completion remains unverified. A proof-search-only
  relocation of `LockStage` to finish actions timed out on both stage-order
  targets and was reverted. Alternative lifecycle/initial-lock tactics and
  no-reuse induction also timed out; the interactive overview stalled.
  See the model README for exact bounds and limitations.
  These three lifecycle claims now also have compositional evidence:
  Lean 4.34.1 induction and token simulation, arbitrary-key interleavings,
  and source-derived certificates for all 43 rules. Run
  `python3 docs/spec/models/lifecycle/check.py --lean /path/to/lean`.
  The source bridge trusts Tamarin's canonical export and the tested Python
  extractor; it is not native Tamarin replay or a verified Tamarin importer.
  The pin, setup and full trust boundary are in the
  [lifecycle reference](docs/spec/models/lifecycle/README.md).
  `lost_data_recovery` has a verified 826-step witness against a theory with
  the same signature, equations, 43 rules and 13 restrictions; its
  assembled-layout strict replay was system-killed with exit 137 after about
  48 minutes. Repository-owned exact-source replay now verifies that witness
  in 826 steps and its sole source lemma in 9 steps:
  `python3 docs/spec/models/replay.py --timeout 180`.
  It preserves every non-lemma declaration and retained certificate through
  a native MSR roundtrip, removes unrelated lemmas and does not start new
  searches with `--prove`. Full-context certificate-only replay still timed
  out at 300 seconds; assembled completion remains unverified (re-run: both profiles exhaust the 5 GiB heap, no lemma result).
  The [source inventory](docs/spec/models/ratchet-source-evidence.md)
  accounts for 43 goal groups/179 branches; the raw inventory has 30
  residual CK/SS disclosure chains, while the current refined profile has
  16 `Reveal_SS` residual chains. The
  [equation review](docs/spec/models/ratchet-equation-evidence.md) supplies
  an internal termination/confluence/FVP rationale. Separate
  [checker research](docs/research/2026-10-09-tamarin-equational-theory-independent-checkers.md)
  records Tamarin's subterm-convergence check and an external CRC
  local-confluence check on the reduced message equations; CRC assumes
  termination. Neither closes independent combined-theory/FVP acceptance.
  Both gates remain open.
  The opt-in proof-only `DISCLOSURE_SOURCES` profile proves CK/SS
  disclosure origins in 12/8 steps. Before the KEM-origin `[sources]`
  promotion it had 15 refined residual chains; the current profile has 16,
  all `Reveal_SS`. Run
  `python3 docs/spec/models/replay.py --disclosure-sources`. It replays the
  unchanged lost-data certificate in 802 steps and all three source
  certificates. Default proof contexts are unchanged:
  all eight existing safety certificates are migrated in the refined profile.
  No application or SDK build/compatibility gate is available.
- **CI gates/code generation:** no application pipeline or generated SDK
  artifacts exist. Future implementation gates are in the local
  [map](.scratch/cairn-r1/map.md); symbolic verification is not a
  constant-time, byte-parser, persistence or hardware proof.
  The lifecycle runner regenerates proof certificates into a temporary
  directory. The [lifecycle workflow](.github/workflows/lifecycle.yml)
  configures Ubuntu 24.04 matrix jobs with Python 3.13.16, Lean 4.34.1,
  Tamarin 1.12.0 and Maude 3.5.1; official tool archives have pinned hashes
  and actions have immutable revisions. Local actionlint validation and the
  macOS lifecycle runner pass. The first hosted run passed the lifecycle
  gate, both witnesses, KEM origin and fresh-DK origin, then hit the shared
  15-minute job timeout. Each of the eleven replays now has its own 15-minute
  matrix job, separate from the lifecycle gate, with fail-fast disabled.
  The merged matrix run
  [37952930237](https://github.com/trancee/cairn/actions/runs/37952930237)
  is successful; required-check enforcement remains unverified. The same
  workflow also runs default and opt-in disclosure-profile exact-source
  witness replay, refined-certificate replays and its 42 regressions.
  `python3 docs/spec/models/replay.py --disclosure-sources --target kem_ciphertext_origin`
  verifies the KEM origin `[sources]` certificate in 31 steps with all
  three source certificates. Default KEM replay remains 31 steps.
  All eight refined certificates are migrated (`--target`
  `kem_ciphertext_origin`, `fresh_dk_origin`, `encrypted_origin`,
  `extract_origin`,   `ratchet_key_origin`, `session_key_origin`,
  `initial_ck_secret`, `fresh_ss_origin`). After the KEM-origin `[sources]`
  promotion, the exact-prefix safety-only context built from the current
  native export verified 55/55 complete all-traces certificates. It excludes
  the three incomplete serialization lemmas and four existential witnesses;
  it does not establish assembled/full-profile completion. Exact commands,
  hashes, and exclusions are recorded in the
  [source evidence](docs/spec/models/ratchet-source-evidence.md#combined-safety-only-context).
  The focused `encrypted_ct_tail_encapsulated` certificate also verifies in
  four steps in default and disclosure-source contexts. It ties an honest
  outgoing CT tail to an earlier encapsulation; it does not establish the
  origin of arbitrary incoming ciphertext or close the 16 residual refined
  SS chains. Promoting the KEM origin lemma to `[sources]` preserved all
  43 rules and 13 restrictions but increased refined precomputation residuals
  from 15 to 16; source closure remains open.
  A local `gh act` 0.2.89 Linux/amd64 run on Colima/Rosetta passed
  checksum installation, lifecycle proofs and replay regressions, but
  default witness replay hit guest OOM; a bounded-runtime retry timed
  out at 300 seconds. The full local job did not pass and did not reach
  disclosure-profile replay.   Hosted formal matrix checks have passed; the
  full assembled-context replay remains inconclusive.
  `python3 docs/spec/models/mutation.py --timeout 180` now establishes native
  mandatory-mix sensitivity: the unchanged default target verifies in 2 steps,
  and `CLASSIC_FALLBACK` falsifies it in 504 steps. The runner checks exact
  transition correspondence apart from the removed guard and uses no helper
  lemmas. `--mutation NO_PREFIX_GUARD` establishes stored-prefix sensitivity:
  the default `no_partial_mix` verifies in 4 steps and the mutation falsifies
  it in 526 steps. Correspondence requires only two added unguarded tail
  rules, with no other default declaration changes. Separate lifecycle
  matrix jobs are configured but have not yet run on a hosted runner.
  The broader ratchet gate remains open; see the
  [mutation reference](docs/spec/models/README.md#native-mandatory-mix-mutation-regression).

Policy authority: [`CONSTITUTION.md`](CONSTITUTION.md)/[`AGENTS.md`](AGENTS.md).

### CI scheduling and setup

Rust and lifecycle workflows run on pull requests, pushes to `main`, merge
groups and manual dispatch. Feature branches without a PR use manual dispatch;
this avoids duplicate push/PR matrices. Superseded PR runs are cancelled, but
main/merge-group/manual runs are not cancelled. All proof, build, test,
coverage and fuzz gates still execute; results and compiled project targets
are not cached.

Setup caches contain version-keyed host tool binaries, lockfile-keyed Cargo
registry downloads and pinned proof archives. Proof archives are checksum
verified after every restore. Cache misses install the same pinned tools.
The Memcheck apt install omits recommended packages, not its requested
prerequisites. New cache actions are pinned to official `v6.1.0`.

Baseline: PR Rust run `37963979548` took 13m32s; its x86-64 taint job spent
9m26s installing prerequisites (55.8 MB at 103 kB/s), then about 63s checking
and executing the harness. The same commit's push Rust run `37963974833`
took 4m22s and its taint job 1m18s. This establishes setup/network variability,
not slow taint execution. Optimization changes require hosted cold/warm
comparison before claiming a measured speedup; queue and mirror latency
remain outside the repository's control.

Hosted comparison at `aa470f2` (2026-10-09):
[Rust run 37966263807](https://github.com/trancee/cairn/actions/runs/37966263807)
passed all 11 jobs in 3m39s cold and 2m11s warm (attempt 2);
[lifecycle run 37966263691](https://github.com/trancee/cairn/actions/runs/37966263691)
passed all 11 jobs in 4m56s cold and 4m55s warm.
Logs confirm warm binary/registry/archive cache hits. Same-PR reruns preserve
cache scope; manual dispatch cannot read PR-merge-ref caches.
The warm Rust reduction was 40% in this sample; lifecycle wall time did not
materially improve because proof replay/queueing still dominates. These are
single-run observations, not a guaranteed latency budget or attribution of
the anomalous baseline's full 13m32s to repository-controlled work.

Pre-merge scan (2026-10-09): Gitleaks 8.30.1 scanned all 11 proposed commits.
Its 204 generic-key findings were confined to the pinned public Wycheproof
and NIST HMAC fixtures; both file checksums matched recorded upstream
provenance. A temporary exact-findings baseline excluded those known vector
matches, and the remaining history scan passed. No blanket file exclusion
or repository scan suppression was added. This is a point-in-time scan,
not an independent cryptographic/security audit.

Final-head lifecycle run
[37967905307](https://github.com/trancee/cairn/actions/runs/37967905307)
at `83e2edb` failed in `replay-fresh_dk_origin` with
`tamarin-prover: <<loop>>`, exit 1, after theory closure.
Both canonical hashes match the successful warm run above, and both jobs
used the same runner image version and checksum-verified tool archives.
Ten local replays with the exact Linux archives and matching canonical hashes
verified all five retained certificates, but used Rosetta rather than a
native x86-64 runner. The cause remains unresolved; these passes do not
establish that the intermittent crash is fixed. No retry, runtime workaround
or proof change was added.

The bounded native x86-64 diagnostic
[37970902175](https://github.com/trancee/cairn/actions/runs/37970902175)
at `00a3f0c` verified all five certificates on all 20 unchanged-input
replays (43.77–46.08 seconds each). Canonical hashes matched the failed
run. The job used the same Ubuntu image version, Python 3.13.16,
GHC 9.6.7 and four CPUs, with `GHCRTS` unset and the binary's default
`-N`. The temporary diagnostic workflow and driver were removed after
capturing its seven-day hosted artifact. The ordinary Rust/lifecycle
runs `37970902100`/`37970902125` also passed at `00a3f0c`.
No native crash was reproduced, so its cause remains unresolved.
Passing repetitions do not establish a fix or justify a retry policy.

PR #2 was merged at `65fc089` on 2026-10-09 after every check passed on
final head `ce54305`: [Rust run 37972979064](https://github.com/trancee/cairn/actions/runs/37972979064)
and [lifecycle run 37972978282](https://github.com/trancee/cairn/actions/runs/37972978282)
each passed all 11 jobs, and CodeQL passed. The feature branch was deleted.
This accepts only ADR 0012's bounded foundation, not S0 or the full protocol.
Post-merge results are separate from this final-PR-head evidence.

Post-merge Rust run
[37973820517](https://github.com/trancee/cairn/actions/runs/37973820517)
passed at `65fc089`. Lifecycle run
[37973820415](https://github.com/trancee/cairn/actions/runs/37973820415)
failed in `replay-encrypted_origin` during tool installation: `curl` exit 56,
`Recv failure: Connection reset by peer`. Its proof step did not run.
This is a download failure, not the earlier Tamarin `<<loop>>` symptom
or a reported counterexample. No successful post-merge formal run is claimed.

The schema below is retained for the future implementation profile.

```text
profile={purpose,languages/toolchains,supported_platforms/version_constraints,prerequisites,setup/bootstrap,
targeted/full_validation,CI_gates,code_generation}
KMP_add={
version/config_owners:{wrapper,catalog,conventions,included_builds,daemon_JDK,compile_toolchains/bytecode},
target_host_proof_matrix:[{module,target,host,prerequisites,task,proof,limitations}],
proof:compilation|ABI|generated-consumer|runtime|coverage,
checks:{fast_local,clean/forced_CI,host_gaps/owning_jobs},
ABI:{validator,baseline/update/check,final_artifact_scope,unsupported_target_inference},
coverage:{engine,modules/source_sets/test_tasks,thresholds,exclusions,unmeasured_targets},
generated_docs/code:{owning_tasks,outputs,committed_artifact_drift_gates},
processors/plugins:{supported_consumer_toolchains,integration_matrix}}
```
