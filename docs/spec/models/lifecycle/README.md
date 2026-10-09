# Lifecycle verification

Reference for the compositional serialization gate adopted in
[ADR 0010](../../../adr/0010-compositional-lifecycle-verification.md).
This is not a replacement for the cryptographic Tamarin proofs.

## Run

Prerequisites: Python 3.10+, Tamarin 1.12.0 and Maude 3.5.1 on `PATH`,
and Lean 4.34.1. The runner rejects missing or mismatched tool versions.
The Lean release is pinned in `lean-toolchain`; only Lean's bundled `Std`
library is used, with no Mathlib or other package dependency.

With an existing Elan installation:

```sh
elan toolchain install leanprover/lean4:v4.34.1
cd docs/spec/models/lifecycle
python3 check.py
```

Alternatively, download the matching platform archive from the
[Lean 4.34.1 release](https://github.com/leanprover/lean4/releases/tag/v4.34.1)
and pass the extracted compiler to `python3 check.py --lean /path/to/bin/lean`.
The runner checks its version; it does not install or change global tools.

The runner executes mutation regressions, expands the current assembled
`ratchet.spthy` with Tamarin, validates every rule and all three target
formulas, and compiles the Lean proofs and source-derived rule certificates
in a fresh temporary directory. Compilation warnings are errors.
It prints the expanded-theory SHA-256 and audits theorem axioms.
The only permitted axioms are Lean's standard `propext`, `Classical.choice`
and `Quot.sound`; `sorryAx` or any custom assumption fails the command.
Every required theorem must have its own audit report; missing or duplicate
reports fail. A theorem depending on no axioms is also accepted.

## CI configuration

[`Lifecycle verification`](../../../../.github/workflows/lifecycle.yml)
defines the `lifecycle` job on `ubuntu-24.04`, for pushes, pull requests,
merge queues and manual dispatch. It runs the same `check.py` entry point.
It also runs the [exact-source witness gate](../README.md#exact-source-witness-replay)
and its separate regression suite; that evidence is native Tamarin replay,
not a Lean lifecycle theorem.
There are no path filters, cached proof outputs, secrets, artifact uploads
or write permissions. Checkout credentials are not persisted.

Python is pinned to 3.13.16. Checkout and Python setup actions use immutable
commit revisions. Tamarin 1.12.0, Maude 3.5.1 and Lean 4.34.1 are official
Linux x86-64 release archives with SHA-256 checks before extraction;
Maude's bundled support files are available through `MAUDE_LIB`.
The runner checks the actual Tamarin-reported Maude version, not only the
archive name. Tools are isolated under `RUNNER_TEMP`; Lean certificates
are rebuilt in a fresh temporary directory. The job has a 15-minute limit.
The hosted runner image and Python setup distribution remain external
dependencies; this is not a hermetic OS build.

Local workflow validation: `actionlint .github/workflows/lifecycle.yml`.
It does not execute the Linux binaries or prove hosted success.
A successful clean hosted run and a repository ruleset requiring `lifecycle`
are still needed before calling this an authoritative merge gate.
This checkout has no Git remote configured; no workflow was dispatched and
no repository ruleset was changed.

## Proof correspondence

| Source surface | Projection |
|---|---|
| `ResumeSlot(pid,r,s)` | `Token.slot s` |
| `StartPermit(pid,r,s)` | `Token.permit s` |
| `BusySlot(pid,r,s)` | `Token.busy s` |
| Linear `IWait` or `RPending`, same key and final stage field | `Token.attempt s` |
| `FinishPermit(pid,r,s)` | `Token.finish s` |
| `LockStage`, `ResumeStart`, `ResumeFinish` | Same ordinal and same event time |
| `I_Start` | Subset of `ResumeStart`, emitted at the same event |
| Other facts, conditions and restrictions | Erased, enlarging the set of allowed traces |

`Lifecycle.lean` proves an invariant by induction over arbitrary finite
executions. It establishes `resume_serialized`, `lock_stage_order`, and
the initiator-start subset corollary `initial_resume_serialized`.
The natural stages are unbounded. The latter corollary is stronger than the
source claim because it does not require its extra `Init` and `Cur` guards.
`two_starts_executable` kernel-checks a completed attempt followed by a second
start, so the abstract serialization claim is not justified merely by an
unreachable second start.

`Refinement.lean` treats linear tokens as multiplicity functions. It proves
that every enabled projected multiset rewrite has an abstract machine step,
with identical resulting inventory. Concrete token traces do not assume
abstract reachability: `projected_trace_simulates` derives it inductively.
`step_records_actions` proves that the three action histories record the
right ordinals at the step's clock, including arbitrary stuttering steps.

`Composition.lean` preserves these invariants across arbitrary interleavings
of arbitrarily many keys, with a common event clock. Fresh initialization
cannot reset an existing key. The two pairing roles are distinct keys;
creating both at one `Pair` event is supported. `global_linear_step` lifts an
enabled local rewrite into that global execution. `global_fresh_pair`
checks the two-role creation step with an explicit freshness premise.
`fresh_creation_preserves_existing` proves that creation cannot replace
existing histories when that premise holds. `global_stutter` permits
unrelated events even before any pair exists; `stutter_records_no_actions`
checks that such events only advance local clocks.

`projection.py` checks key preservation, linearity, multiplicity, arity,
stage increments, initialization freshness, and action labels against the
actual canonical rules. It rejects unknown lifecycle mutations and changed
target formulas/equations/builtins, misplaced token/action facts, persistent
freshness premises and duplicate target/builtin declarations.
`parsing.py` preserves quoted comment markers, checks balanced fact calls
and rejects empty terms, truncated comments/literals and unsupported suffixes.
Generated initialization equalities use each role's extracted inventory
and marker at an arbitrary event clock, together with the two distinct keys.
Other rule equalities use the extracted token lists and action ordinals,
not hand-maintained certificates.
Payload fields of attempt tokens are erased conservatively: even an attempt
with mismatched cryptographic payload may finish in the abstraction.

## Trusted boundary and limitations

The Lean kernel checks the induction, token simulation, event recording,
interleaving invariants and generated schema equalities. The connection from
the Tamarin source to those schemas **also trusts Tamarin's canonical export
and the Python parser/projection checker**. Python is regression-tested, not
formally verified. Lean does not parse Tamarin or mechanize its complete
equational/MSR semantics. In particular, freshness of `Fr(~pid)`, isolation of
linear fact names, and the interpretation of the reviewed natural-number and
role equations use Tamarin's standard semantics.
The source-level hardening is an internal review with mutation regressions,
not independent cryptographic review or expert sign-off.

This is compositional evidence for the three source claims under that
explicit trust boundary, not a native Tamarin proof certificate or a formal
verification of the extractor. The original three Tamarin obligations remain
unproved in that tool; their formulas and search status are unchanged.
Cryptographic claims, source coverage and implementation/constant-time/
persistence proofs are separate gates. The lost-data witness now has
repository-owned exact-source replay; full assembled-context completion
remains unverified.
The CI configuration exists, but hosted execution and required-check
enforcement remain unverified.

## Observed evidence

On macOS/Apple silicon, Lean 4.34.1 and Tamarin 1.12.0:
all 50 regression tests pass, all three Lean modules compile from scratch,
and generated certificates check for all 43 default rules: one initialization,
one acquire, one release, four starts, ten finishes and 26 stutters.
Expanded-theory SHA-256:
`1dd88a6b63d08fb64654d0e82e6f5cae0d37ef445a996e4e139e01965419d380`.
The runner recomputes this value rather than using it as a cached proof.
`actionlint` 1.7.12 (with ShellCheck 0.11.0) accepts the workflow.
Downloaded Tamarin and Maude Linux archives match their official published
SHA-256 hashes; Lean's Linux checksum and the action revisions were checked
against official GitHub release metadata. The pinned Python release lists
Ubuntu 24.04/x64 support.

On 2026-10-09, `gh act` 0.2.89 ran the workflow in a disposable source
copy with Colima 0.10.3, Docker 29.5.2 and Rosetta-backed `linux/amd64`.
The Ubuntu 24.04 image digest was
`sha256:c58e2b364da03b0c804c7d660f2ecbedf2f221a382b9baa0b344b0144780ff43`.
Python setup, all three archive checksums, the clean lifecycle gate and
34 witness-runner regressions passed. The default witness replay was
OOM-killed in the 8-GiB guest. A retry with local-only
`GHCRTS=-M3G -N1 --disable-delayed-os-memory-return` avoided that kill
but reached the runner's 300-second timeout. The disclosure-profile
witness invocation was not reached; the whole job did not pass.
No workflow, claim or proof check was altered.
Local source-copy checkout and CPU translation do not establish hosted
checkout/image parity, timeout enforcement or required checks.
Hosted execution remains unverified.
