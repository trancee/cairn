# PROJECT

state=protocol research/specification/formal models; application/build/test-pipeline=none.

## Verified profile

- **Purpose:** specify and verify `pqcble-r1` before implementing the SDK.
- **Languages/toolchains:** Markdown specification and Tamarin `.spthy` models;
  model commands use Tamarin 1.12.0 and Maude 3.5.1.
- **Platforms:** formal checks have run on macOS/Apple silicon. Android/iOS
  are intended application targets, not implemented or platform-tested here.
- **Prerequisites/setup:** tool installation is documented in
  [`docs/spec/models/README.md`](docs/spec/models/README.md#tooling).
- **Environment:** before running Tamarin, replay or `act`, read
  [`docs/spec/models/ENVIRONMENT.md`](docs/spec/models/ENVIRONMENT.md);
  `scripts/check.sh` runs the fast gates (also the pre-commit hook and CI).
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
  seven existing safety skeletons still need migration in the refined profile,
  and their regeneration timed out at 240 seconds.
  No application build, coverage or compatibility gate is available.
- **CI gates/code generation:** no application pipeline or generated SDK
  artifacts exist. Future implementation gates are in the local
  [map](.scratch/pqcble-r1/map.md); symbolic verification is not a
  constant-time, byte-parser, persistence or hardware proof.
  The lifecycle runner regenerates proof certificates into a temporary
  directory. The [lifecycle workflow](.github/workflows/lifecycle.yml)
  configures an Ubuntu 24.04 job with Python 3.13.16, Lean 4.34.1,
  Tamarin 1.12.0 and Maude 3.5.1; official tool archives have pinned hashes
  and actions have immutable revisions. Local actionlint validation and the
  macOS lifecycle runner pass. No Git remote is configured, so hosted
  execution and required-check enforcement remain unverified. The same
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
  disclosure-profile replay. Hosted checks remain unverified.

Policy authority: [`CONSTITUTION.md`](CONSTITUTION.md)/[`AGENTS.md`](AGENTS.md).
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
