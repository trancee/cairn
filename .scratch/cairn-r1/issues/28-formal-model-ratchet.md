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

2026-10-14 (published 53-audit checkpoint; see the derivation-kind follow-up
at the end): the owner-approved `guarded-maude-boundary` is wired into all
ratchet acceptance callers. It rejects altered modules, improperly sorted
queries/whole replies, unsafe variable namespaces and missing/inconsistent
private lifecycle evidence; it never filters solutions. Real native operations
and guarded Tamarin parsing pass. The canonical export is unchanged; parse-only
median overhead measures `+3.5%`. Python/tool/importer trust remains explicit.
Complete sorted AC-unification/FVP transfer and full assembled replay are still
open, so this is not implementation/default activation or publication approval.
Earlier query-membership comments below are historical checkpoints.

2026-10-14: free tuple/Node framing closure is now kernel-checked under raw
structural AC, rewriting and typed substitutions, including node assignments.
The naive `h(list(nil))` framing kernel red and old 50-audit CLI red are green;
the [checker](../../../docs/spec/models/equations/README.md) requires 53 audits.
This free framing envelope is wider than the exact printed tuple grammar.
Actual caller/input/output membership, substitution provenance and native
narrowing/unification/FVP acceptance remain open. This checkpoint supersedes
the earlier node-fixed assignment, without changing equations, API, wire,
runtime, CI jobs or ceilings. Local/unpublished; implementation remains closed.

2026-10-14: the [equation checker](../../../docs/spec/models/equations/README.md)
now requires 50 audits. Independent raw structural AC and six-rule/context
rewriting preserve and reflect the encoded message image; every recognized
term is an encoding. Encoded quotient steps have typed matching realizations
modulo AC. Typed natural/message substitution commutes with encoding, with
rigid atom indices frozen and public/fresh assignments kept sort-separated.
The rigid-natural substitution kernel red and old 26-/44-audit CLI reds
are green. The native assignment fixes node variables; actual framing/query
construction, backend substitution provenance, narrowing/unification closure
and complete sorted AC-unification/FVP acceptance remain open.
This increment is local/unpublished, with no equation, API, wire, primitive,
constant-time, CI-job or resource-ceiling change. Ticket stays claimed,
profile opt-in and implementation closed. Earlier comments are snapshots.

2026-10-14: the [equation checker](../../../docs/spec/models/equations/README.md)
also checks frozen-index natural/message encoding left inverses and injectivity.
Variables and rigid atoms with the same native index remain distinct in the
mathematical carrier. The kernel collision red and missing-image-audit CLI red
are green; all 26 audits and image rejection cases run in the existing cell.
This is a structural encoding foundation, not completed native AC/matching/
substitution/framing correspondence or narrowing/unification closure.
No native index, protocol counter, wire data or acceptance gate changes.
The increment remains local/unpublished.

2026-10-14: the local [equation checker](../../../docs/spec/models/equations/README.md)
now proves a substitution-independent normalization bound, global matching
confluence and quotient-path confluence modulo natural AC. Nonlinear key-copy
peaks, AC path transport and normality invariance are checked; all 22 audits
and kernel cases run in the existing lifecycle cell. Missing boundedness and
confluence reports have intended CLI red/green coverage. This increment is
unpublished; current-source hosted acceptance is not claimed.
The owner selected the actual typed protocol-query image for correspondence.
Native preservation/reflection, substitution/unification/narrowing closure,
remaining FVP hypotheses and full assembled replay are still open.
Ticket stays claimed, profile opt-in and implementation closed.

2026-10-14: the local [equation checker](../../../docs/spec/models/equations/README.md)
now also kernel-checks typed B-coherence and matching soundness modulo natural
AC. AC-equivalent repeated keys and the inherited termination relation are
covered; five new audits are mandatory. The source/CLI/kernel red/green
boundary is preserved. The published termination checkpoint passed
formal/Rust/four-language CodeQL at `70c1c19` in PR #9; this addition is
unpublished and has no hosted acceptance yet. Native query-image/FVP acceptance
and full assembled replay remain open. No profile,
implementation or merge authorization changes.

2026-10-14: the source-guarded [equation termination checker](../../../docs/spec/models/equations/README.md)
kernel-checks all six message equations in every typed context modulo sorted
natural AC, with generated source correspondences and six mandatory axiom audits.
At authoring, local checks pass and hosted acceptance is pending. Sorted CRC local
confluence/sort-decreasingness and exhaustive native flat patterns are additional
evidence, not a mixed-theory/FVP certificate without the missing admissibility/
coherence and source/signature correspondence. Full assembled replay remains
incomplete. Ticket stays claimed, profile opt-in and implementation closed.

2026-10-13: joint raw-source induction of KEM and encrypted CT-tail origins
verifies in 60 steps and closes refined deconstructions (43 groups, zero
residual chains). All 56 completed safety certificates replay together;
all four existential witnesses replay independently with unchanged
43-rule/13-restriction transitions. The stale fresh-SS proof is regenerated
without formula changes. Repository replay fails on missing/partial source
completion and unexpected incomplete safety claims. Workflow/local gates
include the joint source, safety suite and all witnesses.
Full assembled invocation was system-killed with exit 137 before a summary.
All 19 formal jobs passed at `85aa105` in
[run 38442377893](https://github.com/trancee/cairn/actions/runs/38442377893).
Independent combined-equation/FVP acceptance remains open.
Ticket stays claimed; implementation gate stays closed.
See [current evidence](../../../docs/spec/models/ratchet-source-evidence.md#current-result-2026-10-13).
Earlier comments below are historical and do not state current source counts.

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

2026-10-14 (required derivation-kind follow-up): published `3d5dd7c` passed
the lifecycle cell but failed all 18 replay/mutation cells in
[formal run 38622779805](https://github.com/trancee/cairn/actions/runs/38622779805).
The exact default replay and a valid paired-counter input reproduced
`tamtplus(x0:Fresh,tamXCtone)` locally. Pinned Tamarin deliberately applies
`natToFreshVars` inside premise constructors during derivation checks.
The owner chose `extend-derivation-kind-image`, not a bypass or backend patch.

The guard now admits only controlled Fresh/natural sum leaves and their
enclosing message/free framing contexts. Arbitrary operands, kind variables
and kind-valued returned bindings/results still fail closed. Disjoint
proof-only shadow labels have a checked inverse/injectivity; raw AC/rewrite
transfer, image closure, substitution commutation and decoded-kind termination
are checked. Framed substitution closure has a typed-shadow compatibility
premise not yet universally derived. Raw rules omit native proper-message
guards, so these results do not establish native confluence, normalizing
paths, complete narrowing/unification or FVP.

The real derivation regression, kernel collision and old 53-audit CLI
red/green checks pass. Fresh fast gates pass 115 model/50 lifecycle tests,
43 projections, six correspondences and 67 audits (21 axiom-free).
The original guarded default recovery verifies in 826 steps plus the
nine-step ownership helper (`127.70` seconds of reported proof processing).
The guarded refined complete-safety context verifies all 56 certificates
with complete sources (`54.59` seconds). Rules/restrictions remain 43/13.
Final parse-only comparison is byte-identical at the canonical SHA,
`1.494`/`1.535` seconds median (`+2.7%`); full-search/memory overhead is
unmeasured. These are local selected contexts, not full assembled acceptance.
The fix is unpublished; the failed hosted run remains unsuperseded.
Implementation/default activation and complete native FVP acceptance stay closed.

2026-10-14 (representative performance follow-up): both real mutation runners
pass under original limits: default/`CLASSIC_FALLBACK` verifies/falsifies in
2/504 steps (`60.58`/`71.80` seconds), and default/`NO_PREFIX_GUARD` in
4/526 steps (`65.22`/`70.57` seconds). A whole-model, strict derivation-check
export benchmark then exposes `+46.3%` direct/guarded overhead:
`24.178`/`35.385` seconds median across three alternating paired runs with
identical bytes and unchanged `120`-second caps. The one-rule fixture has
`+0.301` seconds fixed cost (`0.116`/`0.417`, `+259.5%`). These measure the
whole guard, not just the incremental kind parser. Parse-only `+2.7%` was
not representative of this path.

The checked diagnostic profile retains the identical export and observes
90,874 operations, 181,760 per-event report opens/writes/closes and `8.619`
instrumented seconds in record handling. Report-I/O optimization or an
explicit approved budget/rationale is still needed under Constitution P4;
no waiver, relaxed deadline or performance acceptance is implied. Native
sorted matching/FVP and full assembled replay also remain open.

2026-10-15 (approved evidence-I/O optimization): the owner selected
`optimize-evidence-io`, not a performance exception. The guard now retains
every operation event through one validated append descriptor per process,
with bounded 16 KiB batching plus at most one record. The journal flushes and
closes before successful shutdown evidence. Other lifecycle/failure records
remain immediate; partial writes, report-capacity failures and incomplete
reconciliation still reject the entire command. Selector reuse and shared
canonical parser/audit fast paths preserve the original validation paths.

The final-source fast gate passes 117 model tests, 50 lifecycle tests,
43 projections, six source correspondences and 67 audits (21 axiom-free).
New CLI/native-stream regressions cover complete 512-operation evidence and
controlled report-capacity failure. The optimized default recovery replays
in 826 steps plus the nine-step helper (`106.77` seconds), and all 56 refined
safety certificates verify with complete sources (`44.85` seconds).
Default/`CLASSIC_FALLBACK` verifies/falsifies in 2/504 steps
(`48.50`/`55.13` seconds); default/`NO_PREFIX_GUARD` in 4/526 steps
(`49.82`/`56.79` seconds). These are reported proof-processing times,
not paired benchmarks. All proof options, rules, restrictions and deadlines
are unchanged.

The representative final-source three-pair export benchmark measures
`24.303`/`29.761` seconds direct/guarded median (`+22.5%`), with identical
bytes at the same full-export SHA-256. This is approximately 16% faster than
the initial whole guard, but still exceeds Constitution P4's 10% merge limit.
An unsuccessful single-pass token experiment was removed. No performance
budget exception, compiled/upstream rewrite, publication, merge or activation
is approved. Native sorted matching/narrowing, complete AC-unification/FVP
transfer and full assembled acceptance remain separate open gates.

2026-10-15 (compiled proxy feasibility): the owner selected
`prototype-compiled-proxy`, explicitly measuring before any default cutover.
The [opt-in Rust prototype](../../../docs/spec/models/equations/native-proxy/README.md)
has no third-party dependencies and shares the reviewed generated inventory.
It retains iterative query/reply recognition, all sort/kind/namespace/index
and whole-solution checks, complete journals, checked write/close failures and
ready/pending interruption. Native process POSIX FFI is isolated from app/core
code. The Python acceptance route and proof deadlines remain unchanged.

Intended reduction and missing-unification reds are green. All 18 opt-in
CLI/process/proof checks, strict Rust formatting/Clippy and the existing
117-model/50-lifecycle/67-audit fast gate pass. Three alternating complete-export
pairs on Apple-silicon macOS measure direct/prototype medians
`24.281`/`25.931` seconds (`+6.80%`), with unchanged full-export SHA-256
`aaaf873a9b7baff6fbf209f1cf87088581552498ade6f9a5e471ee2b5ea6fb5d`.
This workload is below `10%`, but tiny derivation startup separately adds
`39.93` ms (`0.118`/`0.158` seconds, `+33.76%`); no absolute allowance is
approved. Default Python overhead remains `+22.5%` and performance-blocked.

The experiment establishes local representative feasibility, not exhaustive
parser equivalence, full-proof/memory performance, Linux/full-caller parity
or global P4 acceptance. Maintained integration/default replacement needs
separate approval and validation. No commit/push/hosted dispatch/merge,
protocol/API/wire/primitive/constant-time change or implementation activation
occurred. Native sorted matching/narrowing, complete AC-unification/FVP
transfer and full assembled acceptance remain open.

2026-10-15 (promotion and bounded startup budget): the owner selected
`promote-with-50ms-startup-budget`. The startup-only three-pair median
additional allowance is `50` ms; the representative full-export limit remains
`10%`, and no proof deadlines or checks are relaxed. The rationale and exact
workload/environment/method are recorded in
[ADR 0010](../../../docs/adr/0010-compositional-lifecycle-verification.md#maintained-proxy-promotion-and-startup-only-budget-2026-10-15).
Linux parity, all caller regressions and CI integration must pass before
default cutover. Local Docker is unavailable and Colima is stopped; this host's
documented memory/emulation limits do not establish native Linux proof parity.
The owner subsequently selected `publish-promotion-checkpoints`, authorizing
commits, pushes and PR-description updates limited to this promotion, necessary
fixes and conditional cutover after the required criteria pass, using PR #9's
existing native CI. No manual dispatch, merge or SDK/profile activation is
authorized.

Maintained staging is now implemented under `equations/native-proxy`, with
generated source identity in every compiled version record and mandatory
current-source reconciliation. Invalid/missing/stale candidates reject rather
than silently building or falling back. All existing callers retain the shared
runner; explicit candidate selection stages local/19-cell CI validation before
default cutover. `scripts/check.sh` builds and statically checks the host tool;
CI names its internal-tool coverage exclusion and adds both rejecting
three-pair budget gates without new jobs or longer deadlines.
The clean local candidate gate passes 19 native cases, 138 model tests,
50 lifecycle tests, 43 projections and 67 equation audits. The missing-identity
and unsupported budget-mode reds and real stale-executable rejection are
retained, together with controlled source-input/inventory-output I/O reds.
Current-source three-pair medians are `24.248549`/`25.807651` seconds for
full export (`+6.4297%`) and `0.110541`/`0.147073` seconds for startup
(`+36.531959` ms, `+33.0482%`), both passing the separately approved limits.
The final build also passes original-cap recovery (826+9 steps), complete
refined safety (56 certificates) and both mutation regressions (verified
defaults, 504-/526-step attacks). All non-lemma declarations remain identical.
These four selected local contexts are not native Linux/all 19 CI cells;
run `38710117729` at `2e7b429` passes all 18 native caller cells and fast
gates, but rejects an unreviewed benchmark export before any budget verdict.
A public CLI diagnostic red now requires the phase and expected/observed
hashes without output payloads; it passes without weakening any check.
Full native acceptance and default cutover remain blocked.

Diagnostic run `38712391261` at `942f8d8` again passes all 18 native caller
cells and fast gates, and identifies the rejected direct baseline before any
guarded sample. The inventory had only the macOS full-export digest.
Retain the exact observed pinned Linux digest
`1b66b2a76902af6c98de7b22edbe6f4d8fddc27cd2adb580db6d5eff639dbd48`
as well, not a digest derived from the first runtime sample. Every output must
match the fixed inventory and all six outputs must remain byte-identical.
No normalization, filtering, source/evidence, budget or deadline change.
The intended public Linux-fixture CLI red is green; all 13 budget/diagnostic
cases pass, including Linux over-limit/startup-allowance rejection and malformed
digest values. Both saved macOS reports passed at that fixture-only checkpoint.

Run `38714285780` at `67584ea` completes all six identical native Linux full
exports but genuinely fails the unchanged cap: direct `35.220242391` seconds,
guarded `38.939535589` seconds, `+10.560101%`. All 18 replay/mutation cells and
fast gates pass; startup does not run. Rust and four-language CodeQL pass.
No unchanged rerun, exception or default cutover follows.

An active Rust sample, not the first idle-handle sample, identifies stdout
write/flush cost. Parent full-journal reconciliation takes only `0.151` profiled
seconds locally. Combine each complete validated reply and original prompt
through a once-cloned raw stdout handle with checked write/flush/close.
The native-stream closed-consumer regression is green before and after this
behavior-preserving refactor. The stdout-only source passes full export
(`+6.4369%`) but genuinely fails startup (`+52.560041` ms).
An isolated exact-digest startup profile records `13` ms in one parent
final-evidence sleep. Poll every `1` ms instead of `10` ms while retaining the
`5`-second grace and complete evidence audit; the resulting local budgets are
the current passing medians above. All three startup samples are retained,
including the first guarded `0.356682459`-second sample.
The final fast gate passes 19 native, 137 model and 50 lifecycle cases,
43 projections and all 67 audits. Earlier-source reports are historical,
not reusable current-source acceptance. Fresh native performance acceptance
and conditional default cutover remain pending.
Full-proof/memory overhead remains unmeasured.
The Python default and independent native FVP/full-context obligations are
unchanged.

Native follow-up `38719650091` at `2b642e2` passes all 18 replay/mutation cells,
fast gates and the full-export budget: direct `37.767067723` seconds, guarded
`40.976766595` seconds, `+8.498671%`, all six exports identical.
Startup then rejects its direct baseline before any guarded startup sample:
observed `59548c48458d4bdf8e7fee57ba0257642f0a21bfd94c2004a4fb990781659fae`,
where only the macOS startup digest was retained. Pin both fixed startup
outputs as already done for full export; no runtime-learned digest,
normalization, filtering, numeric budget or deadline change. The intended
Linux startup report CLI red is green; 14 cases pass, including above-`50` ms
rejection for either digest. Both current macOS reports and the genuine native
full-export report still pass; native guard source/binary identities do not change.
Fresh native startup acceptance remains required before default cutover.

Companion Rust `38719650123` passes all 11 jobs. CodeQL `38719650130` fails
the existing Apple isolation preflight on `hdiutil` scratch detach
(`Resource busy`), after its file/process/CPU limits pass. This is the previously
documented teardown failure, not a native guard finding; no unrelated repair,
manual rerun or external-volume cleanup is performed.

2026-10-15 (native staging accepted; conditional default cutover):
run `38721189200` at `71168a1` passes all 19 cells, including all 18 callers,
fast gates and both actual three-pair budgets. Native full export is
`32.023234268`/`35.116483184` seconds (`+9.659389%`); startup is
`0.103666940`/`0.119538055` seconds (`+15.871115` ms, `+15.3097%`).
All six exports per workload are identical and match the fixed Linux inventory.
Both saved reports independently pass before the next source change.
Rust `38721189142` and four-language CodeQL `38721189358` also pass,
including the Apple preflight.

Those results meet the owner's explicit condition for central default cutover.
The public guarded-command test first fails because it observes
`legacy-selected` instead of the compiled executable, then passes after the
shared resolver changes. The only default is now `cairn-maude-proxy` from
`CARGO_TARGET_DIR/release`, or root `target/native-proxy/release` when unset.
An empty Cargo target and invalid/missing/non-executable/stale binaries reject.
Every version requires current source identity; no automatic build or fallback.
The temporary route and obsolete Python validator/evidence/parser are deleted;
the shared module inventory stays. All nine private parser-test groups are
covered by native CLI cases, with exact standalone framing and leading-blank
unsorted-Pub cases explicitly retained. Malformed journal fixtures now carry
valid identity where needed and assert the intended error reason.

The current default fast gate, without the temporary selector, passes
19 native/131 model/50 lifecycle cases, 43 projections and 67 audits.
Current-source local three-pair full export is `24.324896333`/`25.820824167`
seconds (`+6.149781%`); startup is `0.112295750`/`0.154256167` seconds
(`+41.960417` ms, `+37.365988%`). Both saved reports independently pass.
Source ID is `96295e1ecba13e26eac68929ff5dbff673651f5e0eb61a8fe16ae847f2ccf0a8`;
macOS binary SHA-256 is
`aa8b30c421366c5f77bcce80aff804aad1ccd7708f2e2d6d68d030cb883a3838`.
Final-source hosted acceptance remains pending. No merge, SDK/profile
activation, protocol/wire/API/primitive or constant-time claim change.

2026-10-15 (published default cutover; retained native derivation timeout):
`2fa6d16` publishes the central cutover after both mandatory hooks and a
full-file Gitleaks scan (30 current/deleted files, 468644 bytes, verified hashes).
Native run `38724991914` passes the lifecycle cell and 17/18 callers, including
both actual three-pair budgets: full export `44.715196836`/`48.455600938`
seconds (`+8.364951%`), startup `0.124041834`/`0.149827204` seconds
(`+25.785370` ms, `+20.787640%`). All six exports per workload are fixed and
identical; both saved reports independently pass. Source identity is unchanged;
Linux binary SHA-256 is
`af8d464b6aaebf770181e08436e16156eff948cfe57804a2aabc1750ecb74b28`.

`replay-initial_ck_secret`, job `116388509084`, fails during its strict
assembled export: Tamarin reports `Derivation checks timed out` at the
unchanged `60`-second cap; `--quit-on-warning` correctly rejects before the
selected proof. Version/install checks pass. The log names no individual
timed-out rule. The exact local command
`python3 docs/spec/models/replay.py --disclosure-sources --target initial_ck_secret --timeout 180`
passes its 11-step claim and five origin
helpers; no native red-capable local reproduction or root cause is established.
This is not a fix or all-green native acceptance. No larger budget, warning
relaxation, filtering, manual rerun or unrelated infrastructure repair.
Rust `38724991821` and four-language CodeQL `38724992020` pass.
All current-head authoritative gates remain required;
PR #9 records subsequent documentation-only publication checks.

2026-10-15 (native proper-sort relation transfer, local gates complete):
the preceding default head `7432d7d` completed native lifecycle `38728305203`
(all 19 cells), Rust `38728305133` and four-language CodeQL `38728305302`.
That accepts the guard promotion, not the new proof increment below.

[`QuerySorted.lean`](../../../docs/spec/models/equations/QuerySorted.lean)
independently models the native six-rule root patterns with proper-`Msg`
guards and AC-equivalent repeated keys, under every raw context. Actual Maude
controls retain a blocked ill-kind discarded component, a proper Fresh
projection, a permitted inner rewrite in an error-kind context and AC-key
decryption. The raw kind/shadow relation is not relabeled as native matching.

Typed matching lifts to the guarded relation and guarded steps decode through
raw quotient rewriting. The kernel transfers termination, one-step B-coherence,
confluence/normal-form uniqueness modulo AC, normality invariance and the
template-only normalization bound on proper-message inputs. Controlled-kind
framing closure and decoded-kind termination also hold, not controlled-kind
convergence or bounded normalizing paths. Complete sorted unification,
narrowing/FVP, universal importer correspondence and full assembled acceptance
remain open.

The existing CLI initially accepted missing new matching/convergence audits;
both intended reds are green after making all 14 new reports mandatory.
A complete-transcript positive control and kernel cases cover all six rules,
bad discarded operands/keys, Node/list rejection, AC keys, a nonlinear key-copy
peak and the template bound. Fresh pinned `scripts/check.sh` passes
19 native/134 model/50 lifecycle tests, 43 projections and 81 audits
(22 axiom-free). No equation, attacker, claim, transition, restriction,
warning, proof deadline, guard source-ID input, runtime or budget changes.
The owner selected `publish-proof-checkpoints`, separately authorizing proof-only
commits, normal pushes, PR-description updates and necessary fixes in PR #9.
The [PR checks](https://github.com/trancee/cairn/pull/9/checks) record current-head
hosted acceptance. No new benchmark, manual dispatch, merge, profile activation
or implementation approval is claimed.

2026-10-15 (guarded native query normalizing bound, local gates complete):
[`QuerySortedBoundedness.lean`](../../../docs/spec/models/equations/QuerySortedBoundedness.lean)
proves bounded normalizing-path existence directly for every frozen-index native
query template and normalized assignment, using proper-sort guarded matching
rather than raw shadow rewriting. Source-only bounds include natural-addition
and tuple/Node contexts, not assigned-term size, without a compatible typed
shadow. Bottom-up normalization leaves at most one root step. The broader raw
AST theorem does not widen the stream grammar, establish arbitrary substitution/
image closure, prove controlled-kind confluence, or close sorted unification/
narrowing/FVP/importer and full assembled obligations.

The existing CLI initially accepts a complete 81-audit transcript without the
three new reports (`0 != 1`); the rejecting green and complete-transcript
positive control pass. Kernel cases cover blocked-root/allowed-inner
normalization, arbitrary normal replacements, source-only bounds, free framing,
nonlinear keys and `kdf`. Fresh pinned `scripts/check.sh` passes
19 native/135 model/50 lifecycle cases, 43 projections and all 84 audits,
24 axiom-free. Existing Python temporary-directory ResourceWarnings remain;
no warning-free claim. No equation, attacker, claim, transition, restriction,
warning policy, deadline, native guard source-ID input or budget changes.
The existing `publish-proof-checkpoints` approval covers publication in PR #9;
current-head hosted acceptance remains required. No manual dispatch, merge,
SDK/ratchet implementation or profile activation is authorized.

2026-10-15 (guarded convergence across the frozen-index native AST):
Exact guarded root/step/path decoding to typed matching joins primitive
overlaps without assuming their enclosing raw contexts are proper. Structural
induction handles every same-child/disjoint-context peak, and a strictly
decreasing context count proves global matching termination/confluence.
Bidirectional AC transport covers natural reassociation/permutation and every
message/framing congruence. The distinct guarded quotient relation then has
count-preserving matching realizations, termination, AC-invariant normality,
matching/quotient normality equivalence, confluence and normal-form uniqueness
modulo AC. This directly covers controlled-kind/free framing, not by
transferring unguarded shadow confluence.

Four successive complete-old-transcript CLI reds (`0 != 1`) become rejecting
greens; all 18 new reports are mandatory, for 102 audits, 24 axiom-free.
Kernel cases retain distinct AC-equivalent error-kind normal forms, exact
matching decoding, framed nonlinear key-copy peaks, `kdf` and explicitly marked
raw-AST cases outside the native grammar. No arbitrary properness-invariance
or wider grammar claim. Fresh pinned `scripts/check.sh` passes 19 native,
136 model and 50 lifecycle cases, 43 projections and all 102 audits.
Seven changed-document local-link sets, both Python ASTs and whitespace pass.
Existing Python temporary-directory ResourceWarnings remain; no warning-free
claim. Sorted narrowing/unification/FVP, the full imported
NAT/kind-variable carrier, universal importer correspondence and full assembled
63-declaration acceptance remain open. Equations, attacker, claims, rules,
restrictions, strict options/deadlines, native source identity and budgets
are unchanged. Publication remains covered by `publish-proof-checkpoints`;
current-head hosted acceptance is required, with no manual dispatch, merge,
SDK implementation or profile activation.

2026-10-15 (sort-respecting guarded substitution closure):
[`QuerySortedSubstitution.lean`](../../../docs/spec/models/equations/QuerySortedSubstitution.lean)
models the five variable-sort value disciplines and proves a complete
representation by the existing typed substitution. Proper-message guards,
guarded rewrites and counted matching/quotient paths survive every such
assignment. [`QueryKindSubstitution.lean`](../../../docs/spec/models/equations/QueryKindSubstitution.lean)
proves kind abstraction preserves proper values and produces a sorted abstract
assignment. Its typed representation derives the previously assumed compatible
shadow, giving controlled-kind/free framing substitution closure without an
extra premise. This is mathematical assignment closure, not native unifier,
validator/importer or FVP acceptance.

The 38-case equation fixture baseline is green before/after extracting its
independent transcript inventory, keeping the shared process fixture at
405 lines and below the hard limit. Two missing-audit CLI reds (`0 != 1`)
become rejecting greens; the complete-transcript positive control passes.
The checker now requires 114 audits, 24 axiom-free. Kernel cases retain all-sort
rejection, frozen same-index rigid/variable atoms, separate Fresh/natural
shadows, simultaneous substitution, framed kind closure, blocked ill-kind
roots, counted AC-key paths and new redex creation. No normality-preservation
or rewrite-reflection claim. Native sorted unification/narrowing/FVP,
algorithm/importer/namespace correspondence and exact full assembled acceptance
remain open. No native source-ID input, grammar, equation, attacker, claim,
rule, restriction, option, deadline or budget changes. Existing publication
approval applies; no manual dispatch, merge or SDK/profile activation.

2026-10-15 (sorted AC-unifier composition and solution correspondence):
[`QueryComposition.lean`](../../../docs/spec/models/equations/QueryComposition.lean)
proves identity, ordered simultaneous composition, associativity, all-sort
value closure and pointwise AC congruence through raw/framing contexts.
[`QueryUnification.lean`](../../../docs/spec/models/equations/QueryUnification.lean)
models sorted AC solutions separately from equality modulo ordinary equations.
Solutions compose; message/natural encoding preserves/reflects them, with
typed representations for all sorted solutions on encoded inputs. Kind
solutions correspond only through derived compatible abstract assignments.

The kernel proves a Fresh/natural original pair has no sorted AC solution,
while unrestricted natural shadows admit an incompatible `one` assignment.
Actual pinned Maude confirms original cross-sort/mixed-kind failures and a
same-sort success; the separate `flip(roleA)`/`roleB` control has no plain AC
unifier. No native solution filtering, broader grammar or runtime repair.
Three missing-audit CLI reds become rejecting greens; the complete transcript
passes. All 127 audits, 25 axiom-free, and new kernel cases pass. The independent
source/native process fixtures remain 409/384 lines, transcript inventory 111,
under the hard limit with the shared-fixture recommendation rationale in ADR 0010.
Finite complete enumeration, most-generality, occurs-check/fresh namespace,
narrowing/FVP, native algorithm/importer and exact full assembled acceptance
remain open. Source-ID inputs, equations, attacker/claims/rules/restrictions,
options, deadlines, jobs and budgets are unchanged. Existing proof-only
publication approval applies; no dispatch, merge or SDK/profile activation.

2026-10-15 (published AC-unifier checkpoint and independent CI blocker):
`bfff37f` passes all 19 lifecycle cells in
[run `38770078384`](https://github.com/trancee/cairn/actions/runs/38770078384)
and all 11 Rust jobs in `38770078237`. Actual lifecycle job `116543272613`
contains 127 audits/25 axiom-free, 19 native/137 model/50 lifecycle cases
and 43 projections. Both extracted native reports independently pass:
full-export `38.223192488`/`41.712657755` seconds (`+9.129183%`);
startup `0.122968961`/`0.138492166` seconds (`+15.523205` ms).
Source/Linux executable identities and original limits are unchanged.
CodeQL `38770078501` fails ordinary Apple scratch teardown with `Resource busy`
after Kotlin queries, before integrity/result delivery; the proof checkpoint
is not fully accepted. The separately reproduced mandatory-`f` holder-record
diagnostic defect and owner-approved narrow fix are recorded in
[issue 45](45-provision-isolated-build-runner.md).
Actual busy-eject root cause, updated-source hosted acceptance and the
independent unifier-generation/narrowing/FVP/importer/full-63 obligations
remain open. No manual rerun, dispatch, force-detach, retry, budget change,
merge or SDK/profile activation is implied.

2026-10-16 (scoped AC factorization and conditional completeness):
[`QueryInstances.lean`](../../../docs/spec/models/equations/QueryInstances.lean)
extracts source-query variables and proves scoped AC substitution congruence,
sorted postfactor preorder laws and solution closure. Comparisons exclude
unrelated bindings, not just rigid indices.
[`QueryTypedInstances.lean`](../../../docs/spec/models/equations/QueryTypedInstances.lean)
independently defines typed composition and equality/AC for all five sorts.
Encoding commutes with composition and preserves/reflects scoped factorization.
[`QueryCompleteness.lean`](../../../docs/spec/models/equations/QueryCompleteness.lean)
transports sound completeness of given finite families and candidate
most-generality on proper message/natural inputs in both directions.
Singleton completeness is equivalent to its member's most-generality; no
general complete finite generator or unrestricted kind-family transfer follows.

Three public-CLI missing-report reds (`0 != 1`) become rejecting greens.
All 141 required kernel audits and the complete transcript pass, with 25
axiom-free and no `sorryAx`. The 38-case equation suite remains green.
Kernel controls prove a variable-pair complete singleton, reject a sound ground
singleton and an empty family, and show that adding an unrelated message
variable would wrongly reject the scoped MGU. They also retain all-sort support/
composition, frozen labels, natural AC, sorted-factor rejection and cyclic/
no-zero finite-AST solution controls. These do not verify a native occurs check.
Fresh `scripts/check.sh` passes 19 native/137 model/50 lifecycle cases,
source projection and all 141 theorem audits at unchanged limits. All eight
changed-document local-link checks, three Python ASTs, source line limits
and whitespace checks pass. Existing warnings are not suppressed.

Native finite-support/generator/namespace/importer correctness, narrowing/FVP,
kind-family transfer and exact full 63-declaration acceptance remain open.
The owner's intervening all-Actions request updates all three CodeQL Action
references to verified stable `v4.39.0`; the other five upstream actions were
already current. [ADR 0015](../../../docs/adr/0015-build-backed-kotlin-codeql.md#action-release-refresh-2026-10-16)
records provenance/compatibility. All native source-ID inputs, equations,
attacker/claims/rules/restrictions, options, deadlines, jobs and budgets remain
unchanged. Existing checkpoint publication approval applies; current-head
hosted acceptance remains separate, without dispatch, merge or SDK/profile
activation.
