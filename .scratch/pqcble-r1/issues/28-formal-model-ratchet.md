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

Current proof blocker: `fresh_dk_origin`, `fresh_ss_origin` and
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
