# Reviewing the residual `Reveal_SS` source chain

This brief asks for an independent Tamarin review of one representative
residual disclosure-source branch in Cairn's ratchet model. It records the
current symbolic evidence and its limits; it does not claim source closure or
authorize a ratchet implementation.

## Review boundary

The reviewed property is the soundness of a possible `[sources]` refinement
for `Reveal_SS`, using the unchanged transition system and preserving every
allowed compromise and attacker trace. The model uses Tamarin's symbolic
Dolev–Yao network semantics. This review does not establish computational
PQC security, constant-time behavior, implementation correctness, or the
combined message/natural-number theory's finite variant property.

## Representative raw source branch

The native interactive source view for theory `CairnRatchet` identified the
goal group `!KU(kdec(t.1,t.2)) @ #i`. Its third of three source cases is
`Reveal_SS`. The unresolved constraints in that case are:

```text
(#vl.7, 0) ~~> (#i, 0)
!SSValue(pid.10, t.8)[no_precomp]             from Reveal_SS
!Have(pid.10, r.10, %e.10, pq.10, t.8, ek.10, ct.10)[-, no_precomp]
                                                from Reveal_SS
```

The relevant rule is [`Reveal_SS`](../spec/models/ratchet.spthy#L149), which
outputs the shared secret from those persistent facts. The residual chain
therefore cannot be closed by treating the revealed value as fresh: the
secret's recorded provenance and the accepted ciphertext state both matter.

The two supporting source groups expose the recursive case:

| Fact being sourced | Relevant raw case | Consequence |
|---|---|---|
| `!SSValue(pid, ss)` | `Decode_known_ciphertext` (second of two cases) | The decoder stores `kdec(ct, dk)` for any network-provided `ct`; the source case leaves `!KU(ct)` and DK ownership to establish. Equation splitting includes both a KEM-shaped ciphertext and a nested `kdec(...)` ciphertext. |
| `!Have(pid, r, e, pq, ss, ek, ct)` | `Receive_CT_tail` (second of two cases) | The receiver accepts the encrypted CT tail only with its prior `CT0`, generated DK, session/key state, and incoming ciphertext. It sets `ss = kdec(ct, dk)` and records `EpDec`; the supplied `ct` is not thereby proved to have a fresh-secret payload. |

The corresponding model rules are
[`Decode_known_ciphertext`](../spec/models/ratchet.spthy#L173) and
[`Receive_CT_tail`](../spec/models/ratchet.spthy#L237). In the raw
`Receive_CT_tail` case, the source view leaves attacker knowledge of both
`senc(<'CT', e, 'half', ct>, kr)` and the matching encrypted CT prefix,
alongside `Session`, `SKValue`, and `CKValue` premises. The network inputs are
untrusted; the prefix state and local key/session premises do not constrain
the origin or internal structure of `ct`.

These cases are linked by the current model facts and equations, not by an
assumption that decoded values are fresh. An attacker may supply an
arbitrary, nested ciphertext, and may know a complete KEM ciphertext while
not knowing its plaintext.

## Reproducible evidence

The evidence below was observed with Tamarin 1.12.0 and Maude 3.5.1 on
macOS/Apple silicon. The UI's theory and case indexes are runtime-assigned;
the route used for this inspection is not a stable interface.

From the repository root:

```sh
tamarin-prover docs/spec/models/ratchet.spthy \
  --defines=DISCLOSURE_SOURCES --quit-on-warning \
  --precompute-only --derivcheck-timeout=60
python3 docs/spec/models/replay.py \
  --disclosure-sources --target kem_ciphertext_origin --timeout 180
```

The profile precomputation reports 43 source groups, 30 raw residual chains,
and 15 refined residual chains, all in `Reveal_SS` cases. The exact-source
replay verifies `ck_disclosure_origin` (12 steps),
`ss_disclosure_origin` (8), `kem_ciphertext_origin` (18), and
`dk_reveal_owner` (9). Its native source SHA-256 is
`5dae43d3a8c03b0e566aa2c577cbde0f8f1a8bd5663fc1aa5134733887cc0625`;
the selected replay SHA-256 is
`f25a04c6da03133bdecca47f2ba519ec38763b6bdaf1aa421f80c5a8f6f6e91c`.
The source inventory and candidate experiments are recorded in
[`ratchet-source-evidence.md`](../spec/models/ratchet-source-evidence.md).

Prior attempts do not close the branch:

- A candidate omitting the fresh-secret alternative was falsified in eight
  steps: encapsulation exposes the KEM ciphertext, and an attacker can wrap
  it with a known symmetric key while its secret remains unknown.
- Shape-specific ciphertext-origin candidates that included fresh-secret
  and prior-knowledge alternatives timed out; these are inconclusive, not
  counterexamples.
- Promoting `encrypted_origin` to `[sources]` increased refined residuals
  from 15 to 765. Adding a prior-`RevSS` alternative to a KEM-origin
  candidate left 30 raw but 19 refined residuals and timed out. Neither
  candidate was retained.
- `--auto-sources` left the counts at 30 raw / 15 refined and emitted no
  `AUTO_typing` lemma. Removing the `!SSValue` guard moved the residual to
  `!Have` without changing those counts.
- A separate `[sources]` candidate asserting prior `KU(ct)` for each
  `EpDec(..., ct, ...)` event also remained inconclusive: precomputation
  stayed at 30 raw / 15 refined chains, and automatic proof search timed out
  at 240 seconds with default settings and 180 seconds with each of
  `--heuristic=O` and `--heuristic=I`.

The complete command outcomes and limitations are in the source inventory.
No protocol rule, restriction, attacker capability, or persisted proof
certificate was changed by these experiments.

One narrow supporting fact is now independently certified:
`encrypted_ct_tail_encapsulated` proves in four steps that an honest
outgoing CT half-tail follows an `EpEnc` event for the same ciphertext. It
does not characterize arbitrary incoming ciphertext; the 15 residual
`Reveal_SS` chains remain. The default and disclosure-profile exact-source
replays are documented in the source inventory. Its replay is included in
the local `REPLAY=1` gate and a separate lifecycle workflow matrix job.

## Questions for independent review

1. Is there a sound raw-source lemma for this branch, using only the existing
   transition system and restrictions, that preserves arbitrary attacker-
   supplied and nested `ct` terms, including a public KEM ciphertext whose
   plaintext remains unknown?
2. Can existing `EpDec`, `FreshSS`, `RevSS`, or ciphertext-output events bind
   the required payload origin without excluding allowed compromise traces or
   treating a decapsulation result as fresh? If so, what is the minimal
   source formula and proof structure?
3. Does the relationship between the persistent `SSValue` ghost fact and
   `Have` state admit a sound proof-only refinement, or would changing that
   bookkeeping require a separate semantic-equivalence argument?
4. What exact raw-source replay and dependent-certificate checks would be
   needed to accept such a refinement?

The separate combined-equation/FVP review and full assembled-context replay
remain open. Even a successful review of this branch would not by itself
close those gates or establish the ratchet model's full verification.
