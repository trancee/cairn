# Ratchet source-precomputation evidence

Reference snapshot for the default, unrestricted
[`ratchet.spthy`](ratchet.spthy), observed on 2026-10-09.
This inventories unresolved sources; it does not prove their closure.

## Configuration and identity

Tamarin 1.12.0, Maude 3.5.1, Graphviz 16.1.0, macOS/Apple silicon.
No preprocessor definitions, source-limit overrides, auto-sources or
protocol mutations were enabled. Default open-chain/saturation limits
were 10/5. The assembled `--parse-only` SHA-256 was:

`8979b0346fbcd45370222436b2595af509460070a368eee4f70f05190e3e4051`.

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

The table is the raw-source inventory: every row has exactly two partial
branches, one named `Reveal_CK` and one named `Reveal_SS`, each with one
unresolved chain. The goal's variables are schematic. The current refined
disclosure profile has 16 residual chains, all in `Reveal_SS`; its count is
not the raw table's 30-chain total.

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

Before the KEM-origin `[sources]` promotion, the refined profile had 15
remaining chains, one `Reveal_SS` branch in each of the 15 shapes above.
The current profile has 16 refined residual chains after that promotion.
Interactive inspection of the representative chains found
`!SSValue(pid, ss)` unresolved between `Prepare_encapsulation` and
`Decode_known_ciphertext`; the new per-lemma KEM certificate does not close
these source branches globally. The source-coverage gate remains open.

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

The current `[sources]` lemmas are `dk_reveal_owner` and
`kem_ciphertext_origin` in [`ratchet-origins.inc`](ratchet-origins.inc)
and its disclosure-profile include. `dk_reveal_owner` relates DK creation
and disclosure ownership. `kem_ciphertext_origin` relates attacker
knowledge of a structured KEM ciphertext to prior fresh encapsulation or
knowledge of its shared-secret payload. The latter's refined certificate
does not close the remaining `Reveal_SS` source chains. Ordinary `[reuse]`
origin lemmas are not automatically source-refinement lemmas; neither their
presence nor a verified source lemma proves global source closure.

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

At this stage, raw sources remained at 43 groups/30 residual chains.
Pre-promotion refined sources had 43 groups, 172 branches and **15 residual
chains**, one `Reveal_SS` branch in each of the same 15 knowledge shapes.
Refined branches per
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
An initial raw-source proof of the KEM-origin formula succeeded in 31 steps
but increased refined residual chains to 16; the promotion was not retained
at that point because it had not been replayed in the selected exact-source
context.

Consequently the new refinement is an explicit diagnostic proof profile,
**not a default cutover**. Default sources and existing certificate
contexts remain unchanged. The repository runner and CI replay the
new profile's source certificates, lost-data witness and migrated KEM
origin certificate; they do not certify its other safety claims.
All eight migrated refined-origin certificates now replay with the
`[sources]` KEM-origin helper, but 16 refined chains and assembled-context
verification remain open. The overall source-coverage gate remains open.

### First migrated safety certificate

`kem_ciphertext_origin` now has a separate generated
[`ratchet-refined-kem-origin.inc`](ratchet-refined-kem-origin.inc)
certificate selected only by `DISCLOSURE_SOURCES`.
Its formula is identical to the default certificate; the refined-profile
attributes are `[sources, reuse, use_induction]`. The default lemma keeps
its original attributes and default source counts and export digests remain
unchanged.

The refined proof splits the `Decode_known_ciphertext` equality cases under
both `Pair` sources, resolves the deconstruction chain and uses induction
on earlier nested KEM knowledge. The fresh-secret alternative cannot
generate a structured KEM term. The generated certificate verifies in
31 steps; search-depth bounds used during inspection are absent from
certificate-only replay:

```sh
python3 docs/spec/models/replay.py \
  --disclosure-sources --target kem_ciphertext_origin --timeout 180
python3 docs/spec/models/replay.py \
  --target kem_ciphertext_origin --timeout 180
```

Observed profile/default KEM replay: **31/31 steps**, respectively, with
all source certificates verified. The disclosure-profile replay preserves
all 43 rules and 13 restrictions and all non-lemma declarations through
the runner's native roundtrip.

In the exact-prefix context of 54 complete safety certificates, replay
verified **47** and left **seven** incomplete: the previous list
minus `kem_ciphertext_origin`. This historical count predates the
`[sources]` promotion and is not a full-theory completion count.

The source attribute was then tested in the full 43-rule/13-restriction
theory. Strict precomputation reports 30 raw and 16 refined residual
chains, so the promotion does not close the global source gate. A
lemma-focused context with every protocol rule and restriction preserved
generated the certificate; exact-source replay verified it and each of
the eight migrated refined-origin certificates, plus
`encrypted_ct_tail_encapsulated`. This establishes the KEM source lemma,
not completion of the recursive `Reveal_SS` chains or the full assembled
theory.

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
are migrated. At that stage, the 15 residual SS source chains still needed
ciphertext-payload origin reasoning; the current post-promotion count is 16.

### CT-tail output provenance helper

Added `encrypted_ct_tail_encapsulated [reuse]` to
[`ratchet-transfer-origins.inc`](ratchet-transfer-origins.inc). It states
that an honest outgoing CT half-tail `EncryptedOutput` follows an earlier
`EpEnc` for the same epoch and ciphertext, with the sending session use at
the output event. Its four-step certificate sources the output at
`Send_CT_tail` and the `EncWait` state at the earlier `Encapsulate`.

The repository runner verifies this certificate independently in both
profiles:

```sh
python3 docs/spec/models/replay.py \
  --target encrypted_ct_tail_encapsulated --timeout 120
python3 docs/spec/models/replay.py --disclosure-sources \
  --target encrypted_ct_tail_encapsulated --timeout 120
```

Observed: four steps in each profile, with all retained source certificates
verified; each selected replay preserves all 43 rules and 13 restrictions.
The default source/replay SHA-256 values are
`5b88721e10ec9be426f915e913e0c9fccf01495607ee14c2407161528d5d7881` and
`c876fb1186a81253497cbd30eeec31a11298ee27eb481ba57cc27b9ad5dcaf2e`;
the disclosure-profile values are
`5f941bae3ae34db1d0b0cc03db4bf28534f1702e48558c24d35158ecf4c1a2b5` and
`fcac36e0e74e1e0b7fe4d72f2a931e3a4ed9ebb07e6f0cd7ee93fb100e449d8b`.
This is outgoing honest-peer provenance only: it does not establish the
origin of attacker-supplied incoming CT tails and does not reduce the 15
residual refined SS chains.

### Focused CT-tail ciphertext-origin attempt (2026-10-09)

Inspected the refined `Reveal_SS` source branch whose attacker-knowledge
goal is
`!KU(senc(<'CT', e, 'half', kem(t, pk(~dk))>, kr))`. Its unresolved
constraints include the `Reveal_SS` premises for `!SSValue` and `!Have`,
an earlier-event chain, and corresponding encrypted CT-tail knowledge.
The associated `Receive_CT_tail` source case has
`EpDec(..., kem(t, pk(~dk)), t)`, but the rule accepts the network-provided
ciphertext; this event alone does not establish that `t` is fresh.

A temporary raw-source candidate claimed that every attacker-known
encrypted CT tail with a KEM payload came from a prior `EncryptedOutput`
or prior attacker knowledge of the payload. It was **falsified in 8 steps**:
`Prepare_encapsulation` exposes a KEM ciphertext without exposing its
plaintext, and the attacker can encrypt that ciphertext with a known key.
Thus any sound origin statement must include the `FreshSS` possibility for
the encapsulated payload.

Adding that possibility produced this source-lemma candidate:

```text
KU(senc(CT-half(kem(ss, pk(dk))), kr))
  => prior EncryptedOutput
     | prior FreshSS(ss, pk(dk))
     | prior KU(ss)
```

Strict raw-source proof attempts timed out at 240 seconds with the default
heuristic and 180 seconds with the induction-oriented heuristic, both using
the unchanged transition system. Including the verified
`kem_ciphertext_origin` and `encrypted_origin` helper certificates in the
minimal proof context did not close the automatic search within 180 seconds.
These timeouts are inconclusive; the candidate was not proved or promoted.

Interactive expansion of the candidate isolated the remaining recursive
case. `Reveal_SS` can select `Decode_known_ciphertext`, after which
`splitEqs` gives either a generated-secret case or
`ss = kdec(ct, dk)`. The generated-secret case contradicts the absence of a
prior `FreshSS`; in the decoded case the remaining goals include
`!KU(ct)` and an unresolved earlier-event chain. This is consistent with
the attacker supplying a previously known, potentially structured
ciphertext; it does not justify replacing decapsulation results with fresh
atoms. No transition, restriction, attacker capability, or committed
certificate was changed. The 15 residual chains remain open, and this
experiment does not establish that every possible sound refinement fails.

### Further encrypted-origin refinement attempts (2026-10-10)

Tried a shape-specific raw-source candidate for attacker-known encrypted CT
half messages carrying a KEM ciphertext:

```text
KU(senc(CT-half(kem(ss, pk(dk))), kr))
  => prior EncryptedOutput
     | prior FreshSS(ss, pk(dk))
     | prior KU(ss)
```

The temporary candidate passed parsing and strict wellformedness with
`DISCLOSURE_SOURCES`, but an induction-oriented proof search timed out at
240 seconds with both induction-oriented and output-oriented heuristics.
Loading that candidate in the loopback interactive UI completed the theory
checks, but requesting the initial proof source timed out after 30 seconds;
the server was stopped without changing the certificate or model.

Also tested promoting the existing refined `encrypted_origin` lemma from
`[reuse, use_induction]` to `[sources, reuse, use_induction]` in an ephemeral
copy of the model. Raw source precomputation remained at 30 residual chains,
but refined chains expanded from 15 to 765 and source saturation stopped at
the configured five-iteration limit. The promotion was discarded; it is
not a viable refinement in this form.

These tests preserve all protocol rules and attacker capabilities. The
shape-specific candidate remains unproved, the source promotion is rejected,
and the 15-chain source-closure gate remains open.

A final variant replaced the payload-secret alternatives with the
term-origin condition expected from attacker construction: prior knowledge
of the complete `kem(ss, pk(dk))` ciphertext and symmetric key `kr`, or a
matching `EncryptedOutput`. This avoids incorrectly requiring knowledge of
`ss` when the KEM ciphertext itself is public. The candidate passed strict
parsing, but its output-oriented proof timed out at 180 seconds and its
induction-oriented proof timed out at 240 seconds. It was not promoted;
refined source counts remain unchanged.

### Oracle and auto-sources diagnostics (2026-10-10)

Retried the focused ciphertext-origin theorem in a temporary minimal native
MSR context using `--heuristic=O` and the explicit inert oracle
`--oraclename=/usr/bin/true`. This avoids Tamarin's default lookup for a
missing `./oracle`; the source-lemma proof still timed out at 240 seconds.
The result is inconclusive, not a counterexample or a proof.

Also ran the unchanged `DISCLOSURE_SOURCES` theory with
`--auto-sources --precompute-only --derivcheck-timeout=60`. Tamarin reported
43 source groups, 30 raw residual chains and 15 refined residual chains, the
same residual counts as without auto-sources. The canonical native export
contained no generated `AUTO_typing` lemma. This option did not close the
remaining chains or produce a certificate to inspect.

In a temporary theory, removed only `!SSValue(pid,ss)` from the `Reveal_SS`
premises while retaining the active `!Have(...)` state guard. Strict default
and `DISCLOSURE_SOURCES` precomputation still reported 30 raw and 15 refined
residual chains. Interactive source inspection showed the unresolved
`Reveal_SS` chain now at `!Have(...)`, rather than `!SSValue(...)`; removing
the ghost guard therefore does not close the chains. The candidate was
discarded, and the model's compromise behavior was not changed.

Tried a narrower ciphertext-origin source candidate with an extra disjunct
for prior `RevSS` of the exact structured ciphertext. This accounts
explicitly for a disclosed shared secret that itself equals the CT-tail
message, without asserting that a decoded secret is fresh. Its focused
proof search still expanded through the `Reveal_SS`/`Have` decapsulation
history; the operating system killed both candidate precomputation and proof
processes with exit `-9` before a theorem result. This is resource-inconclusive,
not a falsification or verification, and the candidate was not adopted.

As a narrower follow-up, added prior `RevSS(pid,ss)` as an alternative to
the existing `FreshSS` and prior `KU(ss)` cases in a temporary
`kem_ciphertext_origin [sources]` candidate. It strictly precomputed with
30 raw residual chains but 19 refined chains (instead of 15); because the
candidate intentionally had no proof certificate, this is diagnostic only
and does not establish a valid refinement. Its raw proof search using
`--heuristic=I` and `--oraclename=/usr/bin/true` timed out at 300 seconds.
No certificate was generated or promoted.

Tested a separate input-origin candidate:

```text
EpDec(pid, r, e, ek, ct, ss) @ i
  => prior KU(ct)
```

The intent was to establish that any ciphertext accepted by
`Receive_CT_tail` was already attacker-known, either because the attacker
constructed the encrypted input or because it replayed a protocol output.
The strict profile precomputation succeeded but remained at 30 raw / 15
refined residual chains. Automatic proof search timed out at 240 seconds
with default settings, 180 seconds with `--heuristic=O`, and 180 seconds
with `--heuristic=I`; none produced a theorem result or certificate. The
candidate remains unproved and was not retained. The focused command shape
was:

```sh
tamarin-prover <temporary-candidate.spthy> --defines=DISCLOSURE_SOURCES \
  --quit-on-warning --derivcheck-timeout=60 \
  --prove=epdec_ciphertext_known [--heuristic=O|I]
```

### Decapsulation-event alternative for KEM ciphertext origin (2026-10-10)

Tried another temporary `kem_ciphertext_origin [sources]` candidate. In
addition to prior `FreshSS` and `KU(ss)`, it allowed any earlier
`EpDec(pid,r,e,dk,ct,ss)` event as an origin for an attacker-known
`kem(ss,ek)` term. Strict `DISCLOSURE_SOURCES` precomputation completed
with 30 raw and 18 refined residual chains, compared with 30/15 for the
unchanged profile. Focused proof attempts using both `--heuristic=I` and
`--heuristic=O` with the inert oracle `/usr/bin/true` timed out at 240
seconds. The output-oriented attempt still showed unresolved `!Have` and
attacker-knowledge constraints. No proof certificate or counterexample was
produced; the candidate was discarded. This result is inconclusive and does
not establish that no sound source refinement exists. No model rule,
restriction, attacker capability, or repository certificate was changed.

### Combined safety-only context

Rebuilt from the current native `DISCLOSURE_SOURCES` export, retaining every
complete `all-traces` lemma. The selection contains **55** lemmas; it excludes
four existential witnesses (`executable`, `initiator_candidate_recovery`,
`lost_data_recovery`, `fresh_epoch_after_compromise`) and three incomplete
lemmas (`lock_stage_order`, `initial_resume_serialized`,
`resume_serialized`). Tamarin 1.12.0 / Maude 3.5.1 verified **55/55**, with
zero falsifications and exit 0:

```sh
tamarin-prover docs/spec/models/ratchet.spthy \
  --defines=DISCLOSURE_SOURCES --quit-on-warning \
  --derivcheck-timeout=60 --output-module=msr --output=<temp>/assembled.spthy
# Retain every complete all-traces lemma from the native export.
tamarin-prover <temp>/safety-only.spthy \
  --quit-on-warning --derivcheck-timeout=60 --prove
```

Native export SHA-256:
`bb6fe829ea9ad09102fc0d3157717038875c134a615304c8651c35b058af295e`;
selected context SHA-256:
`d24e2a23faf2c8f0ec31e68a606643661832119f0e9ed63b1117ab5c5e04aacb`.
The context was assembled in a temporary directory and is not a CI gate.
This is not a full-theory count: excluded lemmas remain unproven in this
context, and the current profile still has 16 refined `Reveal_SS` residual
chains. The full assembled-theory run remains inconclusive.
