/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma lock_stage_predecessor [reuse, heuristic={serialization}]:
  all-traces
  "∀ pid r %s #i.
    (LockStage( pid, r, %s ) @ #i) ⇒
    ((%s = %1) ∨
     (∃ %p #j.
       ((LockStage( pid, r, %p ) @ #j) ∧ (%s = (%p%+%1))) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %s #i.
  (LockStage( pid, r, %s ) @ #i)
 ∧
  (¬(%s = %1)) ∧
  (∀ %p #j. (LockStage( pid, r, %p ) @ #j) ∧ (%s = (%p%+%1)) ⇒ ¬(#j < #i))"
*/
simplify
solve( LockStage( pid, r, %s ) @ #i )
  case Acquire_Resume
  solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #i )
    case Pair_case_1
    by contradiction /* from formulas */
  next
    case Pair_case_2
    by contradiction /* from formulas */
  next
    case Release_Resume
    by contradiction /* from formulas */
  qed
next
  case Pair_case_1
  by contradiction /* from formulas */
next
  case Pair_case_2
  by contradiction /* from formulas */
next
  case Release_Resume
  solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #i )
    case B_Collision_Yield
    by contradiction /* from formulas */
  next
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case I_Timeout
    by contradiction /* from formulas */
  next
    case R_Data_advance_epoch
    by contradiction /* from formulas */
  next
    case R_Data_recovery_candidate
    by contradiction /* from formulas */
  next
    case R_Data_same_epoch
    by contradiction /* from formulas */
  next
    case R_Timeout
    by contradiction /* from formulas */
  next
    case R_Timeout_recovery_candidate
    by contradiction /* from formulas */
  qed
qed
