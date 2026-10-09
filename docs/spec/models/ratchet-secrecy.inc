/* Generated from Tamarin 1.12.0's verified default-model proof export. */

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-initial-ck-secret.inc"
#else
lemma initial_ck_secret [reuse, use_induction, heuristic={key_birth}]:
  all-traces
  "∀ pid ck #i #j.
    ((Init( pid, ck ) @ #i) ∧ (!KU( ck ) @ #j)) ⇒
    (∃ #r. (RevCK( pid ) @ #r) ∧ (#r < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ck #i #j.
  (Init( pid, ck ) @ #i) ∧ (!KU( ck ) @ #j)
 ∧
  ∀ #r. (RevCK( pid ) @ #r) ⇒ ¬(#r < #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( !KU( ~ck ) @ #j )
    case Reveal_CK
    solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr )
      case I_S2_classic
      by solve( (#vl, 0) ~~> (#j, 0) )
    next
      case I_S2_classic_recovery_candidate
      solve( splitEqs(1) )
        case split_case_1
        by solve( (#vl, 0) ~~> (#j, 0) )
      next
        case split_case_2
        by solve( (#vl, 0) ~~> (#j, 0) )
      next
        case split_case_3
        by solve( (#vl, 0) ~~> (#j, 0) )
      qed
    next
      case I_S2_mix
      by solve( (#vl, 0) ~~> (#j, 0) )
    next
      case Pair
      solve( (#vl, 0) ~~> (#j, 0) )
        case Var_fresh_1_ck
        by contradiction
      qed
    next
      case R_S2_classic
      by solve( (#vl, 0) ~~> (#j, 0) )
    next
      case R_S2_mix
      by solve( (#vl, 0) ~~> (#j, 0) )
    qed
  next
    case Reveal_SS
    solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr )
      case Decode_known_ciphertext
      solve( splitEqs(1) )
        case split_case_1
        by solve( (#vl, 0) ~~> (#j, 0) )
      next
        case split_case_2
        solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
               (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
          case case_1
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case case_2
          by contradiction
        qed
      qed
    next
      case Prepare_encapsulation
      by solve( (#vl, 0) ~~> (#j, 0) )
    qed
  qed
qed
#endif

lemma ck_secret [reuse, use_induction]:
  all-traces
  "∀ pid ck #i #j.
    ((CK( pid, ck ) @ #i) ∧ (!KU( ck ) @ #j)) ⇒
    (∃ #r. (RevCK( pid ) @ #r) ∧ (#r < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ck #i #j.
  (CK( pid, ck ) @ #i) ∧ (!KU( ck ) @ #j)
 ∧
  ∀ #r. (RevCK( pid ) @ #r) ⇒ ¬(#r < #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (last(#i))  ∥
         (∃ #r. (RevCK( pid ) @ #r) ∧ (¬(last(#r))) ∧ (#r < #j)) )
    case case_1
    solve( CK( pid, ck ) @ #i )
      case I_S2_classic
      solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
             (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
        case case_1
        by contradiction
      next
        case case_2
        by contradiction
      qed
    next
      case I_S2_classic_recovery_candidate
      solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
             (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
        case case_1
        by contradiction /* from formulas */
      next
        case case_2
        by contradiction /* from formulas */
      qed
    next
      case I_S2_mix
      solve( splitEqs(0) )
        case split_case_1
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_2
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_3
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      qed
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
             (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
        case case_1
        by contradiction
      next
        case case_2
        by contradiction
      qed
    next
      case R_S2_mix
      solve( splitEqs(0) )
        case split_case_1
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_2
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_3
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      qed
    qed
  next
    case case_2
    solve( CK( pid, ck ) @ #i )
      case I_S2_classic
      solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
             (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
        case case_1
        by contradiction
      next
        case case_2
        by contradiction
      qed
    next
      case I_S2_classic_recovery_candidate
      solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
             (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
        case case_1
        by contradiction /* from formulas */
      next
        case case_2
        by contradiction /* from formulas */
      qed
    next
      case I_S2_mix
      solve( splitEqs(0) )
        case split_case_1
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_2
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_3
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j.1)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      qed
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
             (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
        case case_1
        by contradiction
      next
        case case_2
        by contradiction
      qed
    next
      case R_S2_mix
      solve( splitEqs(0) )
        case split_case_1
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_2
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case split_case_3
        solve( (∃ #k. (!KU( ck ) @ #k) ∧ #k < #j)  ∥
               (∃ #r. (RevCK( pid ) @ #r) ∧ #r < #j) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      qed
    qed
  next
    case case_3
    by contradiction
  qed
qed

lemma cur_secret [reuse]:
  all-traces
  "∀ pid r ck #i #j.
    ((Cur( pid, r, ck ) @ #i) ∧ (!KU( ck ) @ #j)) ⇒
    (∃ #d. (RevCK( pid ) @ #d) ∧ (#d < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ck #i #j.
  (Cur( pid, r, ck ) @ #i) ∧ (!KU( ck ) @ #j)
 ∧
  ∀ #d. (RevCK( pid ) @ #d) ⇒ ¬(#d < #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (last(#i))  ∥
         (∃ #d. (RevCK( pid ) @ #d) ∧ (¬(last(#d))) ∧ (#d < #j)) )
    case case_1
    solve( Cur( pid, r, ck ) @ #i )
      case B_Collision_Yield
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Encapsulate
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Generate_EK
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case I_S1_classic
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case I_S1_mix
      solve( !CKValue( pid, ck )[no_precomp] ▶₇ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case R_Data_advance_epoch
      solve( splitEqs(0) )
        case split_case_1
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_2
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_3
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case R_Data_recovery_candidate
      solve( splitEqs(0) )
        case split_case_1
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_2
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_3
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case R_Data_same_epoch
      solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    next
      case R_Timeout
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_Timeout_recovery_candidate
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_CT_duplicate_prefix_complete
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_CT_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_CT_tail
      solve( splitEqs(0) )
        case split_case_1
        solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_2
        solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case Receive_DONE
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_EK_duplicate_prefix_complete
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_EK_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_EK_tail
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_progress_CT
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_progress_EK
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_progress_full
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_CT_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_CT_progress_full
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_CT_progress_half
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_EK_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_EK_progress_full
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_EK_progress_half
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Reveal_CK
      solve( !CKValue( pid, ck )[no_precomp] ▶₀ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Send_CT_tail
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Send_EK_tail
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    qed
  next
    case case_2
    solve( Cur( pid, r, ck ) @ #i )
      case B_Collision_Yield
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Encapsulate
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Generate_EK
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case I_S1_classic
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case I_S1_mix
      solve( !CKValue( pid, ck )[no_precomp] ▶₇ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case R_Data_advance_epoch
      solve( splitEqs(0) )
        case split_case_1
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_2
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_3
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case R_Data_recovery_candidate
      solve( splitEqs(0) )
        case split_case_1
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_2
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_3
        solve( !CKValue( pid, ck )[no_precomp] ▶₆ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case R_Data_same_epoch
      solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    next
      case R_Timeout
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_Timeout_recovery_candidate
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_CT_duplicate_prefix_complete
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_CT_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_CT_tail
      solve( splitEqs(0) )
        case split_case_1
        solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      next
        case split_case_2
        solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
          case I_S2_classic
          by contradiction
        next
          case I_S2_classic_recovery_candidate
          by contradiction /* from formulas */
        next
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case Receive_DONE
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_EK_duplicate_prefix_complete
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_EK_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₅ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_EK_tail
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_progress_CT
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_progress_EK
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Receive_progress_full
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_CT_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_CT_progress_full
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_CT_progress_half
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_EK_prefix
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_EK_progress_full
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Resend_EK_progress_half
      solve( !CKValue( pid, ck )[no_precomp] ▶₃ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Reveal_CK
      solve( !CKValue( pid, ck )[no_precomp] ▶₀ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Send_CT_tail
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case Send_EK_tail
      solve( !CKValue( pid, ck )[no_precomp] ▶₄ #i )
        case I_S2_classic
        by contradiction
      next
        case I_S2_classic_recovery_candidate
        by contradiction /* from formulas */
      next
        case I_S2_mix
        by contradiction
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    qed
  next
    case case_3
    by contradiction
  qed
qed

lemma declared_session_secret [reuse]:
  all-traces
  "∀ pid r ks kr key #i #j.
    (((KeyDeclared( pid, r, ks, kr ) @ #i) ∧ (!KU( key ) @ #j)) ∧
     ((key = ks) ∨ (key = kr))) ⇒
    (∃ #d. (RevCK( pid ) @ #d) ∧ (#d < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ks kr key #i #j.
  (KeyDeclared( pid, r, ks, kr ) @ #i) ∧ (!KU( key ) @ #j)
 ∧
  (((key = ks) ∨ (key = kr))) ∧ (∀ #d. (RevCK( pid ) @ #d) ⇒ ¬(#d < #j))"
*/
simplify
solve( (key = ks)  ∥ (key = kr) )
  case case_1
  solve( KeyDeclared( pid, r, key, kr ) @ #i )
    case I_S2_classic
    by contradiction
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction
  next
    case R_S2_classic
    by contradiction
  next
    case R_S2_mix
    by contradiction
  qed
next
  case case_2
  solve( KeyDeclared( pid, r, ks, key ) @ #i )
    case I_S2_classic
    by contradiction
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction
  next
    case R_S2_classic
    by contradiction
  next
    case R_S2_mix
    by contradiction
  qed
qed

lemma directional_key_ownership [reuse,
                                 heuristic={authenticated_transfer}]:
  all-traces
  "∀ pid q r p outgoing incoming other #i #j.
    ((KeyDeclared( pid, r, outgoing, incoming ) @ #i) ∧
     (KeyDeclared( q, p, incoming, other ) @ #j)) ⇒
    ((pid = q) ∧ (¬(r = p)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid q r p outgoing incoming other #i #j.
  (KeyDeclared( pid, r, outgoing, incoming ) @ #i) ∧
  (KeyDeclared( q, p, incoming, other ) @ #j)
 ∧
  ((¬(pid = q)) ∨ (r = p))"
*/
simplify
solve( KeyDeclared( pid, r, outgoing, incoming ) @ #i )
  case I_S2_classic
  solve( KeyDeclared( q, p.1,
                      kdf(ext(ck, <x, y, 'none'>), 'skR',
                          <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                      other
         ) @ #j.1 )
    case R_S2_classic
    by solve( !Party( pid, r, r )[no_precomp] ▶₁ #j )
  qed
next
  case I_S2_classic_recovery_candidate
  solve( splitEqs(0) )
    case split_case_1
    solve( (¬(y = other))  ∥ (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
      case case_1
      solve( (¬(mac(kdf(ck, 'authR', pid),
                    <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>) =
                other))  ∥
             (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.2) )
        case case_1
        solve( (¬(<y, 
                   mac(kdf(ck, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        qed
      next
        case case_2
        solve( (¬(<y, 
                   mac(kdf(ck, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        qed
      qed
    next
      case case_2
      solve( (¬(mac(kdf(ck, 'authR', pid),
                    <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>) =
                other))  ∥
             (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.2) )
        case case_1
        solve( (¬(<y, 
                   mac(kdf(ck.1, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        qed
      next
        case case_2
        solve( (¬(<y, 
                   mac(kdf(ck.1, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₆ #i )
          qed
        qed
      qed
    qed
  next
    case split_case_2
    solve( (¬(y = other))  ∥ (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
      case case_1
      solve( (¬(mac(kdf(ck, 'authR', pid),
                    <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>) =
                other))  ∥
             (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.2) )
        case case_1
        solve( (¬(<y, 
                   mac(kdf(ck, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, r.1, r.1 )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      next
        case case_2
        solve( (¬(<y, 
                   mac(kdf(ck, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      qed
    next
      case case_2
      solve( (¬(mac(kdf(ck, 'authR', pid),
                    <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>) =
                other))  ∥
             (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.2) )
        case case_1
        solve( (¬(<y, 
                   mac(kdf(ck.1, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      next
        case case_2
        solve( (¬(<y, 
                   mac(kdf(ck.1, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      qed
    qed
  next
    case split_case_3
    solve( (¬(y = other))  ∥ (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
      case case_1
      solve( (¬(mac(kdf(ck, 'authR', pid),
                    <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>) =
                other))  ∥
             (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.2) )
        case case_1
        solve( (¬(<y, 
                   mac(kdf(ck, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, r.1, r.1 )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      next
        case case_2
        solve( (¬(<y, 
                   mac(kdf(ck, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      qed
    next
      case case_2
      solve( (¬(mac(kdf(ck, 'authR', pid),
                    <'S2', h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>) =
                other))  ∥
             (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.2) )
        case case_1
        solve( (¬(<y, 
                   mac(kdf(ck.1, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      next
        case case_2
        solve( (¬(<y, 
                   mac(kdf(ck.1, 'authR', pid),
                       <'S2', h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>)
                  > =
                  other))  ∥
               (∃ #d. (RevCK( q ) @ #d) ∧ #d < #vk.1) )
          case case_1
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        next
          case case_2
          solve( KeyDeclared( q, p.1,
                              kdf(ext(ck.1, <x, y, 'none'>), 'skR',
                                  <pid, h(<<'S1', '0', kdf(ck.1, <'id', r.1>, pid), x>, y>)>),
                              other
                 ) @ #j.1 )
            case R_S2_classic
            solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
              case Pair
              by solve( !Party( ~pid, p, p )[no_precomp] ▶₁ #j )
            qed
          qed
        qed
      qed
    qed
  qed
next
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( KeyDeclared( q, p.1,
                        kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skR',
                            <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>),
                        other
           ) @ #j.1 )
      case R_S2_mix
      solve( splitEqs(4) )
        case split_case_1
        by solve( !Party( pid, g, flip(g) )[no_precomp] ▶₆ #i )
      next
        case split_case_2
        by solve( !Party( pid, g, flip(g) )[no_precomp] ▶₆ #i )
      next
        case split_case_3
        by solve( !Party( pid, g, flip(g) )[no_precomp] ▶₆ #i )
      qed
    qed
  next
    case split_case_2
    solve( KeyDeclared( q, p.1,
                        kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skR',
                            <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>),
                        other
           ) @ #j.1 )
      case R_S2_mix
      solve( splitEqs(4) )
        case split_case_1
        solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
          case Pair
          by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
        qed
      next
        case split_case_2
        solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
          case Pair
          by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
        qed
      next
        case split_case_3
        solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
          case Pair
          by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
        qed
      qed
    qed
  next
    case split_case_3
    solve( KeyDeclared( q, p.1,
                        kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skR',
                            <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>),
                        other
           ) @ #j.1 )
      case R_S2_mix
      solve( splitEqs(4) )
        case split_case_1
        solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
          case Pair
          by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
        qed
      next
        case split_case_2
        solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
          case Pair
          by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
        qed
      next
        case split_case_3
        solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
          case Pair
          by solve( !Party( ~pid, r, r )[no_precomp] ▶₁ #j )
        qed
      qed
    qed
  qed
next
  case R_S2_classic
  solve( KeyDeclared( q, p.1,
                      kdf(ext(ck, <x, ~y, 'none'>), 'skI',
                          <pid, h(<<'S1', '0', kdf(ck, <'id', p>, pid), x>, ~y>)>),
                      other
         ) @ #j )
    case I_S2_classic
    by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
  next
    case I_S2_classic_recovery_candidate
    solve( splitEqs(1) )
      case split_case_1
      by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
    next
      case split_case_2
      by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
    next
      case split_case_3
      by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
    qed
  qed
next
  case R_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( KeyDeclared( q, p.1,
                        kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'skI',
                            <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>),
                        other
           ) @ #j )
      case I_S2_mix
      solve( splitEqs(2) )
        case split_case_1
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      next
        case split_case_2
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      next
        case split_case_3
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      qed
    qed
  next
    case split_case_2
    solve( KeyDeclared( q, p.1,
                        kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'skI',
                            <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>),
                        other
           ) @ #j )
      case I_S2_mix
      solve( splitEqs(2) )
        case split_case_1
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      next
        case split_case_2
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      next
        case split_case_3
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      qed
    qed
  next
    case split_case_3
    solve( KeyDeclared( q, p.1,
                        kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'skI',
                            <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>),
                        other
           ) @ #j )
      case I_S2_mix
      solve( splitEqs(2) )
        case split_case_1
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      next
        case split_case_2
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      next
        case split_case_3
        by solve( !Party( pid, p, p )[no_precomp] ▶₁ #i )
      qed
    qed
  qed
qed
