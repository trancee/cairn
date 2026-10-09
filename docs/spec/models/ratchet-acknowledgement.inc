/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma acknowledgement_input [heuristic={durable_ack},
                             hide_lemma=declared_session_secret, hide_lemma=initial_ck_secret,
                             hide_lemma=ck_secret, hide_lemma=cur_secret,
                             hide_lemma=derived_ck_origin, hide_lemma=derived_ck_predecessor,
                             hide_lemma=ratchet_key_origin, hide_lemma=session_key_origin,
                             hide_lemma=extract_origin, hide_lemma=fresh_dk_origin,
                             hide_lemma=fresh_ss_origin, hide_lemma=kem_ciphertext_origin,
                             hide_lemma=ratchet_key_reveal_owner]:
  all-traces
  "∀ pid r %e kind pos ks kr #i.
    ((Ack( pid, r, %e, kind, pos ) @ #i) ∧
     (SessionUse( pid, r, ks, kr ) @ #i)) ⇒
    (∃ #j. (K( senc(<'PROGRESS', %e, kind, pos>, kr) ) @ #j) ∧ (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e kind pos ks kr #i.
  (Ack( pid, r, %e, kind, pos ) @ #i) ∧ (SessionUse( pid, r, ks, kr ) @ #i)
 ∧
  ∀ #j. (K( senc(<'PROGRESS', %e, kind, pos>, kr) ) @ #j) ⇒ ¬(#j < #i)"
*/
simplify
solve( Ack( pid, r, %e, kind, pos ) @ #i )
  case Receive_progress_CT
  solve( SessionUse( pid, r, ks.1, kr.1 ) @ #i )
    case Receive_progress_CT
    by contradiction /* from formulas */
  qed
next
  case Receive_progress_EK
  solve( SessionUse( pid, r, ks.1, kr.1 ) @ #i )
    case Receive_progress_EK
    by contradiction /* from formulas */
  qed
next
  case Receive_progress_full
  solve( SessionUse( pid, r, ks.1, kr.1 ) @ #i )
    case Receive_progress_full
    by contradiction /* from formulas */
  qed
qed

/* All wellformedness checks were successful. */

/*
Generated from:
Tamarin version 1.12.0
Maude version 3.5.1
Git revision: UNKNOWN, branch: UNKNOWN
Compiled at: 2026-03-08 09:49:47.765662 UTC
*/

lemma acknowledgement_session [reuse]:
  all-traces
  "∀ pid r %e kind pos #i.
    (Ack( pid, r, %e, kind, pos ) @ #i) ⇒
    (∃ ks kr #j.
      ((SessionUse( pid, r, ks, kr ) @ #i) ∧
       (!KU( senc(<'PROGRESS', %e, kind, pos>, kr) ) @ #j)) ∧
      (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e kind pos #i.
  (Ack( pid, r, %e, kind, pos ) @ #i)
 ∧
  ∀ ks kr #j.
   (SessionUse( pid, r, ks, kr ) @ #i) ∧
   (!KU( senc(<'PROGRESS', %e, kind, pos>, kr) ) @ #j)
  ⇒
   ¬(#j < #i)"
*/
simplify
solve( Ack( pid, r, %e, kind, pos ) @ #i )
  case Receive_progress_CT
  by contradiction /* from formulas */
next
  case Receive_progress_EK
  by contradiction /* from formulas */
next
  case Receive_progress_full
  by contradiction /* from formulas */
qed

/* All wellformedness checks were successful. */

/*
Generated from:
Tamarin version 1.12.0
Maude version 3.5.1
Git revision: UNKNOWN, branch: UNKNOWN
Compiled at: 2026-03-08 09:49:47.765662 UTC
*/
