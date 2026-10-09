/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma no_partial_mix [hide_lemma=fresh_dk_origin,
                      hide_lemma=fresh_ss_origin, hide_lemma=derived_ck_origin,
                      hide_lemma=derived_ck_predecessor, hide_lemma=ck_secret,
                      hide_lemma=cur_secret, hide_lemma=epoch_secret,
                      hide_lemma=mixed_key_origin]:
  all-traces
  "∀ pid r %e ss ek ct #i.
    (MixStart( pid, r, %e, <ss, h(ek), h(ct)> ) @ #i) ⇒
    ((∃ #g #p #f.
       (((((EpGen( pid, r, %e, ek ) @ #g) ∧ (CTPrefix( pid, r, %e, ct ) @ #p)) ∧
          (ReceivedFull( pid, r, %e, 'CT' ) @ #f)) ∧
         (#g < #i)) ∧
        (#p < #f)) ∧
       (#f < #i)) ∨
     (∃ #c #p #f.
       (((((EpEnc( pid, r, %e, ek, ct, ss ) @ #c) ∧
           (EKPrefix( pid, r, %e, ek ) @ #p)) ∧
          (ReceivedFull( pid, r, %e, 'EK' ) @ #f)) ∧
         (#p < #f)) ∧
        (#f < #c)) ∧
       (#c < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e ss ek ct #i.
  (MixStart( pid, r, %e, <ss, h(ek), h(ct)> ) @ #i)
 ∧
  (∀ #g #p #f.
    (EpGen( pid, r, %e, ek ) @ #g) ∧
    (CTPrefix( pid, r, %e, ct ) @ #p) ∧
    (ReceivedFull( pid, r, %e, 'CT' ) @ #f)
   ⇒
    ((¬(#g < #i)) ∨ (¬(#p < #f)) ∨ (¬(#f < #i)))) ∧
  (∀ #c #p #f.
    (EpEnc( pid, r, %e, ek, ct, ss ) @ #c) ∧
    (EKPrefix( pid, r, %e, ek ) @ #p) ∧
    (ReceivedFull( pid, r, %e, 'EK' ) @ #f)
   ⇒
    ((¬(#p < #f)) ∨ (¬(#f < #c)) ∨ (¬(#c < #i))))"
*/
simplify
solve( !Have( pid, r, %e, <ss, h(ek), h(ct)>, ss, ek, ct
       )[no_precomp] ▶₅ #i )
  case Encapsulate
  by contradiction
next
  case Receive_CT_tail
  by contradiction
qed

lemma ek_authenticated [reuse, hide_lemma=derived_ck_origin,
                        hide_lemma=derived_ck_predecessor, hide_lemma=initial_ck_secret,
                        hide_lemma=ck_secret, hide_lemma=cur_secret,
                        hide_lemma=position_unique, hide_lemma=position_step,
                        hide_lemma=generator_unique]:
  all-traces
  "∀ pid r %e ek #i.
    (EKPrefix( pid, r, %e, ek ) @ #i) ⇒
    ((∃ p #j.
       ((EpGen( pid, p, %e, ek ) @ #j) ∧ (#j < #i)) ∧ (¬(p = r))) ∨
     (∃ #c. (RevCK( pid ) @ #c) ∧ (#c < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e ek #i.
  (EKPrefix( pid, r, %e, ek ) @ #i)
 ∧
  (∀ p #j.
    (EpGen( pid, p, %e, ek ) @ #j) ⇒ ((¬(#j < #i)) ∨ (p = r))) ∧
  (∀ #c. (RevCK( pid ) @ #c) ⇒ ¬(#c < #i))"
*/
simplify
solve( (∃ #j.
         (EncryptedOutput( <'EK', %e, 'prefix', ek>, kr ) @ #j)
        ∧
         #j < #vk)  ∥
       (∃ #j #l.
         (!KU( <'EK', %e, 'prefix', ek> ) @ #j) ∧ (!KU( kr ) @ #l)
        ∧
         (#j < #vk) ∧ (#l < #vk)) )
  case case_1
  solve( (∃ pid r other.
           (EpGen( pid, r, %e, ek ) @ #j.1) ∧
           (SessionUse( pid, r, kr, other ) @ #j.1))  ∥
         (∃ pid r other #j.2.
           (EpGen( pid, r, %e, ek ) @ #j.2) ∧
           (SessionUse( pid, r, kr, other ) @ #j.1)
          ∧
           #j.2 < #j.1) )
    case case_1
    by contradiction /* from formulas */
  next
    case case_2
    by contradiction /* from formulas */
  qed
next
  case case_2
  by contradiction /* from formulas */
qed

lemma ct_authenticated [reuse, heuristic={authenticated_transfer},
                        hide_lemma=derived_ck_origin, hide_lemma=derived_ck_predecessor,
                        hide_lemma=initial_ck_secret, hide_lemma=ck_secret,
                        hide_lemma=cur_secret, hide_lemma=position_unique,
                        hide_lemma=position_step, hide_lemma=generator_unique]:
  all-traces
  "∀ pid r %e ct #i.
    (CTPrefix( pid, r, %e, ct ) @ #i) ⇒
    ((∃ p ek ss #j.
       ((EpEnc( pid, p, %e, ek, ct, ss ) @ #j) ∧ (#j < #i)) ∧
       (¬(p = r))) ∨
     (∃ #c. (RevCK( pid ) @ #c) ∧ (#c < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e ct #i.
  (CTPrefix( pid, r, %e, ct ) @ #i)
 ∧
  (∀ p ek ss #j.
    (EpEnc( pid, p, %e, ek, ct, ss ) @ #j)
   ⇒
    ((¬(#j < #i)) ∨ (p = r))) ∧
  (∀ #c. (RevCK( pid ) @ #c) ⇒ ¬(#c < #i))"
*/
simplify
solve( (∃ #j.
         (EncryptedOutput( <'CT', %e, 'prefix', ct>, kr ) @ #j)
        ∧
         #j < #vk)  ∥
       (∃ #j #l.
         (!KU( <'CT', %e, 'prefix', ct> ) @ #j) ∧ (!KU( kr ) @ #l)
        ∧
         (#j < #vk) ∧ (#l < #vk)) )
  case case_1
  solve( (∃ pid r ek ss other.
           (EpEnc( pid, r, %e, ek, ct, ss ) @ #j.1) ∧
           (SessionUse( pid, r, kr, other ) @ #j.1))  ∥
         (∃ pid r ek ss other #j.2.
           (EpEnc( pid, r, %e, ek, ct, ss ) @ #j.2) ∧
           (SessionUse( pid, r, kr, other ) @ #j.1)
          ∧
           #j.2 < #j.1) )
    case case_1
    by contradiction /* from formulas */
  next
    case case_2
    by contradiction /* from formulas */
  qed
next
  case case_2
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
