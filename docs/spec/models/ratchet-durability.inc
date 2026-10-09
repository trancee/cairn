/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma progress_is_durable [heuristic={durable_ack},
                           hide_lemma=declared_session_secret, hide_lemma=initial_ck_secret,
                           hide_lemma=ck_secret, hide_lemma=cur_secret,
                           hide_lemma=derived_ck_origin, hide_lemma=derived_ck_predecessor,
                           hide_lemma=ratchet_key_origin, hide_lemma=session_key_origin,
                           hide_lemma=extract_origin, hide_lemma=fresh_dk_origin,
                           hide_lemma=fresh_ss_origin, hide_lemma=kem_ciphertext_origin,
                           hide_lemma=ratchet_key_reveal_owner]:
  all-traces
  "∀ pid r %e kind pos #i.
    (Ack( pid, r, %e, kind, pos ) @ #i) ⇒
    ((∃ p #j.
       ((Durable( pid, p, %e, kind, pos ) @ #j) ∧ (#j < #i)) ∧ (¬(p = r))) ∨
     (∃ #c. (RevCK( pid ) @ #c) ∧ (#c < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e kind pos #i.
  (Ack( pid, r, %e, kind, pos ) @ #i)
 ∧
  (∀ p #j.
    (Durable( pid, p, %e, kind, pos ) @ #j) ⇒ ((¬(#j < #i)) ∨ (p = r))) ∧
  (∀ #c. (RevCK( pid ) @ #c) ⇒ ¬(#c < #i))"
*/
simplify
solve( (∃ #j.1.
         (EncryptedOutput( <'PROGRESS', %e, kind, pos>, kr ) @ #j.1)
        ∧
         #j.1 < #j)  ∥
       (∃ #j.1 #l.
         (!KU( <'PROGRESS', %e, kind, pos> ) @ #j.1) ∧ (!KU( kr ) @ #l)
        ∧
         (#j.1 < #j) ∧ (#l < #j)) )
  case case_1
  solve( (#j.3 < #j.2)  ∥ (#j.3 = #j.2) )
    case case_1
    by contradiction
  next
    case case_2
    by contradiction
  qed
next
  case case_2
  by contradiction
qed
