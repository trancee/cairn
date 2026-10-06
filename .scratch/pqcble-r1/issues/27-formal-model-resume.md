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

2026-10-05: Reopened after the conservative public-`pairID` correction.
The historical answer below describes the earlier model, which hid `pairID`.
Current base and DESYNC profiles verify (11/11 in 45 s; 12/12 in 97 s), but
KCI re-verification is incomplete: `ck_secret`, `cur_secret`, and
`I_key_secrecy` timed out at 300 s. KCI+DESYNC has not been re-verified.
This is not a falsified lemma or a new protocol attack. The implementation
gate remains closed until the corrected model fully verifies.

2026-10-05, bounded proof progress: added `DerivedCK` trace actions and
KCI-only reusable lemmas `derived_ck_origin` and
`derived_ck_predecessor` (`heuristic=C`). This is instrumentation, not a
protocol or attacker change. The command
`python3 /tmp/tprove.py docs/spec/models/resume.spthy 30 derived_ck_origin,derived_ck_predecessor,ck_secret,cur_secret -D=KCI`
independently verified both helpers (108 and 1246 steps) and the secrecy
lemmas (24 and 40 steps). `I_key_secrecy` still times out at 30 s.
KCI+DESYNC's predecessor helper also times out at 30 s; any downstream
proof using it remains conditional until it independently verifies.
Neither profile clears the gate. Experimental agreement reuse was
removed after it did not improve proof search.

2026-10-05: Added `SessionKeys` trace instrumentation and
`session_key_origin`. The helper independently verifies in KCI and
KCI+DESYNC (239 steps each), explicitly hiding all prior reusable
helpers. It proves that either session key requires earlier knowledge
of its input chain key; it does not by itself prove forward secrecy.
Fresh 30 s KCI runs still time out for `I_key_secrecy` and now also for
`derived_ck_predecessor`. Earlier successful predecessor results are
historical; current downstream results remain conditional until all
dependencies verify in the retained model. Experimental state-origin
and session-secrecy helper-hiding changes were removed when they failed
to improve the search. The gate remains closed.

## Answer

Re-verification completed after the public-`pairID` correction. Every
lemma, including every reused helper, verifies in full-file runs:

| Profile | Command flags | Current result | Time |
|---|---|---|---|
| Base | none | 16/16 verified | 8.6 s |
| Desync | `-D=DESYNC` | 17/17 verified | 21.4 s |
| KCI | `-D=KCI` | 19/19 verified | 25.5 s |
| KCI + desync | `-D=KCI -D=DESYNC` | 20/20 verified | 36.3 s |

Run `tamarin-prover --prove docs/spec/models/resume.spthy` with the
listed flags. All four runs passed wellformedness. Counts grew because
of independently proved provenance helpers, not new security assumptions.
The OI-16 reflection counterexample still reproduces (152 steps); the
OI-18 no-compromise `ciphertext_substitution` witness verifies (19 steps).
The latter hides reusable helpers to avoid assuming agreement in the
vulnerable profile. Both regressions complete within 30 s.

The Resume model gate is restored. The composed ratchet gate remains
closed until *Formal model: PQ ratchet mixing* resolves.

Historical result before the public-`pairID` correction: Tamarin model [`docs/spec/models/resume.spthy`](../../../docs/spec/models/resume.spthy); current commands, timings and abstractions are in [`docs/spec/models/README.md`](../../../docs/spec/models/README.md). The spec was draft 0.3 at initial resolution.

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
