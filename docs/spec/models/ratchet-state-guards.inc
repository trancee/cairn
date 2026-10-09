/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma erased_is_retired [reuse]:
  all-traces
  "∀ pid r ck #i.
    (ErasedBranch( pid, r, ck ) @ #i) ⇒ (Retire( pid, r, ck ) @ #i)"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ck #i.
  (ErasedBranch( pid, r, ck ) @ #i) ∧ ¬(Retire( pid, r, ck ) @ #i)"
*/
simplify
solve( ErasedBranch( pid, r, ck ) @ #i )
  case I_S2_classic_case_1
  by contradiction
next
  case I_S2_classic_case_2
  by contradiction
next
  case I_S2_classic_recovery_candidate_case_1
  by contradiction /* from formulas */
next
  case I_S2_classic_recovery_candidate_case_2
  by contradiction /* from formulas */
next
  case I_S2_mix_case_1
  by contradiction
next
  case I_S2_mix_case_2
  by contradiction
next
  case R_Data_advance_epoch_case_1
  by contradiction
next
  case R_Data_advance_epoch_case_2
  by contradiction
next
  case R_Data_recovery_candidate_case_1
  by contradiction
next
  case R_Data_recovery_candidate_case_2
  by contradiction
next
  case R_Data_same_epoch_case_1
  by contradiction
next
  case R_Data_same_epoch_case_2
  by contradiction
next
  case R_Timeout
  by contradiction
next
  case R_Timeout_recovery_candidate
  by contradiction
qed

lemma erased_branch_unusable [heuristic={lifecycle}]:
  all-traces
  "∀ pid r ck #i #j.
    ((ErasedBranch( pid, r, ck ) @ #i) ∧ (Cur( pid, r, ck ) @ #j)) ⇒
    ((#j < #i) ∨ (#j = #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ck #i #j.
  (ErasedBranch( pid, r, ck ) @ #i) ∧ (Cur( pid, r, ck ) @ #j)
 ∧
  (¬(#j < #i)) ∧ (¬(#j = #i))"
*/
simplify
solve( (#j = #i)  ∥ (#i < #j) )
  case case_1
  by contradiction
next
  case case_2
  by contradiction
qed

lemma monotonic_epochs [hide_lemma=fresh_dk_origin,
                        hide_lemma=fresh_ss_origin]:
  all-traces
  "∀ pid r %e n #i. (Advance( pid, r, %e, n ) @ #i) ⇒ (n = (%e%+%1))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e n #i. (Advance( pid, r, %e, n ) @ #i) ∧ ¬(n = (%e%+%1))"
*/
simplify
solve( Advance( pid, r, %e, n ) @ #i )
  case I_S2_classic_recovery_candidate
  by contradiction /* from formulas */
next
  case I_S2_mix
  by contradiction
next
  case R_Data_advance_epoch
  by contradiction
next
  case R_Data_recovery_candidate
  by contradiction /* from formulas */
qed

lemma no_rollback [hide_lemma=fresh_dk_origin,
                   hide_lemma=fresh_ss_origin, hide_lemma=derived_ck_origin,
                   hide_lemma=derived_ck_predecessor, hide_lemma=ck_secret,
                   hide_lemma=cur_secret, hide_lemma=epoch_secret,
                   hide_lemma=mixed_key_origin]:
  all-traces
  "∀ pid r %e n #i #j.
    ((Advance( pid, r, %e, n ) @ #i) ∧ (EUse( pid, r, %e ) @ #j)) ⇒
    ((#j < #i) ∨ (#j = #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e n #i #j.
  (Advance( pid, r, %e, n ) @ #i) ∧ (EUse( pid, r, %e ) @ #j)
 ∧
  (¬(#j < #i)) ∧ (¬(#j = #i))"
*/
simplify
solve( (#j = #i)  ∥ (#i < #j) )
  case case_1
  by contradiction
next
  case case_2
  by contradiction
qed

lemma no_classical_downgrade [hide_lemma=fresh_dk_origin,
                              hide_lemma=fresh_ss_origin, hide_lemma=derived_ck_origin,
                              hide_lemma=derived_ck_predecessor, hide_lemma=ck_secret,
                              hide_lemma=cur_secret, hide_lemma=epoch_secret,
                              hide_lemma=mixed_key_origin]:
  all-traces
  "∀ pid r %e #i #j.
    (((Ready( pid, r, %e ) @ #i) ∧ (ClassicStart( pid, r, %e ) @ #j)) ∧
     (#i < #j)) ⇒
    (∃ n #k. (Advance( pid, r, %e, n ) @ #k) ∧ (#k < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e #i #j.
  (Ready( pid, r, %e ) @ #i) ∧ (ClassicStart( pid, r, %e ) @ #j)
 ∧
  (#i < #j) ∧ (∀ n #k. (Advance( pid, r, %e, n ) @ #k) ⇒ ¬(#k < #j))"
*/
simplify
by contradiction
