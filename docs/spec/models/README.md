# Formal models

Symbolic models of `pqcble-r1` ([spec](../pqcble-r1.md)). Under the strict formal-model gate (ticket *Implementation slicing*), a slice that implements a modelled flow starts only after its model verifies.

| Model | Spec | Status |
|---|---|---|
| [`resume.spthy`](resume.spthy) | §6 Resume | Verified (draft 0.3) |
| PQ ratchet mixing | §9 | Not started |
| SAS pairing | §5 | Not started |

## Tooling

- Tamarin prover 1.12.0 with Maude 3.5.1, from the `tamarin-prover/tap` Homebrew tap: `brew install tamarin-prover/tap/tamarin-prover`.
- On macOS, Homebrew may first require `brew trust --formula` for `tamarin-prover/tap/tamarin-prover`, `tamarin-prover/tap/maude` and `tamarin-prover/tap/libbuddy`.

## Resume (`resume.spthy`)

Run from this directory:

| Command | Profile | Expected | Time (Apple silicon) |
|---|---|---|---|
| `tamarin-prover --prove resume.spthy` | Spec §6, draft 0.3 | 11 lemmas verified | ≈ 9 s |
| `tamarin-prover --prove -D=DESYNC resume.spthy` | Plus R's two-candidate desync recovery | 12 lemmas verified | ≈ 24 s |
| `tamarin-prover --prove -D=KCI resume.spthy` | KCI profile (static ML-KEM keys) | 13 lemmas verified | ≈ 10 s |
| `tamarin-prover --prove -D=KCI -D=DESYNC resume.spthy` | KCI profile plus desync recovery | 14 lemmas verified | ≈ 32 s |
| `tamarin-prover --prove=I_agreement --prove=reflection_resistance --stop-on-trace=BFS -D=UNBOUND resume.spthy` | Draft 0.2 (no pairing role in `K_id`/`K_auth_I`) | Both falsified: reflection attack (OI-16) | ≈ 2 min |
| `tamarin-prover --prove=kci_I_agreement -D=KCI -D=KCI_UNBOUND resume.spthy` | KCI profile with `th_s = H(S1 ‖ eR)` (no `ct_I`) | Falsified: `ct_I` substitution desyncs the pair (OI-18) | ≈ 40 s |

`--stop-on-trace=BFS` is required for `UNBOUND`. Depth-first search does not find the attack in reasonable time.

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
| KCI | Agreement holds even after `CK_n` and the victim's own static key leak; only a reveal of the peer's static key before the session breaks it | `kci_I_agreement`, `kci_R_agreement` (`-D=KCI`) | Verified; **falsified without `ct_I` in `th_s`** (OI-18) |

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

### Modelling notes

The first versions did not terminate. Every lemma timed out, because state-copy rules (reveal, abort, timeout) formed loops in backward search. The fixes, in case they're useful for the other models:

1. **Persistent state plus restrictions** (`Cur` / `Retire`) instead of linear facts that rules consume and re-produce.
2. **State keyed by pairing role.** Names come from a `!Party` fact created at `Pair`, so identities sit one step from `Pair` instead of behind the whole Resume history.
3. **Secrecy helper split in two:**
   - an inductive lemma on key creation (`CK`);
   - a non-inductive bridge lemma on key use (`Cur`) that other proofs can apply.
4. **No `[reuse]` on agreement lemmas.** Each instance pulls in more history.
5. **Pinned `exists-trace` lemmas.** Pin them to the first Resume after `Pair`, and exclude irrelevant behaviour (for example, B never initiates).
