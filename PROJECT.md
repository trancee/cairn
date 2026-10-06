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
- **Targeted validation:** from the repository root,
  `tamarin-prover docs/spec/models/ratchet.spthy --open-chains=0 --saturation=0 --derivcheck-timeout=30`
  checks model loading/wellformedness, not lemma verification.
  `--prove=lemma_name` selects a proof obligation.
- **Full validation:** the model README gives full Resume/SAS profiles and
  regression commands. The ratchet's full proof is pending; no application
  build, coverage or compatibility gate is available.
- **CI gates/code generation:** no application pipeline or generated SDK
  artifacts exist. Future implementation gates are in the local
  [map](.scratch/pqcble-r1/map.md); symbolic verification is not a
  constant-time, byte-parser, persistence or hardware proof.

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
