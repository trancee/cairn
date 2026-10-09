# Formal model: PQ ratchet mixing

Type: task
Status: claimed
Blocked by: 26

## Question

Write and prove the symbolic Tamarin model of PQ ratchet mixing: KEM_EK/KEM_CT chunks carried in DATA frames, with a completed epoch mixed into CK at the next Resume. Follow the [formal-tooling research](../../../docs/research/2026-10-05-formal-model-tooling.md) and cover its 8 ratchet lemmas:
- post-compromise security after one completed epoch;
- resistance to harvest-now-decrypt-later attackers;
- no downgrade to the classical-only path.

Put the model under `docs/spec/models/`. A failing lemma reopens the relevant ADR. This model gates implementing the ratchet, per the formal-verification gate.

## Comments

2026-10-05: Initial [`ratchet.spthy`](../../../docs/spec/models/ratchet.spthy)
is a draft, not an implementation-gate proof. It composes an abstract
authenticated epoch transfer with Resume in a quantum-attacker view.
The current abstraction omits chunk reassembly, epoch counters, alternating
generators, and the two-candidate Resume recovery path. It uses a ciphertext
hash in DONE rather than the specified epoch identifier. Those differences
must be reconciled before resolving this ticket.

Making `pairID` public in both models removes an unintended hidden input to
the attacker's KDF/MAC computations. This is a conservative attacker-model
correction, not a wire-format change. The corrected Resume base and DESYNC
profiles verified (11/11 in 45 s and 12/12 in 97 s). KCI re-verification is
incomplete: `ck_secret`, `cur_secret`, and `I_key_secrecy` timed out at 300 s.
No counterexample was returned by those runs.

Further search experiments are capped at 30 s per lemma. Timeout is
incomplete analysis, never success or evidence of a protocol attack.

With public `pairID`, the following targeted command completed within the
30 s per-lemma cap:
`python3 /tmp/tprove.py docs/spec/models/ratchet.spthy 30 epoch_secret,binding,no_downgrade,hndl_secrecy`.
Results: `epoch_secret` verified (4 steps), `binding` (14), `no_downgrade`
(562), and `hndl_secrecy` (204). The temporary runner is a session tool,
not a repository validation command. These results apply only to the
documented abstraction; they do not prove chunk handling, counter safety,
automatic healing after active interception, or that fallback cannot
postpone PQ mixing.

Accepted decisions (2026-10-05, both recommendation A):
- **OI-21:** non-wrapping `u32` epoch identifiers, canonical LEB128 in
  KEM_EK, KEM_CT and EPOCH_DONE; exhaustion requires re-pairing.
- **OI-22:** a ready initiator retains the epoch until commitment and
  retries with MIX = 1; no automatic classical fallback. Mismatch fails
  closed with a local recovery-required error.

Applied to spec draft 0.5 and ADR 0005. At that point the model did not
represent these decisions or the full transfer/recovery contract.

Subsequent accepted decisions (2026-10-05):
- **OI-23:** each CK candidate carries its post-mix epoch position;
  defer responder erasure until branch confirmation; never double-mix
  during lost-DATA recovery.
- **OI-24:** healing is conditional on an unexposed, genuinely exchanged
  fresh epoch. Previously stolen values remain known; continued active
  interception can prevent healing.
- **OI-25:** authenticated cumulative KEM_PROGRESS after durable storage;
  retain immutable sender objects, resend unacknowledged chunks and
  re-advertise active-branch progress/completion after Resume.
- **OI-26:** contiguous reassembly with exact contained duplicate ranges;
  gaps, conflicts, cross-frontier overlaps, wrong epochs and bounds
  violations fail closed without partial mutation.

OI-25/26 are applied to spec draft 0.6 and ADR 0005. The rewritten model
now includes symbolic epoch positions, alternating-role state, two-piece
reassembly, progress and candidate recovery. Earlier targeted results
above are historical and do not verify this replacement.

Resume's public-`pairID` correction is fully verified: 16/17/19/20 lemmas
in base/DESYNC/KCI/KCI+DESYNC. Its implementation gate is restored.
The composed ratchet gate is separate and remains closed.

Historical proof blocker (superseded by the 2026-10-06 checkpoint below):
`fresh_dk_origin`, `fresh_ss_origin` and
`derived_ck_origin` still reach the 30 s cap with source precomputation
disabled. Source tracing/oracle experiments have not established these
dependencies. Any successful lemma that reuses them is conditional,
not a gate proof. Complete epoch agreement, genuine generator parity,
executability, PCS/recovery witnesses and mutation checks remain required.

The retained model now includes full progress receipts, immutable-object
retransmission, reconnect receipt/DONE rules and completed-prefix duplicate
handling. `latest_progress`, `completed_send` and `prefix_send` are local
state guards, not proved storage implementation.

Wellformedness exposed an invalid hash-preimage match in mixed Resume:
`IWait` held hashes but not the EK/CT objects needed by `I_S2_mix`.
Keeping the pending secret/objects in `IWait` fixes this. The standalone
command `tamarin-prover docs/spec/models/ratchet.spthy --open-chains=0 --saturation=0 --derivcheck-timeout=30`
loads cleanly with derivation checks enabled.

Targeted checks verify `epoch_position_shape`,
`monotonic_epochs`, `no_rollback` and `no_classical_downgrade` in 5/4/4/2
steps. They cover structural guards, not cryptographic composition.
The initial shape lemma has no earlier helpers; the other three explicitly
hide reusable helpers to establish independent proofs.
The stronger parity, completed-peer agreement and stored-prefix mix
properties replace misleadingly weak names/statements. Honest execution,
lost-DATA recovery and post-compromise fresh exchange are pinned witnesses
whose proofs remain pending.

Two explicit mutations are retained: `CLASSIC_FALLBACK` and
`NO_PREFIX_GUARD`. Their targeted BFS searches (with reusable helpers
explicitly hidden in the tested properties)
still time out at 30 s. No attack trace or successful mutation test is
claimed. Removing redundant piece/decoder equations and trying partial
evaluation also failed to terminate the origin/execution proofs within
the cap; increasing timeouts is not a resolution.

2026-10-06: The initiator path could select an already-mixed responder
candidate without publishing its committed generator index. A targeted
honest-recovery obligation was falsified in five steps by index-source
elimination. The model now separates same-position classic commitment
from ahead-of-index candidate commitment; the latter atomically publishes
the CK, session and recovered index. Both initiator and responder
candidate commitment record advancement of the lagging local frontier,
without a second candidate-epoch increment or PQ contribution. See
[ADR 0005](../../../docs/adr/0005-wire-format.md).

Strict unrestricted replay:
`tamarin-prover docs/spec/models/ratchet.spthy --quit-on-warning --derivcheck-timeout=60`.
A session runner enforced a 120 s wall-clock cap. Result: 47 obligations
verified, 10 incomplete; prover processing time 54.58 s. The original
honest execution verifies in 609 steps. Fresh-secret/KDF/CK origins,
chain/session secrecy, conditional epoch-security helpers and generator
parity now have retained replayed evidence. The pending initiator witness
explicitly binds the honest transfer's sessions and pre-commit candidates.
The retained `declared_keys_have_inputs` audit verifies in seven steps;
it is not reused automatically, to avoid injecting unnecessary key-history
goals into unrelated proofs. Event-first authentication experiments,
including limited helper reuse and explicit key shapes, remain
inconclusive within 90 s. Isolated `In`-to-`K` probes motivated disabling
source expansion for the composed acknowledgement proof. With unrelated
reusable helpers removed, `acknowledgement_input` verifies in eight steps
and the reusable `acknowledgement_session` binding in five. Both retained
proofs replay with unrestricted default precomputation in
[`ratchet-acknowledgement.inc`](../../../docs/spec/models/ratchet-acknowledgement.inc).
Neither establishes peer durability. Subsequent lazy-source searches for
authentication, serialization, candidate recovery and progress durability
remain inconclusive at the 90 s cap. Prioritizing session/equation goals
and isolating durability from unfinished authentication helpers did not
close the durability proof.

Remaining default obligations: the three recovery/healing witnesses,
`lock_stage_order`, initial/general Resume serialization, EK/CT
authentication, progress durability and complete
epoch agreement. Existing EK/CT authentication artifacts need repair.
Both mutation attacks, repository-owned proof regeneration, source
coverage and independent convergence/FVP evidence remain open. Strict
precomputation passes but leaves 30 partial deconstructions across
43 source cases. This ticket remains claimed and the implementation gate
remains closed.

2026-10-07: Exact interactive guidance closes `progress_is_durable`
in six steps by splitting ciphertext origin and storage/output ordering
before sourcing keys. EK/CT output provenance is now separated into
original generation/encapsulation and retransmission cases; the two
helpers verify in five steps each. That disjunctive shape avoids recursive
eager expansion of generation events. Repaired `ek_authenticated` and
`ct_authenticated` each verify in six steps.

The strict default replay command above verifies 52 of 59 obligations in
55.80 s (56.45 s wall time). All previously retained proofs replay.
Owners: [`ratchet-durability.inc`](../../../docs/spec/models/ratchet-durability.inc),
[`ratchet-transfer-origins.inc`](../../../docs/spec/models/ratchet-transfer-origins.inc)
and regenerated [`ratchet-transfer.inc`](../../../docs/spec/models/ratchet-transfer.inc).
No rules, restrictions, wire fields or target claims changed.

Seven obligations remain incomplete: the three recovery/healing witnesses,
`lock_stage_order`, initial/general Resume serialization and
`epoch_agreement`. The lazy-source agreement search still reached 90 s
after authentication was repaired. Serialization guidance exposes
recursive predecessor/induction expansion; no serialization proof is yet
retained. Mutation/source-coverage/equational-evidence/regeneration gates
remain open, so this ticket is not resolved.

2026-10-07 (subsequent checkpoint): Minimal high-level reuse and exact
interactive guidance close `epoch_agreement`. Its 132-step generated
proof is retained in
[`ratchet-agreement.inc`](../../../docs/spec/models/ratchet-agreement.inc).
The proof uses EK/CT authentication and generator uniqueness, hiding
unrelated hints without changing the claim, rules or restrictions.

A fresh strict replay of the repository's assembled include layout,
run from `docs/spec/models` as
`tamarin-prover ratchet.spthy --quit-on-warning --derivcheck-timeout=60`,
verifies 53 of 59 obligations in 53.75 s (54.22 s wall time).
Six remain incomplete: `initiator_candidate_recovery`,
`lost_data_recovery`, `fresh_epoch_after_compromise`, `lock_stage_order`,
`initial_resume_serialized` and `resume_serialized`.
Strict precomputation still reports 43 source cases and 30 partial
deconstructions. Both helper-free mutation searches remain inconclusive
at 90 s. Seeding the honest execution with a prior CK reveal also remains
incomplete; the timeout is not a post-compromise execution certificate.
The implementation gate remains closed.

2026-10-07 (fresh execution): Exact replay of the known honest witness,
matching renamed binders and retaining explicit source branches, closes
`fresh_epoch_after_compromise` under the unchanged default rules. The
stronger formula also pins both Resume lifecycles and matching session
events. CK_0 is revealed before the first initiator commit; DK, SS and
other chain keys remain unexposed. This is an existential fresh-epoch
execution certificate, not unconditional healing.

The solved-only generated owner
[`ratchet-fresh-execution-proof.inc`](../../../docs/spec/models/ratchet-fresh-execution-proof.inc)
replays in 617 steps. The same strict full repository replay now verifies
54 of 59 obligations in 72.63 s (73.54 s wall time), including every
previously retained proof. Five obligations remain: the two recovery
witnesses and three serialization claims. No protocol rule, restriction,
wire field or security claim was weakened. The remaining formal evidence
gates are still open.

A session-only lower-stage-prefix invariant was tested as a different
serialization proof route. Hiding reusable predecessor/uniqueness hints
did not stop inductive variable-stage expansion. Both bounded search and
exact last-event-first guidance reached their 90 s caps. No new invariant,
restriction or serialization proof was retained.

2026-10-07 (candidate recovery): The candidate witness now pins one exact
three-Resume recovery trace, including the initial classical Resume, epoch-1
KEM transfer and MIX, responder timeout, role-B candidate commitment, and
epoch-2 generation. Universal conditions in the witness exclude extra
Resume starts/accepts/commits and intervening role-B MIX/confirmation events;
they do not alter protocol rules or restrictions. The generated
`ratchet-candidate-recovery-proof.inc` replays in 507 steps under the
unrestricted default model. Full strict replay verifies 55/59 obligations
in 203.07 s processing time (207.94 s wrapper elapsed). Four remain incomplete:
`lost_data_recovery`, `lock_stage_order`, `initial_resume_serialized` and
`resume_serialized`. The model's source-coverage, mutation-sensitivity,
custom-equation convergence/FVP and proof-regeneration gates remain open.

2026-10-07 (lost-data replay diagnosis): An earlier bounded witness proof
verified in `lost_data_recovery-lean.spthy` (823 steps, 71.89 s). A later
comparison showed that theory retained all 43 default rules and 13
restrictions, but its witness formula differed from the repository claim at
that checkpoint, so it was not evidence for that claim. Grafting that solved
tree into the flattened default theory passed parsing; strict full-context
replay was terminated by the system with exit 137 after 47 minutes.
Formula-only full searches also remained incomplete (BFS reached depth 43;
DFS ran 20 minutes). No proof for the then-current repository formula was
integrated at that checkpoint; no protocol rule or restriction changed.

2026-10-07 (lost-data witness): The earlier 823-step certificate had a
different witness formula and was not used for the repository claim. A
Tamarin 1.12.0 proof of the expanded three-Resume witness verifies in 826
steps (103.34 s). Its source theory was checked against the current flattened
model: the same signature/equations, all 43 default rules and all 13 default
restrictions. The expanded formula pins the Resume lifecycles, candidate
state, timeout and final peer confirmation, and strengthens the former
existential witness without changing any transition or restriction. The
generated certificate is retained in
[`ratchet-lost-data-recovery-proof.inc`](../../../docs/spec/models/ratchet-lost-data-recovery-proof.inc).

The strict assembled-layout command
`tamarin-prover docs/spec/models/ratchet.spthy --quit-on-warning --derivcheck-timeout=60 --prove=lost_data_recovery`
was killed by the system after about 48 minutes (exit 137). This is
inconclusive, not a counterexample; the standalone proof covers the same
transition system, but replay in the full include layout remains
resource-blocked. The witness establishes one feasible recovery trace, not
guaranteed healing or availability under continued interception. Three
default obligations remain without proof evidence:
`lock_stage_order`, `initial_resume_serialized` and `resume_serialized`.
Mutation sensitivity, source coverage, custom-equation convergence/FVP and
repository-owned proof regeneration remain open.

2026-10-08 (initial lock-stage diagnosis; superseded below): A reduced
lifecycle trace showed
that `Release_Resume` emitted `LockStage` a second time at the same ordinal
already emitted by `Acquire_Resume`. This falsified the retained
`lock_stage_unique` helper and interval form of `lock_stage_order` in the
reduced lifecycle (8-step and 7-step counterexamples, respectively). The
proof-only release marker was removed; `LockRelease` remains, and protocol
transitions, restrictions and wire behavior are unchanged. The corrected
reduced lifecycle verifies `lock_stage_unique` (39 steps) and
`lock_stage_predecessor` (12 steps); these are not full-theory evidence.

2026-10-08 (superseding correction): The preceding reduced lifecycle omitted
the completion-stage increment present in the assembled rules: each finish
rule sets `FinishPermit` to the `BusySlot` ordinal plus one. Therefore the
release `LockStage` ordinal is distinct from the acquisition ordinal, and the
claim that release duplicated acquisition was incorrect. In a faithful projection, removing the release marker produces a seven-step
witness against `lock_stage_order`. The release marker has been restored. The
last completed 55/59 replay included that marker; a fresh full strict replay
timed out at 360 seconds. An isolated restored-source search for
`lock_stage_order` with `--heuristic=I` timed out at 300 seconds after 18,346
constraints. Earlier timeouts from the marker-removed theory do not establish
results for this source. Restored-source searches for
`initial_resume_serialized` and `resume_serialized` each timed out at
300 seconds. The faithful reduced lifecycle verifies `lock_stage_unique`
(65 steps) and `lock_stage_predecessor` (14 steps), but these are not
full-theory evidence. Mutation sensitivity, source coverage, custom-equation
convergence/FVP and repository-owned proof regeneration remain open.

Further searches remain inconclusive: `lock_stage_order` with
`--heuristic=O` exceeded 120 seconds; `resume_serialized` with
`--heuristic=I --derivcheck-timeout=0` was stopped after 240 seconds as
`ResumeFinish` interval constraints continued to expand. A proposed
monotonic-stage helper timed out after 180 seconds and was discarded. The
interactive UI loaded the theory, but the overview request stalled and the
server was stopped. No rule, restriction, or target formula changed.
Combining `--no-reuse --heuristic=O --derivcheck-timeout=0` timed out at
120 seconds for each remaining target.
Moving `LockStage` from release to each matching finish action was also tried
with the stage ordinal unchanged; both `lock_stage_order` and
`lock_stage_predecessor` timed out at the 180-second process cap with
`--derivcheck-timeout=0`. That proof-search-only instrumentation change was
reverted. No new assembled-theory evidence was obtained.
Later tactic variants also timed out: `lifecycle` for `lock_stage_order`,
`lifecycle` for `resume_serialized`, `initial_lock` for
`initial_resume_serialized`, and `--no-reuse --heuristic=I
--derivcheck-timeout=0` for both stage ordering and general serialization,
each at a 180-second cap. An interactive UI theory overview stalled after
30 seconds; minimal-source-precompute settings aborted strict wellformedness
checks. These are inconclusive, not proof or attack results. All experimental
tactic annotations were reverted.

2026-10-09: The accepted compositional approach now has a passing repository
runner at `docs/spec/models/lifecycle/check.py`. Lean 4.34.1 proves unbounded
serialization/marker-order invariants, concrete linear-token simulation,
action-history recording and arbitrary-pair interleavings. The runner checks
all 43 default-rule projections and the exact three source claims, generates
Lean token/action certificates, and rejects changed equations, multiplicities,
key/stage mismatches and missing markers. All 24 regressions pass; Lean
reports only standard kernel axioms, with no `sorryAx` or custom assumptions.

The source bridge trusts Tamarin's canonical export and the tested Python
projection checker. The latter is not formally verified; no claim of native
Tamarin completion or mechanized full Tamarin semantics is made. See
[ADR 0010](../../../docs/adr/0010-compositional-lifecycle-verification.md) and
the [lifecycle reference](../../../docs/spec/models/lifecycle/README.md).
Native Tamarin searches for the three claims remain inconclusive; lost-data
replay, source/equation evidence and authoritative CI integration remain
separate open gates. No protocol rule, restriction, target formula, wire field
or staged proof tree was changed.

2026-10-09 (source-boundary hardening): An internal review added intended-red
mutation regressions and corrected ignored token/action positions, persistent
`Fr` premises, duplicate target/builtin declarations and discarded empty
terms. Fact parsing now preserves quoted comment markers and rejects
malformed calls/suffixes. Pair certificates use both extracted role
inventories and markers rather than a fixed initialization equality.
Lean now proves fresh creation preserves existing histories and supports
global unrelated-event stuttering, including before initialization.
All required theorem audits are checked individually. The clean runner and
all 46 regressions pass with the same expanded-theory digest recorded in
the lifecycle reference. The index was preserved; no protocol source changed.
This is not independent expert review or a verified extractor; authoritative
CI, lost-data replay and source/equation evidence remain open.

2026-10-09 (CI configuration): Added
[`.github/workflows/lifecycle.yml`](../../../.github/workflows/lifecycle.yml)
for push/PR/merge-queue/manual execution, with a stable `lifecycle` job,
read-only permissions, no retained checkout credentials or proof cache,
immutable action revisions, Python 3.13.16 and checksum-pinned official
Linux archives for Lean 4.34.1, Tamarin 1.12.0 and Maude 3.5.1.
The runner now rejects missing/wrong Maude versions, following two
intended-red regressions. All 50 regressions and the clean local proof
runner pass; actionlint 1.7.12 with ShellCheck 0.11.0 accepts the workflow.
Downloaded Tamarin/Maude archives match official hashes; Lean's published
hash and action revisions were verified against official metadata.
No Linux runtime or hosted execution is claimed. This checkout has no
Git remote; no push, dispatch or required-check setting was performed.
Authoritative CI evidence remains blocked on hosting and approved execution;
the other ratchet gates and original theory digest are unchanged.

2026-10-09 (repository-owned exact-source witness replay): Added
[`replay.py`](../../../docs/spec/models/replay.py), deriving its input through
Tamarin's native MSR exporter from the current assembled source. It keeps the
witness and every `[sources]` lemma (currently only `dk_reveal_owner`) and
checks the full non-lemma prefix and retained formulas/attributes/certificates
after native roundtrip. All 43 rules, 13 restrictions, signature and equations
are unchanged. The strict replay without `--prove` verifies the witness in
826 steps and source lemma in 9 steps (105.69 s processing time).
The 32 correspondence/selection/result/process regressions and workflow
schema validation pass; the workflow now runs this gate too.
Source/replay native-export digests and exact commands are in the
[model reference](../../../docs/spec/models/README.md#exact-source-witness-replay).

The saved successful export also contained unfinished existential siblings;
the retained solved-only certificate has no `sorry`. `--prove` starts
automation beyond certificate checking: the same minimal context with that
flag timed out at 240 seconds. Full assembled-context certificate-only replay
also timed out at 300 seconds. Consequently the exact-transition-system
witness is reproducibly verified, but there is no new full-context replay
count. Protocol files and existing generated proof trees were not changed.
Source/equation evidence, broader protocol mutations, independent expert
review and hosted CI execution remain open.

2026-10-09 (source and equation audit, without local Actions): Fresh strict
default precomputation completed with 43 raw/refined source-goal groups
and 30 residual chains. Loopback interactive source routes exposed all
179 branches in both inventories even though the overview route timed
out. Every residual chain is in a `Reveal_CK` or `Reveal_SS` branch:
15 attacker-knowledge shapes, two partial branches each. The other 28
groups/78 branches have no residual chain in this snapshot.
The [source evidence](../../../docs/spec/models/ratchet-source-evidence.md)
records the full classification, remaining reveal premises and commands.
This is an inventory, not a proof eliminating the chains.

The [equation evidence](../../../docs/spec/models/ratchet-equation-evidence.md)
records the exact six message rules, a decreasing-size termination
argument, the non-left-linear repeated-key confluence obligation, and
the documented subterm/ground finite-variant rationale. The sorted AC
natural-number combination and independent equation acceptance remain
explicit review obligations; no formal certificate is claimed.
The canonical digest is unchanged. No protocol, source-lemma attribute,
restriction or proof tree changed. The inspection server was stopped;
no `act`/Docker installation or local Actions run was performed.

2026-10-09 (disclosure source refinement): Added generated raw-source
certificates `ck_disclosure_origin` (12 steps) and
`ss_disclosure_origin` (8 steps), without ordinary reuse helpers or
transition changes. The opt-in `DISCLOSURE_SOURCES` profile reduces
refined partial chains from 30 to 15, all in `Reveal_SS`; raw chains
remain 30. Strict exact-prefix replay verifies these and the existing
9-step DK source certificate. The unchanged lost-data certificate
checks in 802 steps in the refined context, rather than the default's
826. No protocol/witness certificate was weakened or rewritten.

Compatibility checks exposed eight safety skeletons whose source-case
branches need migration. The 54-certificate safety-only context verifies
46 and reports those eight incomplete; targeted regeneration and a
58-complete-certificate context each timed out at 240 seconds.
The refinement therefore remains a diagnostic proof profile, not the
default model context. A KEM-origin promotion verified against raw
sources but increased chains to 16 and was not retained.
Remaining SS cases require ciphertext-payload origin reasoning across
accepted encrypted pieces and recursive disclosures.
The [evidence](../../../docs/spec/models/ratchet-source-evidence.md#opt-in-disclosure-refinement)
records the exact compatibility list and limits.
Added explicit profile selection to the witness runner and CI; its two
selector regressions followed intended red/green. Overall source
closure, full-model verification and independent review remain open.

2026-10-09 (first refined safety migration): `kem_ciphertext_origin`
now verifies in 18 steps under `DISCLOSURE_SOURCES`, retaining the
exact formula and attributes. Its existing default certificate remains
31 steps. Direct source-state inspection identified the changed SS
decapsulation branch; splitting destructor variants, resolving the
chain and induction on earlier KEM knowledge closed it without
expanding session histories. Added a generated profile-specific
certificate and explicit safety-target selection to the replay runner,
with intended-red/green tests. CI checks the selected KEM certificate
and all sources; no ordinary reuse helpers are needed.
At this point the complete safety-only refined context verified 47/54;
superseded below by the 54/54 re-measurement. The 15 SS source chains are unchanged.
No protocol/rule/restriction/equation/formula change or default cutover
was made. See the [migration evidence](../../../docs/spec/models/ratchet-source-evidence.md#first-migrated-safety-certificate).

2026-10-09 (second refined safety migration): `fresh_dk_origin` verifies
in 46 steps under `DISCLOSURE_SOURCES` with unchanged formula and
attributes, via a generated profile-specific certificate. The same
`Reveal_SS` / `Decode_known_ciphertext` branch (both `Pair` cases) was
closed by destructor splitting, the `kem_ciphertext_origin` disjunction
and the `~~>` chain. `replay.py --target fresh_dk_origin` retains the
declared dependency `kem_ciphertext_origin` (5 new intended-red/green
tests; 42 total). Default digests unchanged.

2026-10-09 (remaining refined migrations): `encrypted_origin`,
`extract_origin`, `ratchet_key_origin`, `session_key_origin` and
`initial_ck_secret` and `fresh_ss_origin` (101 steps) migrated the same
way; each verifies via `replay.py --disclosure-sources --target`. CI loops
over all eight targets.

2026-10-09 (re-measurement): the exact-prefix safety-only profile context
(61-lemma export minus 4 existential witnesses and 3 incomplete
serialization lemmas) verifies **54/54** in 38.7 s (pre-rename theory `PqcbleRatchet`; native export SHA-256
`2421f43c5907ff5a2e96e4dea404a643b472ed25ab38922bf6bc11b48f49bfe1`,
selected context `f82357a72ab9304d2438d3311986ebdd48e312a346f3fa1cb974e414fae195d0`).
Not a full-theory count; the 15 SS source chains remain.

2026-10-09 (current evidence reconciliation): all eight refined safety
certificates are migrated. All 11 hosted formal jobs passed on final PR #2
head `ce54305` in
[run 37972978282](https://github.com/trancee/cairn/actions/runs/37972978282).
The bounded Rust foundation was merged at `65fc089`, not the ratchet
implementation gate. Earlier comments describing missing hosting or pending
certificate migrations are historical. Full assembled-context completion,
15 residual SS source chains, independent combined-equation acceptance and
broader protocol mutation coverage remain open. Required-check enforcement
is not configured. The recurrent Tamarin runtime crash remains unexplained
after 20 exact-input native replays passed.

2026-10-09 (bounded mutation follow-up): the user confirmed the native
assembled-theory test boundary with the existing mutation flags, not
mocked results or a reduced transition system. Depth-first searches for
`CLASSIC_FALLBACK` / `no_classical_downgrade` and `NO_PREFIX_GUARD` /
`no_partial_mix` each hit an externally enforced 90-second process cap
on macOS with Tamarin 1.12.0 and Maude 3.5.1. Both used
`--quit-on-warning --derivcheck-timeout=60 --open-chains=0 --saturation=0
--stop-on-trace=DFS`. The first fallback probe with a 30-second derivation
budget failed its derivation checks; correcting to the documented 60-second
budget still produced a process timeout. No counterexample or proof-sensitivity
regression was established, and no model, certificate or gate was changed.

2026-10-09 (guided mandatory-mix counterexample): Native loopback guidance
found a solved `CLASSIC_FALLBACK` / `no_classical_downgrade` trace. The proof
context retained the entire canonical mutation prefix and unchanged target,
omitting only unrelated lemmas. The attacker uses an allowed initial-CK
reveal to complete a classical Resume, derive session keys and inject both
CT pieces. Role A becomes `Ready`, then starts another classical Resume in
the same epoch without `Advance`. The normal mandatory-mix guard excludes
that ordering.

The generated attack-only include contains no unfinished proof steps.
The attack extractor prunes unselected alternatives and natively replays
the chosen path before writing it. `mutation.py --timeout 180` freshly
exports both assembled profiles, rejects any transition difference beyond
removal of `mandatory_mix`, requires identical target formula/attributes
and retains no helper lemmas. The intended-red run verified the default
claim but failed on the mutation's old `analysis incomplete (3 steps)`.
The green run verified the default in 2 steps (38.00 s) and falsified the
mutation in 504 steps (44.37 s). These are native Tamarin processing times
on macOS, not Linux/CI wall times. The default export SHA-256 remained
`d5678674a4dfdff8fb5997fc8bc0202b7818f0cdcf9ac1f5aa4089d40d89e8e0`.

A dedicated lifecycle CI job and the local opt-in replay gate now run this
regression; hosted execution of the new job remains unverified. See the
[mutation reference](../../../docs/spec/models/README.md#native-mandatory-mix-mutation-regression).
This establishes only mandatory-mix sensitivity in the deliberately mutated
symbolic model, not a vulnerability in the guarded protocol. Prefix-guard
sensitivity, assembled-context completion, SS source closure, independent
equation acceptance and the implementation gate remain open.

2026-10-09 (guided stored-prefix counterexample): Native guidance also
completed `NO_PREFIX_GUARD` / `no_partial_mix`, retaining the full canonical
mutation transition system and only the exact target lemma. The trace uses
an allowed initial-CK reveal to finish a classical Resume, forges an
authenticated CT tail without a CT prefix, and reaches `I_S1_mix`/`MixStart`
after unguarded tail acceptance. No `CTPrefix` event appears. The normal
mandatory-mixing restriction stays present. This is a deliberately mutated
symbolic-model counterexample, not a guarded-protocol vulnerability.

The new `mutation.py --mutation NO_PREFIX_GUARD --timeout 180` gate checks
that only the two unguarded tail rules are added, that each removes just its
stored-prefix premise (plus its rule/diagnostic rename), and that every
default declaration and target formula/attribute is unchanged. The intended
red observed default verification in 4 steps, then rejected the mutation's
old `analysis incomplete (6 steps)`. The green replay verified the default
in 4 steps (38.75 s) and falsified the mutation in 526 steps (45.10 s).
The default canonical export SHA-256 remains unchanged. Both profiles omit
all helper lemmas while retaining every non-lemma declaration.

`extract_attack.py` now generates both native attack-only includes; neither
contains unfinished steps. It replaced the fallback-specific extractor
before publication. Both mutations have separate CI jobs and local opt-in
replay commands; hosted execution is unverified. The trace exercises the CT
side, not a separately guided EK attack. Both original symbolic guard
mutations now have native sensitivity regressions. Full-context completion,
SS source closure, independent equation acceptance and the implementation
gate remain open.

2026-10-09 (first mutation CI diagnosis): PR #4 at `5b29d90` ran both new
jobs in [37985431090](https://github.com/trancee/cairn/actions/runs/37985431090).
Both failed the default export's strict derivation check at 60 seconds,
before any replay result. All 11 existing formal jobs passed, as did Rust
and CodeQL. This is a derivation timeout, not a found trace or the earlier
`<<loop>>` exception.

The exact checksum-pinned Linux binaries reproduced failure with guided
precomputation flags and success with standard export. Guided replay also
timed out at 60 seconds; standard replay made the attack skeleton incomplete.
A strict 120-second guided derivation budget completed the fallback replay
in 74.24 seconds with its unchanged 504-step attack. The runner now separates
standard export (60 seconds) from guided certificate replay (120 seconds),
retaining the 180-second external cap and strict warnings. No retries,
validation bypass or protocol/claim changes were introduced. This local
Linux result used Rosetta, not native hosted execution.

The complete corrected Linux/Rosetta runner then passed both profiles:
default/`CLASSIC_FALLBACK` verified/falsified in 2/504 steps (63.91/74.10 s);
default/`NO_PREFIX_GUARD` verified/falsified in 4/526 steps (67.04/75.40 s).
Transition-prefix digests matched macOS. Fast gates, pinned Lean, links,
workflow syntax and model secret scanning also passed. Hosted native
confirmation remains required.
