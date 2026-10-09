# Formal models

Symbolic models of `cairn-r1` ([spec](../cairn-r1.md)). Under the strict formal-model gate (ticket *Implementation slicing*), a slice that implements a modelled flow starts only after its model verifies.

| Model | Spec | Status |
|---|---|---|
| [`resume.spthy`](resume.spthy) | §6 Resume | All four profiles verified with public `pairID` |
| [`ratchet.spthy`](ratchet.spthy) | §9 | Last completed replay: 55/59; current strict replay timed out at 360 s; full gate closed |
| [`sas.spthy`](sas.spthy) | §5 Pairing (QR, SAS, TOFU, Verify) | Verified (draft 0.4) |

## Evidence index

Run commands from the repository root; setup and limits are in [`ENVIRONMENT.md`](ENVIRONMENT.md).

| Claim | Evidence | Gate |
|---|---|---|
| Lifecycle invariants hold for the projected 43 rules | [`lifecycle/`](lifecycle/README.md) | `python3 docs/spec/models/lifecycle/check.py --lean <lean>` |
| Lost-data witness and KEM origin replay exactly against the source | `replay.py`, [`ratchet-source-evidence.md`](ratchet-source-evidence.md) | `python3 docs/spec/models/replay.py [--disclosure-sources [--target <certificate>]]` |
| Replay tooling selects and compares certificates correctly | `test_replay.py` | `python3 -m unittest discover -s docs/spec/models -p 'test_replay.py'` |
| Certificates are finished and every include file is wired in | `check_certificates.py`, `test_check_certificates.py` | `python3 docs/spec/models/check_certificates.py` |
| Branch driver parses methods and picks the closing priority | `test_branch.py` | `python3 -m unittest discover -s docs/spec/models -p 'test_branch.py'` |
| Custom equations terminate and are confluent | [`ratchet-equation-evidence.md`](ratchet-equation-evidence.md) | Independent review open |
| All fast gates | `scripts/check.sh` | pre-commit hook and CI |

## Tooling

- Tamarin prover 1.12.0 with Maude 3.5.1, from the `tamarin-prover/tap` Homebrew tap: `brew install tamarin-prover/tap/tamarin-prover`.
- On macOS, Homebrew may first require `brew trust --formula` for `tamarin-prover/tap/tamarin-prover`, `tamarin-prover/tap/maude` and `tamarin-prover/tap/libbuddy`.

## Resume (`resume.spthy`)

Run from this directory:

| Command | Profile | Expected | Time (Apple silicon) |
|---|---|---|---|
| `tamarin-prover --prove resume.spthy` | Spec §6, public `pairID` | 16 lemmas verified | ≈ 9 s |
| `tamarin-prover --prove -D=DESYNC resume.spthy` | Plus R's two-candidate desync recovery | 17 lemmas verified | ≈ 21 s |
| `tamarin-prover --prove -D=KCI resume.spthy` | KCI profile, public `pairID` | 19 lemmas verified | ≈ 26 s |
| `tamarin-prover --prove -D=KCI -D=DESYNC resume.spthy` | KCI plus desync recovery | 20 lemmas verified | ≈ 36 s |
| `tamarin-prover --prove=reflection_resistance --stop-on-trace=BFS -D=UNBOUND resume.spthy` | Draft 0.2 (no role binding) | Falsified: reflection attack (OI-16) | < 30 s |
| `tamarin-prover --prove=ciphertext_substitution -D=KCI -D=KCI_UNBOUND resume.spthy` | KCI without `ct_I` in `th_s` | Attack witness verified: different committed chain keys without compromise (OI-18) | < 30 s |

`--stop-on-trace=BFS` is required for `UNBOUND`. Depth-first search does not find the attack in reasonable time.

The current model discloses `pairID` conservatively: confidentiality
must not depend on hiding a KDF/MAC context. Earlier results from the
hidden-`pairID` model are superseded by the full-file results above.
All reused helper lemmas verify in those runs; none is assumed unproved.

Proof-only actions record fresh DH exponents, encapsulated secrets,
chain-key predecessors, session-key inputs and I's chain advancement.
Helpers split provenance from secrecy. `hide_lemma` limits reuse where
irrelevant helpers expand old state histories; it removes proof hints,
not traces or attacker capabilities. Initiator secrecy reuses proved
agreement and passive-session secrecy. The recovery witness pins
`CK_n -> CK_{n+1} -> CK_{n+2}`, with R's timeout between the two commits
and R confirming the final key.

Search experiments have a 30 s per-lemma cap. The complete 20-lemma
KCI+DESYNC run used a 60 s aggregate cap and finished in 36 s.
The OI-18 attack witness explicitly hides reusable helpers, including
agreement, so no false theorem from the vulnerable profile suppresses
the counterexample.

### Properties

Numbers refer to the lemma list in [formal-tooling research §8.1](../../research/2026-10-05-formal-model-tooling.md).

| # | Property | Lemma | Result |
|---|---|---|---|
| 1 | Agreement on pair, ephemerals and session keys | `I_agreement`, `R_agreement`, `R_injective` | Verified |
| 2 | Session-key secrecy | `I_key_secrecy`, `R_key_secrecy` | Verified |
| 3 | Single-use `CK_n` | Restrictions `current` and `retire_once` | Assumed; required by spec §6 (OI-17) |
| 4 | Forward secrecy (state reveal after the session) | `I_key_secrecy`, `R_key_secrecy` | Verified |
| 5 | Healing against a passive attacker after `CK_n` reveal | `pcs_passive_session` | Verified |
| 6 | Replayed S1 yields no session key | `R_key_secrecy` | Verified |
| 7 | Reflection resistance | `reflection_resistance`, `I_agreement` | Verified; **falsified in draft 0.2** (OI-16) |
| 8 | A leaked S2 confirmation key alone reveals no session key | `I_key_secrecy`, `R_key_secrecy` (`RevAuthR`) | Verified |
| 9 | Desync recovery after a lost first DATA frame | `desync_recovery` (`-D=DESYNC`) | Verified |
| 10 | No X25519 for an S1 that no honest I produced | `dh_only_after_valid_mac` | Verified |
| KCI | Agreement holds even after `CK_n` and the victim's own static key leak; only a reveal of the peer's static key before the session breaks it | `kci_I_agreement`, `kci_R_agreement` (`-D=KCI`) | Verified in both KCI profiles |

`ck_secret` and `cur_secret` are helper lemmas: a chain key becomes known only after that pair's state was revealed.

For property 8, `I_key_secrecy` excludes one combination: a reveal of the confirmation key before the session **and** a reveal of the chain key at any time. The attacker could then forge S2 with its own ephemeral and later read R's still-current `CK_n`. This is equivalent to a state reveal before the session.

### Abstractions and limits

- Pairing is an authentic setup that yields a shared `CK_0`; the SAS model covers it.
- HKDF and the labelled MAC are free functions. ML-KEM is an ideal KEM: `kdec(kem(ss, pk(sk)), sk) = ss`; any other ciphertext decapsulates to an unrelated value (implicit rejection). Truncation and `ctx(n)` are not modelled, because every chain key is fresh.
- Contact state is a persistent fact made linear by restrictions. Abort and timeout are attempts that never complete.
- DATA is reduced to I's first frame (R's key confirmation).
- Not covered:
  - the PQ mix (`pq`), which belongs to the ratchet model;
  - ephemeral-secret reveal;
  - pseudonym unlinkability, which is an observational-equivalence property.
- With `DESYNC`, R keeps the unused candidate when the other one advances. This over-approximation gives the attacker more power than the spec does.

## PQ ratchet (`ratchet.spthy`)

This is a draft, not an implementation-gate proof. The expanded model
includes symbolic monotonic epochs, role-bound generator positions,
two contiguous symbolic pieces per EK/CT, authenticated half/full progress,
mandatory MIX and CK-candidate-bound recovery metadata (OI-21-24).
Stored prefixes, progress and DONE can be resent under a later session;
guards prevent receipts regressing after completion and new sends after
acknowledgement (OI-25/26). Empty-prefix progress is a stuttering no-op
in this abstraction; concrete offsets remain outside it.

Earlier targeted results applied to a superseded, smaller model and are
not evidence for the expanded model. The default-model honest witness verifies, including the initial
Resume, complete authenticated EK/CT exchange and a subsequent mixed
Resume that advances the epoch. Fresh-secret and KDF/CK provenance
helpers, chain/session secrecy and generator parity have replayed proofs.
EK/CT authentication and authenticated-progress durability now replay.
Complete epoch agreement and fresh-epoch execution after compromise now
replay. The lost-data recovery witness now has a proof. An earlier reduced
lifecycle diagnosis that removed `LockStage` from `Release_Resume` was
incorrect: that projection omitted the real completion-stage increment, where
`FinishPermit` advances from the `BusySlot` ordinal. Consequently, the release
marker is the next distinct ordinal, not a duplicate. With the marker removed,
the faithful reduced lifecycle has a seven-step counterexample to
`lock_stage_order`; the marker has been restored. The latest strict assembled
replay timed out at 360 s, and targeted searches for the remaining obligations
also timed out; none provides proof or counterexample evidence.

### Compositional lifecycle gate

The three serialization claims now have a separate compositional verification
path under [ADR 0010](../../adr/0010-compositional-lifecycle-verification.md).
Lean 4.34.1 kernel-checks unbounded lifecycle induction, token-rewrite
simulation, event recording and arbitrary-key interleavings. A fail-closed
Python checker projects all 43 current default rules and generates Lean
token/action schema certificates; it also pins the exact three source
formulas and reviewed equations. Initialization certificates cover both
roles and their markers; global proofs include fresh-history preservation
and unrelated-event stuttering. Malformed/misplaced facts and duplicate
declarations fail the projection; every required theorem is axiom-audited.
All 50 regressions and the clean Lean build pass.
Run and inspect the trust boundary in
[`lifecycle/README.md`](lifecycle/README.md).
The [lifecycle workflow](../../../.github/workflows/lifecycle.yml) configures
a checksum-pinned, clean Linux matrix. All 11 jobs passed on final PR #2
head `ce54305` in
[run 37972978282](https://github.com/trancee/cairn/actions/runs/37972978282).
Required-check enforcement is not configured; successful execution does not
establish full assembled-theory completion.
The [local Linux execution record](lifecycle/README.md#observed-evidence)
now includes a `gh act`/Colima/Rosetta run: lifecycle checks and replay
regressions passed, but the default witness hit guest OOM and then a
300-second timeout under bounded runtime settings. The full local
workflow is not green; the disclosure-profile invocation was not reached.

This is compositional evidence, not three new native Tamarin proofs. Source
correspondence trusts Tamarin's canonical export and the tested Python
extractor; that extractor is not formally verified. The Tamarin search status
and historical replay counts below remain unchanged. Other ratchet gates,
including lost-data replay and source/equation evidence, are not closed by
this lifecycle proof.

### Retained proof checkpoints

The current default model retains Tamarin-generated proof skeletons in
[`ratchet-executable-proof.inc`](ratchet-executable-proof.inc),
[`ratchet-fresh-execution-proof.inc`](ratchet-fresh-execution-proof.inc),
[`ratchet-lost-data-recovery-proof.inc`](ratchet-lost-data-recovery-proof.inc),
[`ratchet-lifecycle.inc`](ratchet-lifecycle.inc),
[`ratchet-state-guards.inc`](ratchet-state-guards.inc),
[`ratchet-origins.inc`](ratchet-origins.inc) and
[`ratchet-ck-origins.inc`](ratchet-ck-origins.inc),
[`ratchet-secrecy.inc`](ratchet-secrecy.inc),
[`ratchet-epoch-security.inc`](ratchet-epoch-security.inc),
[`ratchet-progress.inc`](ratchet-progress.inc),
[`ratchet-key-inputs.inc`](ratchet-key-inputs.inc),
[`ratchet-transfer-origins.inc`](ratchet-transfer-origins.inc),
[`ratchet-transfer.inc`](ratchet-transfer.inc),
[`ratchet-acknowledgement.inc`](ratchet-acknowledgement.inc),
[`ratchet-durability.inc`](ratchet-durability.inc),
[`ratchet-serialization.inc`](ratchet-serialization.inc) and
[`ratchet-positions.inc`](ratchet-positions.inc) and
[`ratchet-agreement.inc`](ratchet-agreement.inc). These generated files
contain the corresponding lemma declarations as well as their proofs;
do not hand-edit their proof trees. The existential witness retains only
its solved branch; no `sorry` occurs in the retained artifacts.

The last completed unrestricted repository replay verified 55 of 59 default
obligations in 203.07 s processing time (207.94 s wrapper elapsed) with
Tamarin 1.12.0 and Maude 3.5.1. Its source included the release `LockStage`
marker, as does the restored current source. A fresh full strict replay did not
finish within a 360 s cap. This includes `executable`
(609 steps), lifecycle/source helpers, erasure/epoch guards, KEM/KDF/CK
provenance, chain/session secrecy, conditional epoch security,
encrypted-progress provenance and generator-position properties.
`declared_keys_have_inputs` (7 steps) checks that each directional key pair
uses the same extract inputs/context as its declared chain key, with
opposite `skI`/`skR` labels. It is deliberately not a reusable search hint.
`acknowledgement_input` (8 steps) ties a receipt to its incoming ciphertext;
`acknowledgement_session` (5 steps) supplies its same-event session and prior
ciphertext knowledge for reuse. Both were proved with unrelated reusable
helpers removed and source expansion disabled, then replayed with default
precomputation. These establish input/session provenance.
`progress_is_durable` now verifies in six steps by composing ciphertext
origin, incoming-key secrecy, directional ownership and storage provenance.
The peer's symbolic storage event precedes an accepted receipt, unless
the pair's CK was revealed earlier; this does not prove a real transaction.
EK/CT authentication now verifies in six steps each. The new five-step
output-origin helpers distinguish original generation/encapsulation from
retransmission. Their disjunctive form avoids eager recursive event
expansion while preserving the same claim and admissible traces.
`epoch_agreement` verifies in 132 steps using EK/CT authentication and
generator uniqueness. Its generated header hides unrelated reusable
hints; the protocol rules, restrictions and target formula are unchanged.
The retained include layout, not just an isolated guided export, replayed.
`fresh_epoch_after_compromise` verifies in 617 steps under the default
rules, without execution-profile restrictions. Its witness strengthens
the earlier formula by also pinning both Resume lifecycles and matching
peer/session events. It reveals CK_0 before the initial initiator commit,
then completes an honest fresh epoch and a mixed Resume without exposing
DK, SS or another CK. This establishes a possible recovery execution,
not inevitable healing or availability against continued interception.
`ratchet_key_reveal_owner` proves that the pair identifier bound into a
derived CK agrees with the pair recorded by its reveal event.

`initiator_candidate_recovery` now verifies in 507 steps in the unchanged
default rules and restrictions. Its existential witness pins three
successive Resumes: an initial classical Resume, an epoch-1 KEM exchange and
MIX, then a timed-out responder's candidate commitment by role B followed by
generation of epoch 2. The witness also rules out extra Resume starts,
accepts or commits, extra role-B MIX/confirmation events before epoch
generation, and CK/DK/SS reveals. These guards specify a particular honest
trace; they are part of the existential witness, not protocol restrictions
or an all-traces security guarantee. The solved-only owner
[`ratchet-candidate-recovery-proof.inc`](ratchet-candidate-recovery-proof.inc)
was replayed both in isolation and in the full default theory. No rule,
restriction, or attacker capability changed.

`lost_data_recovery` now has a Tamarin-verified 826-step existential witness.
Its source theory has the same signature and equations, all 43 default rules,
and all 13 default restrictions as the current model. The witness pins the
Resume lifecycles, candidate state, timeout and final peer confirmation.
Strict replay in the assembled repository layout was killed by the system
with exit 137 after about 48 minutes; this is inconclusive, not a
counterexample. The standalone proof uses the same transition system, while
replaying it in the full include layout remains resource-blocked. The witness
establishes a possible recovery trace, not guaranteed recovery under active
interception.

### Exact-source witness replay

The repository-owned runner rebuilds the lost-data replay from the current
assembled model, rather than relying on a saved session theory:

```sh
python3 -m unittest discover -s docs/spec/models -p 'test_replay.py'
python3 docs/spec/models/replay.py --timeout 180
python3 docs/spec/models/replay.py --disclosure-sources --timeout 180
for target in kem_ciphertext_origin fresh_dk_origin encrypted_origin extract_origin \
    ratchet_key_origin session_key_origin initial_ck_secret fresh_ss_origin; do
  python3 docs/spec/models/replay.py --disclosure-sources --target "$target" --timeout 180
done
```

Prerequisites are Python 3.10+, Tamarin 1.12.0 and Maude 3.5.1.
The runner uses Tamarin's native `--output-module=msr` export with strict
wellformedness checks. `--parse-only` is not used to generate the replay
input: its current printer also emits typed source annotations that do not
reparse as MSR syntax.

Only the selected target and **all** `[sources]` lemmas are retained;
the default's sole source lemma is `dk_reveal_owner`.
`--disclosure-sources` explicitly enables the proof-only
`DISCLOSURE_SOURCES` profile, adding two verified source lemmas.
Its transition-system/signature/restriction prefix is identical to the
default; only the lemma context changes. The prefix containing
the signature, equations, tactics, all 43 default rules and all 13 default
restrictions is copied unchanged. Target/source formulas, attributes and
certificates are also copied unchanged. A second native export checks exact
non-comment correspondence before the proof run. The exporter and tested
Python selector/comparator remain trusted, not formally verified.

The proof command is `tamarin-prover GENERATED_THEORY --quit-on-warning
--derivcheck-timeout=60`, deliberately without `--prove`. It checks the
retained certificates rather than starting automation on unfinished sibling
branches of an existential proof. Success requires a unique `verified`
result for the witness and every retained source lemma; exit status alone
is insufficient. Missing/incomplete results fail. Temporary theories are
cleaned automatically; timeout terminates the command's process group.
`--timeout` defaults to 300 seconds for the proof invocation; export commands
each have a separate 120-second limit.

Observed on macOS/Apple silicon: the strict exact-source replay verifies
`lost_data_recovery` in 826 steps and `dk_reveal_owner` in 9 steps
(105.69 seconds processing time). All 37 selector/correspondence/result/
command regressions pass. The native assembled-export SHA-256 is
`d5678674a4dfdff8fb5997fc8bc0202b7818f0cdcf9ac1f5aa4089d40d89e8e0`;
the native replay-export SHA-256 is
`8efffcd0f03af887cfb11e8f9c3b2c69ed4e5b1b4609e610d5a78a9c6e662caa`.
These differ from the lifecycle printer digest because the export formats
differ; they are regenerated, not cached certificates.

Re-run before the rename to Cairn (theory `PqcbleRatchet`; the digests below are of that export; certificate-only, native export,
`tamarin-prover EXPORT --quit-on-warning --derivcheck-timeout=60 +RTS -M5G`,
8 GiB host): the full assembled context exhausted the 5 GiB heap in both
profiles, after 481 s for the default and 247 s for `DISCLOSURE_SOURCES`.
The export SHA-256 values were:
`b41046cd3ae828ae59d6fa98f61652207005171fd7a84e50af7a1e8ef919f9b0` (default)
and `2421f43c5907ff5a2e96e4dea404a643b472ed25ab38922bf6bc11b48f49bfe1`
(profile). No lemma result was printed, so this is an inconclusive resource
failure, not a counterexample and not a new assembled count.

The same minimal context with `--prove` timed out at 240 seconds.
Certificate-only replay of the full assembled context also timed out at
300 seconds. Thus this closes reproducible exact-transition-system witness
replay, **not** full-context completion or a new 56/59 assembled result.
The [workflow](../../../.github/workflows/lifecycle.yml) now runs these
regressions and the witness runner alongside the lifecycle gate.
The lifecycle gate, two witnesses and eight refined safety targets run as
eleven independent matrix jobs, each with a 15-minute limit. Fail-fast is
disabled so a failed target does not cancel the remaining checks.
The first hosted run passed the lifecycle gate, both witnesses, KEM origin
and fresh-DK origin before the former sequential job exceeded its shared
15-minute limit. Completion of the new matrix remains unverified.

### Remaining lifecycle searches

An isolated restored-source search for `lock_stage_order` with
`--heuristic=I` timed out at 300 s after generating 18,346 constraints. This is
inconclusive. Restored-source searches for `initial_resume_serialized` and
`resume_serialized` also timed out at 300 s each. A faithful reduced lifecycle
verifies `lock_stage_unique` (65 steps) and `lock_stage_predecessor` (14 steps);
these projections do not prove the full theory. Projection-only results and
timeouts are not assembled-theory evidence.

Further proof-search experiments did not close the gap. An
`--heuristic=O` search for `lock_stage_order` exceeded 120 s. An
`--heuristic=I --derivcheck-timeout=0` search for `resume_serialized` was
stopped at 240 s after repeatedly expanding `ResumeFinish` interval goals.
A proposed monotonic-stage helper timed out at 180 s and was discarded.
The interactive UI loaded the theory, but its overview request stalled; the
server was stopped. These experiments are inconclusive and changed no model
transitions or restrictions.
Combining `--no-reuse --heuristic=O --derivcheck-timeout=0` timed out at
120 s for each of the three target obligations.

As a proof-search experiment, `LockStage` was moved from `Release_Resume` to
each finish rule's existing `ResumeFinish` action, keeping the same stage
ordinal and leaving protocol state, restrictions, wire terms and target
formulas unchanged. With a 180 s process cap,
`tamarin-prover ratchet.spthy --prove=lock_stage_order --derivcheck-timeout=0 --quiet`
and the corresponding `--prove=lock_stage_predecessor` command both timed out.
The instrumentation change was reverted; these results are inconclusive and
do not alter the assembled-theory evidence.

Further tactic variants also remained inconclusive. Using the `lifecycle`
tactic on `lock_stage_order` timed out at 180 s after roughly 16,500
constraints. Using `initial_lock` on `initial_resume_serialized` timed out at
180 s. Using `lifecycle` on `resume_serialized` timed out at 180 s while
interval goals expanded; `--no-reuse --heuristic=I --derivcheck-timeout=0`
also timed out at 180 s for that lemma. The latter settings timed out at
180 s for `lock_stage_order` as well, after roughly 15,370 constraints.
The Tamarin UI loaded both theories, but its `/thy/trace/2/overview/help`
request stalled for 30 s; no interactive proof guidance was obtained. A
zero-open-chain/zero-saturation run aborted in `--quit-on-warning` mode on
derivation-check timeouts and is not proof evidence. No tactic annotation,
lemma formula, rule or restriction was retained from these experiments.

The 3 target obligations without native Tamarin proof evidence are
`lock_stage_order`,
`initial_resume_serialized` and `resume_serialized`.
Their compositional lifecycle evidence and trusted source boundary are
described above.
A generated header or absence of `sorry` does not establish proof
validity; the replay result is authoritative.

The initiator recovery witness's generated proof is retained only because it
replays in the unrestricted default theory. Restricted positive-trace
experiments are search aids only; any resulting certificate must replay on
the unrestricted default model.

Replay the retained proofs from this directory:

```sh
tamarin-prover ratchet.spthy --quit-on-warning --derivcheck-timeout=60
```

This command rechecks the stored proofs; it does not search the remaining
lemmas. Earlier runs with a 30-second derivation-check budget sometimes
expired before proof search. The calling process still needs a separate
wall-clock cap; the latest searches used 60 or 90 seconds in total.
The mutex premises use `no_precomp` to prevent source precomputation
expanding unrelated collision/previous-Resume histories. This annotation
changes search strategy, not protocol transitions, restrictions or
attacker capabilities.

Default precomputation still reports 43 source cases and 30 partial
deconstructions. The proved origin/source helpers are progress, not a
claim that this source-coverage gate is closed.
The [fresh source inventory](ratchet-source-evidence.md) accounts for all
43 goal groups and 179 branches: the 30 residual chains are exclusively
`Reveal_CK`/`Reveal_SS` branches across 15 attacker-knowledge shapes.
Raw and refined residual inventories agree; no source closure is claimed.
The opt-in `DISCLOSURE_SOURCES` profile reduces refined chains to 15
across 172 branches. Every remaining partial branch is `Reveal_SS`.
Its new CK/SS origin certificates replay in 12/8 steps, respectively;
the unchanged lost-data certificate checks in 802 steps under this
refined context (100.98 seconds), versus 826 under the default.
This changes replay step counts, not the saved witness or transitions.
The [refinement evidence](ratchet-source-evidence.md#opt-in-disclosure-refinement)
records its limits: all eight affected safety certificates are now migrated,
but 15 SS chains and full assembled-context verification remain unresolved.
The profile is therefore not enabled by default.
`kem_ciphertext_origin` has now been migrated: its unchanged formula
verifies in 18 steps in the profile, versus 31 in the default context.
`--target kem_ciphertext_origin` checks its certificate and all sources
without relying on ordinary reuse helpers; the default target remains
`lost_data_recovery`. Seven more are migrated (`fresh_dk_origin`,
`encrypted_origin`, `extract_origin`, `ratchet_key_origin`,
`session_key_origin`, `initial_ck_secret`, `fresh_ss_origin`); each is
checked by `--target` together with its dependency `kem_ciphertext_origin`.
The exact-prefix safety-only profile context now verifies **54 of 54**
complete certificates in 38.7 s (it was 47/54 before these migrations); the
three incomplete serialization lemmas and four existential witnesses are not
in that context. Earlier bulk regeneration timed out at 240 seconds. Neither this profile nor its selected-certificate CI
check establishes a new full-theory completion count.
The [equation argument](ratchet-equation-evidence.md) records termination,
the repeated-key confluence caveat and the subterm/ground FVP rationale
for the exact six message equations. Independent convergence
and finite-variant evidence for the custom equations is also still
required, including acceptance of their sorted natural-number combination.
The lightweight skill inspector does not expand the `.inc`
files: an entry-file scan reports `NO_LEMMAS` despite the prover loading
59 obligations. Its textual inventory is not an expanded-theory check.
None of these symbolic proofs establishes constant-time code,
computational security, concrete parsing or persistence atomicity.

Bounded experiments use `--open-chains=0 --saturation=0` to avoid source
precomputation expanding arbitrary session histories. These are search
settings, not attacker restrictions. The prefix-closed mandatory-MIX
guard removes an existential restriction from induction. Fresh DK,
fresh SS and derived-CK origin now have retained replayed proofs;
remaining searches use bounded wall-clock experiments and exact
interactive guidance. A timeout is neither verification nor a
counterexample. No ratchet implementation may start on this evidence.

The derivation check caught a modelling error: mixed Resume could recover
EK/CT only from their hashes. `IWait` now retains the concrete pending
secret and objects, matching the local state available at S1. A standalone
load with `tamarin-prover ratchet.spthy --open-chains=0 --saturation=0
--derivcheck-timeout=30` passes wellformedness. This does not prove lemmas.

The earlier `epoch_position_shape` lemma is no longer part of the current
theory. `monotonic_epochs`, `no_rollback` and `no_classical_downgrade`
now have retained default-model proofs (6/4/2 steps), alongside
`erased_is_retired` and `erased_branch_unusable` (16/4 steps).

These flags do not impose an overall proof timeout. The 30 s experiment
cap is enforced by the calling process; `--derivcheck-timeout=30` limits
only message-derivation checks.

The original weaker positional/parsing checks are now named
`generator_has_position` and `kem_decapsulation_agreement`.
`generator_parity` compares consecutive generators; `epoch_agreement`
compares both parties' complete epoch contributions, excluding CK reveal.
`no_partial_mix` requires an actual stored prefix followed by full
reception, not just a completion action.

The `CLASSIC_FALLBACK` and `NO_PREFIX_GUARD` mutations remove mandatory
mixing and permit tail acceptance without stored prefixes respectively.
Earlier helper-hidden BFS searches hit the 90 s cap for both targets.
Guided native replay now establishes sensitivity for both mutations.
`lost_data_recovery`
is a pinned existential witness, not a guarantee of recovery under continued
interception. Its assembled-layout replay limitation is recorded above.

On 2026-10-09, bounded native macOS depth-first probes also timed out at
90 seconds for both targets. Each used the assembled `ratchet.spthy`,
`--quit-on-warning --derivcheck-timeout=60 --open-chains=0 --saturation=0`,
and `--stop-on-trace=DFS`, with `--defines=CLASSIC_FALLBACK
--prove=no_classical_downgrade` or `--defines=NO_PREFIX_GUARD
--prove=no_partial_mix`. The limit covered the entire process, not just search.
An initial 30-second derivation budget failed with a derivation-check timeout;
that setup failure is not a mutation result. No replayable counterexample or
automated mutation regression was obtained from these probes.

### Native mandatory-mix mutation regression

From the repository root:

```sh
python3 docs/spec/models/mutation.py --timeout 180
```

The runner exports the default and `CLASSIC_FALLBACK` assembled theories
with Tamarin 1.12.0/Maude 3.5.1. It checks that the only transition-system
difference is removal of `mandatory_mix` and that the target formula and
attributes are identical. It retains every non-lemma declaration but only
`no_classical_downgrade`: no source, reuse or other helper lemma is available.
Native certificate replay, without `--prove` or a new search, must report:

| Profile | Required result | Local native result |
|---|---|---|
| Default: guard present | `verified` | 2 steps |
| `CLASSIC_FALLBACK`: guard absent | `falsified - found trace` | 504 steps |

The intended-red run verified the default claim but rejected the old
mutation certificate's `analysis incomplete` result. After adding the guided
attack certificate, both required outcomes passed. Timeouts, warnings,
process failures, incomplete analysis and unexpected verification are failures,
not substitutes for a counterexample. The 180-second bound applies separately
to each native command. The lifecycle workflow adds a separate
`mutation-classic-fallback` job; `REPLAY=1 scripts/check.sh` also runs it.
Hosted execution of the new mutation jobs is not yet verified.

The first hosted mutation jobs at `5b29d90` in
[run 37985431090](https://github.com/trancee/cairn/actions/runs/37985431090)
failed during the initial default export: strict derivation checks hit their
60-second timeout before either certificate replay. All 11 existing formal
jobs in that run passed. The exact Linux binaries reproduced that timeout
locally under Rosetta. Standard export settings passed; guided replay with
the same 60-second budget also timed out. A 120-second strict derivation
budget completed fallback replay in 74.24 seconds, with the same 504-step
counterexample. Default replay precomputation instead produced an incomplete
attack skeleton, not a counterexample.

The runner therefore uses standard canonical export with a 60-second
derivation budget, then retains the guided certificate context
(`--open-chains=0 --saturation=0`) with a 120-second derivation budget.
Every process still has the external 180-second cap, and `--quit-on-warning`
remains enabled. There is no retry, skipped check, changed claim or protocol
change. Linux/Rosetta evidence does not substitute for hosted native results.
Both corrected regressions passed with the exact Linux binaries under Rosetta:
default/`CLASSIC_FALLBACK` verified/falsified in 2/504 steps (63.91/74.10 s);
default/`NO_PREFIX_GUARD` verified/falsified in 4/526 steps (67.04/75.40 s).
The transition-prefix digests match the earlier macOS results.

The native trace uses a permitted reveal of the initial CK. The attacker
completes a classical Resume using that CK and the public S1 nonce, derives
the session keys, then injects both authenticated CT pieces. A becomes
`Ready` in the initial epoch and subsequently starts another classical Resume
without any intervening `Advance`. The normal mandatory-mixing guard forbids
that ordering. This is an attack against the deliberately mutated symbolic
model, not a newly found vulnerability in the guarded protocol or evidence
about constant-time implementation.

`ratchet-classic-fallback-attack.inc` stores only the successful native attack
path, without unfinished steps or unselected alternatives. Tamarin may
reconstruct unexplored alternatives while loading the skeleton; falsification
requires one solved counterexample, not exhaustive exploration. Regenerate
the include from a saved native UI export with exactly one solved target path:

```sh
python3 docs/spec/models/extract_attack.py /path/to/native-attack-export.spthy
python3 docs/spec/models/mutation.py --timeout 180
```

Extraction replays the chosen path before writing the generated include.
The second command checks its current assembled-source correspondence.
Unrelated lemmas are omitted, never rules, restrictions, equations or attacker
behaviors. Full assembled-context completion, disclosure-source closure and
independent combined-equation acceptance remain open.

### Native stored-prefix mutation regression

The second profile uses the same runner and toolchain:

```sh
python3 docs/spec/models/mutation.py --mutation NO_PREFIX_GUARD --timeout 180
```

`--mutation` selects `CLASSIC_FALLBACK` (the default) or `NO_PREFIX_GUARD`.
Both compare the selected target's exact formula/attributes and retain its
entire assembled non-lemma prefix without any helper lemmas. For
`NO_PREFIX_GUARD`, the runner checks that the default declarations remain
unchanged and that exactly two unguarded tail rules are added. Each must
match its guarded counterpart except for removing the stored `!EK0` or
`!CT0` premise and renaming the rule/diagnostic action. In particular,
`mandatory_mix` remains present. Any additional change fails correspondence.

| Profile | Target | Required local native result |
|---|---|---|
| Default: prefix guards present | `no_partial_mix` | `verified (4 steps)` |
| `NO_PREFIX_GUARD` | `no_partial_mix` | `falsified - found trace (526 steps)` |

The intended-red run rejected the old mutation certificate's
`analysis incomplete (6 steps)` result. The generated native attack
certificate makes the regression pass. Its trace uses an allowed initial-CK
reveal and a completed classical Resume. The attacker forges an authenticated
CT tail without sending a CT prefix. The unguarded receiver accepts full
reception, stores the decapsulation result and becomes ready; a later
`I_S1_mix` reaches `MixStart` without any `CTPrefix` event. Both complementary
pieces are required by the real protocol. This counterexample demonstrates
why tail acceptance must check durable prefix state even when the session
encryption authenticates. It is not a vulnerability in the guarded model.

The trace exercises the CT side. The runner verifies correspondence for both
added EK and CT rules, but does not claim a separately guided EK counterexample.
It is symbolic, not proof of concrete byte-range checks or storage atomicity.
The new `mutation-no-prefix-guard` CI job and `REPLAY=1 scripts/check.sh`
run the regression; hosted execution remains unverified.

Regenerate `ratchet-no-prefix-guard-attack.inc` from a saved native UI export:

```sh
python3 docs/spec/models/extract_attack.py /path/to/native-prefix-attack.spthy \
  --mutation NO_PREFIX_GUARD
python3 docs/spec/models/mutation.py --mutation NO_PREFIX_GUARD --timeout 180
```

The shared extractor requires one solved target path and natively replays it
before writing the include. `--output PATH` overrides the default generated
include path. Both symbolic guard mutations now have native sensitivity
regressions; the broader ratchet implementation gate remains closed.

The model encodes wire epoch zero as the positive natural `%1`, and uses
natural-number successors, not a concrete u32 counter or LEB128 parser.
Each piece conservatively exposes the full public object
once its enclosing session encryption is opened, while full acceptance
requires both pieces. Position tags distinguish the pieces; redundant
piece/decoder equations were removed without changing this disclosure
abstraction. Byte offsets, exact duplicate comparisons, length
boundaries, crash atomicity, exhaustion and platform persistence remain
implementation-test obligations even after a symbolic proof succeeds.

## Pairing (`sas.spthy`)

Run from this directory:

| Command | Profile | Expected | Time (Apple silicon) |
|---|---|---|---|
| `tamarin-prover --prove sas.spthy` | Spec §5, draft 0.4 | 16 lemmas verified | ≈ 11 s |
| `tamarin-prover --prove=mode_integrity -D=MODE_FROM_P1 sas.spthy` | Draft 0.3 (B takes the mode from P1) | Falsified: SAS → TOFU downgrade (OI-19) | ≈ 8 s |
| `tamarin-prover --prove=no_grinding_A -D=NO_COMMIT sas.spthy` | Mutation: P1 carries `nA` in the clear | Falsified: shows the lemma detects grinding | ≈ 5 s |

### Properties

Numbers refer to the lemma list in [formal-tooling research §8.3](../../research/2026-10-05-formal-model-tooling.md).

| # | Property | Lemma | Result |
|---|---|---|---|
| 1 | Commitment binding | `commit_binding` | Verified |
| 2 | Order enforcement (no grinding) | `no_grinding_A`, `no_grinding_B` | Verified; falsified by the `NO_COMMIT` mutation |
| 3 | SAS agreement on `th`, `nB` and `RK`; `RK` secrecy | `sas_agreement_A`, `sas_agreement_B`, `sas_secrecy` | Verified |
| 4 | Mismatched transcripts complete only by a code collision | `mismatch_needs_guess` | Verified |
| 5 | TOFU admits an active MitM; Verify recovers | `tofu_mitm` (exists-trace), `verify_recovers` | Verified |
| 6 | QR: B protected by `qh`; A by `token`, and by QRC if the QR was photographed | `qr_B_secrecy`, `qr_agreement_A`, `qr_secrecy_A` | Verified |
| – | B never runs a weaker mode than its user chose | `mode_integrity` | Verified; **falsified in draft 0.3** (OI-19) |

`executable_SAS`, `executable_QR` and `executable_TOFU_verify` show that honest runs complete.

### Guessing bound (counting argument)

Tamarin can't state probabilities, so the model makes a code collision an explicit `Lucky` action, and the bound is argued here. ProVerif's `weaksecret` doesn't apply: the codes are computed from public values (`th`, `nB`), so they are not secrets (decided in ticket *Formal model: SAS pairing*).

Treat `H` as a random oracle. Let `t_A` be when the attacker learns `nA` and `t_B` when it learns `nB`.
- By `no_grinding_A`, every input to A's code except `nA` is fixed before `t_A`.
- By `commit_binding` and `no_grinding_B`, every input to B's code except `nB` is fixed before `t_B`.
- Whichever nonce is revealed last, the other code is already determined at that moment, and the code that depends on the last nonce is uniform over its range from the attacker's view.

So each attempt succeeds with probability at most 10⁻⁶ ≈ 2⁻²⁰ for SAS (10⁻⁴ for QRC once the QR was photographed), plus negligible hash-collision and `Digits` bias (< 2⁻⁴⁴) terms. A failed comparison aborts visibly (ADR 0009), so `q` attempts succeed with probability at most `q · 10⁻⁶`. This is the commit-then-reveal argument of Vaudenay (CRYPTO 2005), which has no machine-checked model; the Tamarin lemmas mechanise its ordering premises.

### Abstractions and limits

- A ceremony is two users together who agree on a mode. Their code comparison is an authentic human channel, and each ceremony has one A session and one B session.
- X-Wing is an ideal KEM. Hashes, HKDF and the MAC are free functions; AEAD is symmetric encryption; cards are constants.
- The QR reaches only B's camera; `RevQR` lets the attacker photograph it.
- Not covered: device compromise during pairing, card contents (beacon key, KCI key), the 120 s timeout, and users who confirm without comparing.

## Modelling notes

The first Resume versions did not terminate. Every lemma timed out, because state-copy rules (reveal, abort, timeout) formed loops in backward search. The fixes, in case they're useful for the other models:

1. **Persistent state plus restrictions** (`Cur` / `Retire`) instead of linear facts that rules consume and re-produce.
2. **State keyed by pairing role.** Names come from a `!Party` fact created at `Pair`, so identities sit one step from `Pair` instead of behind the whole Resume history.
3. **Secrecy helper split in two:**
   - an inductive lemma on key creation (`CK`);
   - a non-inductive bridge lemma on key use (`Cur`) that other proofs can apply.
4. **Selective agreement reuse.** Reuse only independently verified lemmas;
   hide irrelevant hints when they expand history, and hide safety lemmas
   that are false in attack-mutation profiles.
5. **Pinned `exists-trace` lemmas.** Pin them to the first Resume after `Pair`, and exclude irrelevant behaviour (for example, B never initiates).
