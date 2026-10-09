# Ratchet source-precomputation evidence

Reference snapshot for the default, unrestricted
[`ratchet.spthy`](ratchet.spthy), observed on 2026-10-09.
This inventories unresolved sources; it does not prove their closure.

## Configuration and identity

Tamarin 1.12.0, Maude 3.5.1, Graphviz 16.1.0, macOS/Apple silicon.
No preprocessor definitions, source-limit overrides, auto-sources or
protocol mutations were enabled. Default open-chain/saturation limits
were 10/5. The assembled `--parse-only` SHA-256 was:

`1dd88a6b63d08fb64654d0e82e6f5cae0d37ef445a996e4e139e01965419d380`.

From the repository root:

```sh
tamarin-prover docs/spec/models/ratchet.spthy \
  --quit-on-warning --precompute-only --derivcheck-timeout=60
```

The command completed within the separate 180-second caller limit:

```text
Multiset rewriting rules and restrictions: 45
Raw sources: 43 cases, 30 partial deconstructions left
Refined sources: 43 cases, 30 partial deconstructions left
```

The CLI's `43 cases` denotes source-goal groups, not the number of
individual branches. Interactive inspection found 43 groups and 179
branches in each of raw and refined sources. The default protocol itself
has 43 rules and 13 restrictions; these are separate inventories.

## Residual-chain inventory

Every row below has exactly two partial branches: one named `Reveal_CK`
and one named `Reveal_SS`, each with one unresolved chain. The goal's
variables are schematic. Raw and refined inventories have the same
residual classification.

| Attacker-knowledge goal | All branches in group | Unresolved chains |
|---|---:|---:|
| `KU(~t)` | 13 | 2 |
| `KU(ext(x,y))` | 3 | 2 |
| `KU(flip(x))` | 3 | 2 |
| `KU(fst(x))` | 3 | 2 |
| `KU(h(x))` | 3 | 2 |
| `KU(kdec(x,y))` | 3 | 2 |
| `KU(kdf(x,y,z))` | 5 | 2 |
| `KU(kem(x,y))` | 7 | 2 |
| `KU(mac(x,y))` | 7 | 2 |
| `KU(pk(x))` | 7 | 2 |
| `KU(sdec(x,y))` | 3 | 2 |
| `KU(senc(x,y))` | 25 | 2 |
| `KU(snd(x))` | 3 | 2 |
| `KU(%1)` | 3 | 2 |
| `KU(%x %+ %y)` | 3 | 2 |
| **Total** | **101** | **30** |

The other 28 groups have 78 branches and no residual chain in this
snapshot. Their premise facts are:

`CKValue`, `CT0`, `CompleteCT`, `CompleteEK`, `DKOwner`, `EK0`, `EncWait`,
`GenKey`, `Have`, `Index`, `Party`, `PositionValue`, `Progress`,
`ReadyEpoch`, `SKValue`, `SSValue`, `SentTail`, `Session`, `St`,
`BusySlot`, `CandidateState`, `DKMaterial`, `EncMaterial`, `FinishPermit`,
`IWait`, `RPending`, `ResumeSlot`, `StartPermit`.

Refined profile: the 15 remaining chains are the `Reveal_SS` rows only
(the 15 goals above). In each, `!SSValue(pid, ss)` stays unsolved between
`Prepare_encapsulation` and `Decode_known_ciphertext`. Closing the second
requires the recursive `kem_ciphertext_origin` argument, and `SSValue`
carries no action fact a `[sources]` lemma can bind without editing the
protocol prefix. A `[sources]` promotion of the KEM lemma raised the count
to 16. These chains are therefore closed only by the per-lemma certificates.

Tried and reverted: a `DISCLOSURE_SOURCES`-gated action fact
`Decoded(pid, ct, ~dk)` on `Decode_known_ciphertext`. The profile loaded
with an unchanged 15 refined / 30 raw count. The leftover obligation in
the `Reveal_SS` cases is not a decode step: it is an unsolved attacker-built
`!KU(senc(<'CT', ..., kem(t, pk(~dk))>, kr))` whose payload `t` is the
secret being derived, a circular dependency. No action fact on the decode
rule addresses it, so the rule stays unchanged.

Absence of a residual chain is a precomputation observation, not a
correctness or secrecy theorem about these facts.

## Remaining constraints and source authority

Each partial branch contains a chain of the form
`(#vl,0) ~~> (#i,0)` and the corresponding unresolved reveal premises:

| Branch | Premises retained in source case | Model authority |
|---|---|---|
| `Reveal_CK` | `!CKValue(pid,t)[no_precomp]`, `!St(pid,r,t,e,g)[-,no_precomp]` | [`ratchet.spthy`](ratchet.spthy), `Reveal_CK` |
| `Reveal_SS` | `!SSValue(pid,t)[no_precomp]`, `!Have(pid,r,e,pq,t,ek,ct)[-,no_precomp]` | [`ratchet.spthy`](ratchet.spthy), `Reveal_SS` |

These are allowed compromise disclosures, not extra attacker restrictions.
Source precomputation stops before determining which concrete key/secret
shape can support each deconstruction. The annotations intentionally limit
expansion; this report does not establish that removing them is tractable
or sufficient.

The sole current `[sources]` lemma is `dk_reveal_owner` in
[`ratchet-origins.inc`](ratchet-origins.inc). Its 9-step certificate replays
in the [exact-source witness gate](README.md#exact-source-witness-replay).
It relates DK creation and disclosure ownership; it does not constrain the
two CK/SS reveal families above. Ordinary `[reuse]` origin lemmas are not
automatically source-refinement lemmas. Their existence must not be reported
as elimination of these chains.

## Inspection commands and limits

The loopback-only interactive server used:

```sh
tamarin-prover interactive docs/spec/models \
  --interface=127.0.0.1 --port=3009 \
  --quit-on-warning --derivcheck-timeout=60
```

After startup, `/` identified the ratchet as theory index 2 for this run.
Indices are runtime-assigned: identify the ratchet link again in each run.
The version-specific routes
`/thy/trace/2/main/cases/raw/1/1` and
`/thy/trace/2/main/cases/refined/1/1` returned JSON whose `html` field
contained the complete respective source inventory, not just one branch.
All group headings, branch headings, partial-deconstruction labels and
unsolved `~~>` constraints were enumerated. The totals matched the CLI.
These routes are inspection interfaces, not stable public APIs.

The overview route timed out after 30 seconds, but both source routes
responded within their 30-second request limits. No interactive proof action
or graph rendering was needed. The server was stopped after inspection.
The inventory is a reviewed snapshot, not an automated zero-chain CI gate.

The next proof obligation is a sound CK/SS disclosure-source refinement,
proved against raw sources while retaining all compromise behavior.
In particular, SS values include both generated secrets and
`kdec(ct,dk)` results: assuming every SS is a fresh atom would be an
unsound shortcut. Do not delete reveals, add unjustified sorts, or assume
origin lemmas as restrictions to obtain zero chains.

The [Tamarin 1.12.0 precomputation documentation](https://github.com/tamarin-prover/tamarin-prover/blob/1.12.0/manual/src/009_precomputation.md)
explains raw/refined sources, proof requirements for `[sources]` lemmas
and limitations of auto-sources. No source-closure or independent-review
gate is closed by this inventory.

## Opt-in disclosure refinement

[`ratchet-disclosure-origins.inc`](ratchet-disclosure-origins.inc) contains
two new Tamarin-generated certificates, included only when
`DISCLOSURE_SOURCES` is defined:

| Lemma | Proved origin before disclosure | Raw-source certificate |
|---|---|---:|
| `ck_disclosure_origin` | Initial pair CK, or a derived `kdf(prk,'ratchet',<pid,ctx>)` | 12 steps |
| `ss_disclosure_origin` | Local `FreshSS`, or prior `EpDec` with that SS | 8 steps |

Both were proved against the unchanged 43-rule/13-restriction native
prefix, with no ordinary `[reuse]` helpers. The SS certificate resolves
`Have` directly through `Encapsulate` and `Receive_CT_tail`; it does not
assume that decoded secrets are fresh. A formula explicitly using
`kdec` was rejected by strict wellformedness because reducible functions
are disallowed in lemma formulas. It was replaced by the existing `EpDec`
action, not by weakened parser checks or new protocol instrumentation.
An unrestricted SS search timed out at 180 seconds. A producer-directed
search, bounded to depth 30, verified it in 24.62 seconds.
The saved certificate requires neither that tactic nor a proof-depth bound.

Reproduce source counts and certificate/witness replay:

```sh
tamarin-prover docs/spec/models/ratchet.spthy \
  --defines=DISCLOSURE_SOURCES --quit-on-warning \
  --precompute-only --derivcheck-timeout=60
python3 docs/spec/models/replay.py --disclosure-sources --timeout 180
```

Observed raw sources remain 43 groups/30 residual chains. Refined sources
have 43 groups, 172 branches and **15 residual chains**, one `Reveal_SS`
branch in each of the same 15 knowledge shapes. Refined branches per
shape, in the table's order, are:
`14, 2, 2, 2, 2, 3, 9, 6, 6, 6, 2, 24, 2, 2, 2`.
The other 28 groups still account for 78 branches.
All three source certificates replay: CK 12, SS 8, DK 9 steps.
The unchanged lost-data certificate checks in 802 steps in this context.
The native assembled profile SHA-256 before KEM certificate migration was
`15950985d6db52779c2478144da858ba1d1833bf2e9d1c83cd74ba69b9d0c34b`;
the selected native replay SHA-256 is
`3b71e303ae16cb2094acf440599c705fa954f1866e2218728b095ebf26cdbc11`.
These include the new lemmas; all non-lemma declarations were compared
with the default export and are identical.

The remaining SS branches now expose a recursive disclosure-origin
obligation. For example, the fresh-atom group includes accepted encrypted
CT prefix/tail knowledge and another `Reveal_SS` occurrence supporting
the unresolved chain. Prior decapsulation identifies the source but
does not establish where a possibly structured ciphertext payload came
from. Merely treating every decapsulation result as a fresh atom is
still unsound.

### Compatibility boundary

Refinement changes source-case trees used by existing proof skeletons,
even though traces are unchanged. In an exact-prefix context retaining
all 54 complete all-traces certificates, 46 replayed and these eight
became incomplete:

`kem_ciphertext_origin`, `encrypted_origin`, `extract_origin`,
`ratchet_key_origin`, `session_key_origin`, `fresh_dk_origin`,
`fresh_ss_origin`, `initial_ck_secret`.

A named regeneration of those eight timed out at 240 seconds. A context
containing all 58 complete certificates, including existential witnesses,
also timed out at 240 seconds. Neither run establishes a counterexample
or a new assembled verification count.
Testing the existing KEM origin certificate separately as a raw-source
lemma succeeded in 31 steps but increased residual chains to 16; that
promotion was not retained.

Consequently the new refinement is an explicit diagnostic proof profile,
**not a default cutover**. Default sources and existing certificate
contexts remain unchanged. The repository runner and CI replay the
new profile's source certificates, lost-data witness and migrated KEM
origin certificate; they do not certify its other safety claims.
Migrating the remaining seven proof skeletons
and completing the recursive SS source reasoning are prerequisites to
enabling it by default. The overall source-coverage gate remains open.

### First migrated safety certificate

`kem_ciphertext_origin` now has a separate generated
[`ratchet-refined-kem-origin.inc`](ratchet-refined-kem-origin.inc)
certificate selected only by `DISCLOSURE_SOURCES`.
Its formula and `[reuse, use_induction]` attributes are identical to the
default certificate; no KEM lemma was promoted to `[sources]`.
Default source counts and export digests remain unchanged.

The old refined replay was incomplete at the `Reveal_SS` /
`Decode_known_ciphertext` branch. Explicitly splitting its destructor
variants, resolving the deconstruction chain and applying induction to
earlier nested KEM knowledge closes the branch. The fresh-secret
alternative cannot generate a structured KEM term. Session-history
expansion is unnecessary. Search-depth bounds used during inspection
are absent from certificate-only replay:

```sh
python3 docs/spec/models/replay.py \
  --disclosure-sources --target kem_ciphertext_origin --timeout 120
python3 docs/spec/models/replay.py \
  --target kem_ciphertext_origin --timeout 120
```

Observed profile/default KEM replay: **18/31 steps**, respectively,
with every source certificate verified. The profile's selected KEM
context has no ordinary reuse helpers besides the target.
Native assembled profile SHA-256 after migration:
`6723c1a83fbb4097fc8951bc6cf5411b082534d033b48f30e47083128a7a2f50`.
Selected KEM replay SHA-256:
`51a3c68ea7da360b847178bbb52d75c9caed7d81314aae2051e43dcc508dc2a5`.
The selected replay preserves all 43 rules, 13 restrictions, signature,
equations, and retained formulas/attributes/certificates through the
runner's native roundtrip.

In the exact-prefix context of 54 complete safety certificates, replay
verified **47** and left **seven** incomplete: the previous list
minus `kem_ciphertext_origin`. The remaining certificates and 15 SS
source chains are still open. This is not a full-theory completion count.

### Second migrated safety certificate

`fresh_dk_origin` has a separate generated
[`ratchet-refined-fresh-dk-origin.inc`](ratchet-refined-fresh-dk-origin.inc)
selected only by `DISCLOSURE_SOURCES`; its formula and
`[reuse, use_induction]` attributes are unchanged and the default
certificate and export digests are unchanged. The refined replay was
incomplete at the same `Reveal_SS` / `Decode_known_ciphertext` branch
(under both `Pair` cases). Splitting the destructor variants, using the
`kem_ciphertext_origin` disjunction, and resolving the `~~>` chain
closes it; the earlier-knowledge alternative is cyclic.

```sh
python3 docs/spec/models/replay.py \
  --disclosure-sources --target fresh_dk_origin --timeout 180
```

The runner retains the target, its declared dependency
`kem_ciphertext_origin` and all source lemmas. Observed: **46 steps**
(`ck_disclosure_origin` 12, `ss_disclosure_origin` 8,
`kem_ciphertext_origin` 18, `dk_reveal_owner` 9). Selected replay
SHA-256: `aa680152cc4af251bd997c8d8dbff74a36d898249ae33ce4e9de7cd6d15c2b9e`.
The exact-prefix safety-only context is re-measured below.

### Remaining migrations

The same destructor-splitting method (`splitEqs`, the
`kem_ciphertext_origin` disjunction, then the `~~>` chain) closed the
stale `Decode_known_ciphertext` branches of six more certificates, each
with unchanged formula and attributes and a generated
`ratchet-refined-*.inc` selected only by `DISCLOSURE_SOURCES`
(`ratchet-origins.inc`, `ratchet-secrecy.inc`). Selected replay, each with
the three source certificates and its `kem_ciphertext_origin` dependency:

| Target | Profile steps | Default steps |
|---|---|---|
| `encrypted_origin` | 43 | not re-run |
| `extract_origin` | 20 | 26 |
| `session_key_origin` | 39 | not re-run |
| `ratchet_key_origin` | 31 | 32 |
| `initial_ck_secret` | 11 | 21 |
| `fresh_ss_origin` | 101 | not re-run |

Default exports and the lifecycle theory digest are unchanged.
`fresh_ss_origin` closed with the same method, so all eight certificates
are migrated; the 15 residual SS source chains still need
ciphertext-payload origin reasoning.

### Combined safety-only context

Rebuilt from the native `DISCLOSURE_SOURCES` export (61 lemmas) by
retaining every complete `all-traces` lemma and dropping four existential
witnesses (`executable`, `initiator_candidate_recovery`,
`lost_data_recovery`, `fresh_epoch_after_compromise`) and three incomplete
lemmas (`lock_stage_order`, `initial_resume_serialized`,
`resume_serialized`). Result: **54/54 verified**, 38.7 s,
`tamarin-prover --prove --quit-on-warning --derivcheck-timeout=60`
(native export SHA-256
`2421f43c5907ff5a2e96e4dea404a643b472ed25ab38922bf6bc11b48f49bfe1`; selected
context `f82357a72ab9304d2438d3311986ebdd48e312a346f3fa1cb974e414fae195d0`).
This is not a full-theory count: the excluded lemmas are unproven here, and
the 15 residual SS source chains remain. The context is an ad hoc
measurement, not a CI gate.
