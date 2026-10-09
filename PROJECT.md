# PROJECT

state=protocol research/specification/formal models + host-only Rust foundation; SDK/application=not implemented.

## Verified profile

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
  accounts for 43 goal groups/179 branches; all 30 residual chains belong
  to CK/SS disclosure branches. The
  [equation review](docs/spec/models/ratchet-equation-evidence.md) supplies
  an internal termination/confluence/FVP rationale, not independent
  acceptance of the mixed message/natural theory. Both gates remain open.
  The opt-in proof-only `DISCLOSURE_SOURCES` profile proves CK/SS
  disclosure origins in 12/8 steps and reduces refined chains to 15
  (all SS). Run `python3 docs/spec/models/replay.py --disclosure-sources`.
  It replays the unchanged lost-data certificate in 802 steps and all
  three source certificates. Default proof contexts are unchanged:
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
  15-minute job timeout. Each of the ten replays now has its own 15-minute
  matrix job, separate from the lifecycle gate, with fail-fast disabled.
  The merged matrix run
  [37952930237](https://github.com/trancee/cairn/actions/runs/37952930237)
  is successful; required-check enforcement remains unverified. The same
  workflow also runs default and opt-in disclosure-profile exact-source
  witness replay, refined-certificate replays and its 42 regressions.
  `python3 docs/spec/models/replay.py --disclosure-sources --target kem_ciphertext_origin`
  verifies the migrated KEM origin certificate in 18 steps with all
  three source certificates. Default KEM replay remains 31 steps.
  All eight refined certificates are migrated (`--target`
  `kem_ciphertext_origin`, `fresh_dk_origin`, `encrypted_origin`,
  `extract_origin`, `ratchet_key_origin`, `session_key_origin`,
  `initial_ck_secret`, `fresh_ss_origin`). The exact-prefix safety-only
  profile replay verifies 54/54 complete certificates (38.7 s); the three
  incomplete serialization lemmas and four existential witnesses are
  excluded, so this is not assembled/full-profile completion.
  A local `gh act` 0.2.89 Linux/amd64 run on Colima/Rosetta passed
  checksum installation, lifecycle proofs and replay regressions, but
  default witness replay hit guest OOM; a bounded-runtime retry timed
  out at 300 seconds. The full local job did not pass and did not reach
  disclosure-profile replay. Hosted formal matrix checks now pass; the
  full assembled-context replay remains inconclusive.

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
