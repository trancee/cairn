# Formal models

Symbolic models of `pqcble-r1` ([spec](../pqcble-r1.md)). Under the strict formal-model gate (ticket *Implementation slicing*), a slice that implements a modelled flow starts only after its model verifies.

| Model | Spec | Status |
|---|---|---|
| [`resume.spthy`](resume.spthy) | §6 Resume | All four profiles verified with public `pairID` |
| [`ratchet.spthy`](ratchet.spthy) | §9 | Draft; not an implementation-gate proof |
| [`sas.spthy`](sas.spthy) | §5 Pairing (QR, SAS, TOFU, Verify) | Verified (draft 0.4) |

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
not evidence for the expanded model. `epoch_secret` and `pcs_epoch`
can terminate using unverified reusable helpers; such conditional
results **do not satisfy the gate**. Fresh-secret/CK origin helpers,
executability, complete epoch agreement, alternation, authenticated
progress, healing and lost-DATA recovery still need independent proofs.

Bounded experiments use `--open-chains=0 --saturation=0` to avoid source
precomputation expanding arbitrary session histories. These are search
settings, not attacker restrictions. The prefix-closed mandatory-MIX
guard removes an existential restriction from induction, but fresh DK,
fresh SS and derived-CK origin searches still hit the 30 s cap. A timeout
is neither verification nor a counterexample. No ratchet implementation
may start on this evidence.

The derivation check caught a modelling error: mixed Resume could recover
EK/CT only from their hashes. `IWait` now retains the concrete pending
secret and objects, matching the local state available at S1. A standalone
load with `tamarin-prover ratchet.spthy --open-chains=0 --saturation=0
--derivcheck-timeout=30` passes wellformedness. This does not prove lemmas.

`epoch_position_shape`, `monotonic_epochs`, `no_rollback` and
`no_classical_downgrade` have targeted proofs (5/4/4/2 steps).
The first is the initial lemma; the other three explicitly hide reusable
helpers to keep these results independent of unverified dependencies.
Reproduce those four checks from this directory:

```sh
tamarin-prover ratchet.spthy --open-chains=0 --saturation=0 --derivcheck-timeout=30 \
  --prove=epoch_position_shape --prove=monotonic_epochs \
  --prove=no_rollback --prove=no_classical_downgrade
```

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
The tested properties explicitly hide all reusable helpers; searches use
`--stop-on-trace=BFS`. Both still hit the 30 s cap; **mutation
sensitivity is not established**. `executable`, `lost_data_recovery` and
`fresh_epoch_after_compromise` are pinned witnesses, not verified traces.

The model uses zero/successor epochs, not a concrete u32 counter or
LEB128 parser. Each piece conservatively exposes the full public object
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
