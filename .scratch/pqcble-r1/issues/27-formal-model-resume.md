# Formal model: Resume

Type: task
Status: resolved
Blocked by: 26

## Question

Write and prove the symbolic Tamarin model of Resume (S1/S2 and the KCI variants), following the [formal-tooling research](../../../docs/research/2026-10-05-formal-model-tooling.md). It covers that report's 10 Resume lemmas: mutual authentication, key secrecy, forward secrecy across epochs, replay resistance, and KCI resistance in the KCI profile.
- Put the model under `docs/spec/models/`.
- A failing lemma reopens the relevant ADR.
- This model gates implementing Resume, per the formal-verification gate.

## Comments

## Answer

Tamarin model [`docs/spec/models/resume.spthy`](../../../docs/spec/models/resume.spthy); commands, timings and abstractions are in [`docs/spec/models/README.md`](../../../docs/spec/models/README.md). Spec now draft 0.3.

| Profile | Command flags | Result | Time |
|---|---|---|---|
| Base (§6) | none | 11/11 verified | ≈ 9 s |
| Desync recovery | `-D=DESYNC` | 12/12 verified | ≈ 24 s |
| KCI profile | `-D=KCI` | 13/13 verified | ≈ 10 s |
| KCI + desync | `-D=KCI -D=DESYNC` | 14/14 verified | ≈ 32 s |
| Draft 0.2 | `-D=UNBOUND`, BFS | `I_agreement`, `reflection_resistance` falsified | ≈ 2 min |
| KCI before OI-18 | `-D=KCI -D=KCI_UNBOUND` | `kci_I_agreement` falsified | ≈ 40 s |

All 10 research §8.1 properties are covered; single-use `CK_n` (property 3) is an assumption enforced by the spec's OI-17 rule.

Findings (each grilled and accepted, applied to spec §6/§13 and ADRs 0003/0005):
- **OI-16, reflection:** a relay could return A's S1 to A, which accepted a self-session and advanced `CK` alone (permanent desync). Fix: `K_id`/`K_auth_I` bind I's pairing role; 0 bytes.
- **OI-17, concurrent Resume:** both sides could initiate at once and commit different `CK`s. Fix: one Resume per contact in flight, atomic commit, pairing role A wins.
- **OI-18, KCI `ct_I`:** `th_s` did not cover `ct_I`, so swapping it desynced the pair. Fix: `th_s = H(S1 ‖ eR ‖ ct_I)` in the KCI profile; 0 bytes.

Not covered: the PQ mix (ratchet model), ephemeral-secret reveal, pseudonym unlinkability.
