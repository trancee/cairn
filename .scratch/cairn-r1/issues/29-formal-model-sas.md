# Formal model: SAS pairing

Type: task
Status: resolved
Blocked by: 26

## Question

Write and prove the symbolic Tamarin model of SAS commit-then-reveal pairing (P1 commits H(nA); P3 reveals nA), following the [formal-tooling research](../../../docs/research/2026-10-05-formal-model-tooling.md). Cover its 6 SAS lemmas, and add a ProVerif `weaksecret` check of the 2^-20 guessing bound.
- Put the models under `docs/spec/models/`.
- A failing lemma reopens the relevant ADR.
- This model gates implementing SAS pairing, per the formal-verification gate.

## Comments

## Answer

Tamarin model [`docs/spec/models/sas.spthy`](../../../docs/spec/models/sas.spthy) of §5 pairing (QR, SAS, TOFU and the later Verify); commands, the counting argument and abstractions are in [`docs/spec/models/README.md`](../../../docs/spec/models/README.md). Spec now draft 0.4.

| Profile | Command flags | Result | Time |
|---|---|---|---|
| Spec §5, draft 0.4 | none | 16/16 verified | ≈ 11 s |
| Draft 0.3 | `-D=MODE_FROM_P1` | `mode_integrity` falsified | ≈ 8 s |
| Mutation | `-D=NO_COMMIT` | `no_grinding_A` falsified (lemma has teeth) | ≈ 5 s |

All 6 research §8.3 properties are covered. Decisions (grilled, user accepted the recommendations):
- **OI-19, mode downgrade:** an attacker could rewrite `P1.mode` from SAS to TOFU, and B stored an Unverified contact its user never chose. Fix: B aborts unless `P1.mode` equals its user's selection; 0 bytes.
- **OI-20, roles without a QR:** in SAS/TOFU the phone whose user picks the peer is B, the picked phone is A (ADR 0009 amended).
- **ProVerif `weaksecret` dropped:** the codes derive from public `th` and `nB`, so they aren't secrets. The 2^-20 bound is a counting argument (README) over the verified no-grinding lemmas. ProVerif isn't installed and isn't needed.
