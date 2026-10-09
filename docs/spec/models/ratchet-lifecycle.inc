/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma lock_stage_unique [reuse, use_induction, heuristic={lifecycle}]:
  all-traces
  "∀ pid r %s #i #j.
    ((LockStage( pid, r, %s ) @ #i) ∧ (LockStage( pid, r, %s ) @ #j)) ⇒
    (#i = #j)"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %s #i #j.
  (LockStage( pid, r, %s ) @ #i) ∧ (LockStage( pid, r, %s ) @ #j)
 ∧
  ¬(#i = #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (#i < #j)  ∥ (#j < #i) )
    case case_1
    solve( LockStage( pid, r, %s ) @ #i )
      case Acquire_Resume
      solve( LockStage( pid, r, (%s%+%1) ) @ #j )
        case Acquire_Resume
        solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #i )
          case Pair_case_1
          solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #j )
            case Pair
            by contradiction
          next
            case Release_Resume
            by contradiction
          qed
        next
          case Pair_case_2
          solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #j )
            case Pair
            by contradiction
          next
            case Release_Resume
            by contradiction
          qed
        next
          case Release_Resume
          solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #j )
            case Pair_case_1
            by contradiction
          next
            case Pair_case_2
            by contradiction
          next
            case Release_Resume
            by contradiction
          qed
        qed
      next
        case Release_Resume
        solve( FinishPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case B_Collision_Yield
          solve( ResumeSlot( pid, roleB, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          qed
        next
          case I_S2_mix
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case I_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Data_advance_epoch
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_same_epoch
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout_recovery_candidate
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        qed
      qed
    next
      case Pair_case_1
      solve( LockStage( ~pid, roleA, %1 ) @ #j )
        case Pair
        by contradiction
      next
        case Release_Resume
        by solve( FinishPermit( ~pid, roleA, %1 )[no_precomp] ▶₀ #j )
      qed
    next
      case Pair_case_2
      solve( LockStage( ~pid, roleB, %1 ) @ #j )
        case Pair
        by contradiction
      next
        case Release_Resume
        by solve( FinishPermit( ~pid, roleB, %1 )[no_precomp] ▶₀ #j )
      qed
    next
      case Release_Resume
      solve( LockStage( pid, r, %s ) @ #j )
        case Acquire_Resume
        solve( FinishPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
          case B_Collision_Yield
          solve( ResumeSlot( pid, roleB, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          qed
        next
          case I_S2_mix
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case I_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Data_advance_epoch
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_same_epoch
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout_recovery_candidate
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        qed
      next
        case Pair_case_1
        by contradiction
      next
        case Pair_case_2
        by contradiction
      next
        case Release_Resume
        solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case B_Collision_Yield
          solve( FinishPermit( pid, roleB, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case B_Collision_Yield
            by contradiction
          qed
        next
          case I_S2_classic
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case I_S2_classic
            by contradiction
          qed
        next
          case I_S2_classic_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_classic_recovery_candidate
              by contradiction /* cyclic */
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_classic_recovery_candidate
              by contradiction /* cyclic */
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_classic_recovery_candidate
              by contradiction /* cyclic */
            qed
          qed
        next
          case I_S2_mix
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_mix
              by contradiction
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_mix
              by contradiction
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_mix
              by contradiction
            qed
          qed
        next
          case I_Timeout
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case I_Timeout
            by contradiction
          qed
        next
          case R_Data_advance_epoch
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_advance_epoch
              by contradiction
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_advance_epoch
              by contradiction
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_advance_epoch
              by contradiction
            qed
          qed
        next
          case R_Data_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_recovery_candidate
              by contradiction
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_recovery_candidate
              by contradiction
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_recovery_candidate
              by contradiction
            qed
          qed
        next
          case R_Data_same_epoch
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case R_Data_same_epoch
            by contradiction
          qed
        next
          case R_Timeout
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case R_Timeout
            by contradiction
          qed
        next
          case R_Timeout_recovery_candidate
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case R_Timeout_recovery_candidate
            by contradiction
          qed
        qed
      qed
    qed
  next
    case case_2
    solve( LockStage( pid, r, %s ) @ #i )
      case Acquire_Resume
      solve( LockStage( pid, r, (%s%+%1) ) @ #j )
        case Acquire_Resume
        solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #i )
          case Pair_case_1
          solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #j )
            case Pair
            by contradiction
          next
            case Release_Resume
            by contradiction
          qed
        next
          case Pair_case_2
          solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #j )
            case Pair
            by contradiction
          next
            case Release_Resume
            by contradiction
          qed
        next
          case Release_Resume
          solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #j )
            case Pair_case_1
            by contradiction
          next
            case Pair_case_2
            by contradiction
          next
            case Release_Resume
            by contradiction
          qed
        qed
      next
        case Release_Resume
        solve( FinishPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case B_Collision_Yield
          solve( ResumeSlot( pid, roleB, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          qed
        next
          case I_S2_mix
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case I_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Data_advance_epoch
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_same_epoch
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout_recovery_candidate
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
            case Release_Resume
            by contradiction
          qed
        qed
      qed
    next
      case Pair_case_1
      solve( LockStage( ~pid, roleA, %1 ) @ #j )
        case Pair
        by contradiction
      next
        case Release_Resume
        by contradiction
      qed
    next
      case Pair_case_2
      solve( LockStage( ~pid, roleB, %1 ) @ #j )
        case Pair
        by contradiction
      next
        case Release_Resume
        by contradiction
      qed
    next
      case Release_Resume
      solve( LockStage( pid, r, %s ) @ #j )
        case Acquire_Resume
        solve( FinishPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #i )
          case B_Collision_Yield
          solve( ResumeSlot( pid, roleB, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case I_S2_classic_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction /* from formulas */
            qed
          qed
        next
          case I_S2_mix
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case I_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Data_advance_epoch
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_2
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          next
            case split_case_3
            solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Release_Resume
              by contradiction
            qed
          qed
        next
          case R_Data_same_epoch
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        next
          case R_Timeout_recovery_candidate
          solve( ResumeSlot( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
            case Release_Resume
            by contradiction
          qed
        qed
      next
        case Pair_case_1
        by solve( FinishPermit( ~pid, roleA, %1 )[no_precomp] ▶₀ #i )
      next
        case Pair_case_2
        by solve( FinishPermit( ~pid, roleB, %1 )[no_precomp] ▶₀ #i )
      next
        case Release_Resume
        solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case B_Collision_Yield
          solve( FinishPermit( pid, roleB, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case B_Collision_Yield
            by contradiction
          qed
        next
          case I_S2_classic
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case I_S2_classic
            by contradiction
          qed
        next
          case I_S2_classic_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_classic_recovery_candidate
              by contradiction /* cyclic */
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_classic_recovery_candidate
              by contradiction /* cyclic */
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_classic_recovery_candidate
              by contradiction /* cyclic */
            qed
          qed
        next
          case I_S2_mix
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_mix
              by contradiction
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_mix
              by contradiction
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case I_S2_mix
              by contradiction
            qed
          qed
        next
          case I_Timeout
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case I_Timeout
            by contradiction
          qed
        next
          case R_Data_advance_epoch
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_advance_epoch
              by contradiction
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_advance_epoch
              by contradiction
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_advance_epoch
              by contradiction
            qed
          qed
        next
          case R_Data_recovery_candidate
          solve( splitEqs(2) )
            case split_case_1
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_recovery_candidate
              by contradiction
            qed
          next
            case split_case_2
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_recovery_candidate
              by contradiction
            qed
          next
            case split_case_3
            solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
              case R_Data_recovery_candidate
              by contradiction
            qed
          qed
        next
          case R_Data_same_epoch
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case R_Data_same_epoch
            by contradiction
          qed
        next
          case R_Timeout
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case R_Timeout
            by contradiction
          qed
        next
          case R_Timeout_recovery_candidate
          solve( FinishPermit( pid, r, (%s%+%1%+%1) )[no_precomp] ▶₀ #j )
            case R_Timeout_recovery_candidate
            by contradiction
          qed
        qed
      qed
    qed
  qed
qed

lemma start_stage_unique [reuse, heuristic={lifecycle}]:
  all-traces
  "∀ pid r %s #i #j.
    ((ResumeStart( pid, r, %s ) @ #i) ∧ (ResumeStart( pid, r, %s ) @ #j)) ⇒
    (#i = #j)"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %s #i #j.
  (ResumeStart( pid, r, %s ) @ #i) ∧ (ResumeStart( pid, r, %s ) @ #j)
 ∧
  ¬(#i = #j)"
*/
simplify
solve( (#i < #j)  ∥ (#j < #i) )
  case case_1
  solve( ResumeStart( pid, r, %s ) @ #i )
    case I_S1_classic
    solve( ResumeStart( pid, r, %s ) @ #j )
      case I_S1_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case Acquire_Resume
          by contradiction
        qed
      qed
    next
      case I_S1_mix
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_mix
      solve( splitEqs(1) )
        case split_case_1
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_2
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_3
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      qed
    qed
  next
    case I_S1_mix
    solve( ResumeStart( pid, r, %s ) @ #j )
      case I_S1_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case I_S1_mix
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case Acquire_Resume
          by contradiction
        qed
      qed
    next
      case R_S2_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_mix
      solve( splitEqs(1) )
        case split_case_1
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_2
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_3
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      qed
    qed
  next
    case R_S2_classic
    solve( ResumeStart( pid, r, %s ) @ #j )
      case I_S1_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case I_S1_mix
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case Acquire_Resume
          by contradiction
        qed
      qed
    next
      case R_S2_mix
      solve( splitEqs(1) )
        case split_case_1
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_2
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_3
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      qed
    qed
  next
    case R_S2_mix
    solve( splitEqs(0) )
      case split_case_1
      solve( ResumeStart( pid, r, %s ) @ #j )
        case I_S1_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case I_S1_mix
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_mix
        solve( splitEqs(2) )
          case split_case_1
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Acquire_Resume
              by contradiction
            qed
          qed
        next
          case split_case_2
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_3
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        qed
      qed
    next
      case split_case_2
      solve( ResumeStart( pid, r, %s ) @ #j )
        case I_S1_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case I_S1_mix
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_mix
        solve( splitEqs(2) )
          case split_case_1
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_2
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Acquire_Resume
              by contradiction
            qed
          qed
        next
          case split_case_3
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        qed
      qed
    next
      case split_case_3
      solve( ResumeStart( pid, r, %s ) @ #j )
        case I_S1_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case I_S1_mix
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_mix
        solve( splitEqs(2) )
          case split_case_1
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_2
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_3
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Acquire_Resume
              by contradiction
            qed
          qed
        qed
      qed
    qed
  qed
next
  case case_2
  solve( ResumeStart( pid, r, %s ) @ #i )
    case I_S1_classic
    solve( ResumeStart( pid, r, %s ) @ #j )
      case I_S1_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case Acquire_Resume
          by contradiction
        qed
      qed
    next
      case I_S1_mix
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_mix
      solve( splitEqs(1) )
        case split_case_1
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_2
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_3
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      qed
    qed
  next
    case I_S1_mix
    solve( ResumeStart( pid, r, %s ) @ #j )
      case I_S1_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case I_S1_mix
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case Acquire_Resume
          by contradiction
        qed
      qed
    next
      case R_S2_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_mix
      solve( splitEqs(1) )
        case split_case_1
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_2
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_3
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      qed
    qed
  next
    case R_S2_classic
    solve( ResumeStart( pid, r, %s ) @ #j )
      case I_S1_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case I_S1_mix
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
      qed
    next
      case R_S2_classic
      solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
        case Acquire_Resume
        solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          case Acquire_Resume
          by contradiction
        qed
      qed
    next
      case R_S2_mix
      solve( splitEqs(1) )
        case split_case_1
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_2
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case split_case_3
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      qed
    qed
  next
    case R_S2_mix
    solve( splitEqs(0) )
      case split_case_1
      solve( ResumeStart( pid, r, %s ) @ #j )
        case I_S1_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case I_S1_mix
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_mix
        solve( splitEqs(2) )
          case split_case_1
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Acquire_Resume
              by contradiction
            qed
          qed
        next
          case split_case_2
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_3
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        qed
      qed
    next
      case split_case_2
      solve( ResumeStart( pid, r, %s ) @ #j )
        case I_S1_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case I_S1_mix
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_mix
        solve( splitEqs(2) )
          case split_case_1
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_2
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Acquire_Resume
              by contradiction
            qed
          qed
        next
          case split_case_3
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        qed
      qed
    next
      case split_case_3
      solve( ResumeStart( pid, r, %s ) @ #j )
        case I_S1_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case I_S1_mix
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_classic
        solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
          case Acquire_Resume
          by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
        qed
      next
        case R_S2_mix
        solve( splitEqs(2) )
          case split_case_1
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_2
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            by solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
          qed
        next
          case split_case_3
          solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
            case Acquire_Resume
            solve( StartPermit( pid, r, (%s%+%1) )[no_precomp] ▶₀ #j )
              case Acquire_Resume
              by contradiction
            qed
          qed
        qed
      qed
    qed
  qed
qed

lemma finish_has_start [reuse, heuristic={lifecycle}]:
  all-traces
  "∀ pid r %s #i.
    (ResumeFinish( pid, r, %s ) @ #i) ⇒
    (∃ %t #j.
      ((ResumeStart( pid, r, %t ) @ #j) ∧ (%s = (%t%+%1))) ∧ (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %s #i.
  (ResumeFinish( pid, r, %s ) @ #i)
 ∧
  ∀ %t #j. (ResumeStart( pid, r, %t ) @ #j) ∧ (%s = (%t%+%1)) ⇒ ¬(#j < #i)"
*/
simplify
solve( ResumeFinish( pid, r, %s ) @ #i )
  case B_Collision_Yield
  solve( BusySlot( pid, roleB, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( IWait( pid, roleB, roleA, own, %e, g, %n, ng, nonce, ownmode, pq,
                  ss, ek, ct, (%s%+%1)
           )[no_precomp] ▶₁ #i )
      case I_S1_classic
      by contradiction
    next
      case I_S1_mix
      by contradiction
    qed
  qed
next
  case I_S2_classic
  solve( BusySlot( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( IWait( pid, r, p, ck, %e, g, %e, g, x, '0', 'none', 'none',
                  'none', 'none', (%s%+%1)
           )[no_precomp] ▶₁ #i )
      case I_S1_classic
      by contradiction
    qed
  qed
next
  case I_S2_classic_recovery_candidate
  solve( splitEqs(0) )
    case split_case_1
    solve( IWait( pid, r, p, ck, (%e%+%1), flip(oldg), (%e%+%1), flip(oldg),
                  x, '0', 'none', 'none', 'none', 'none', %s
           )[no_precomp] ▶₁ #i )
      case I_S1_classic
      by contradiction /* from formulas */
    qed
  next
    case split_case_2
    solve( IWait( pid, r, p, ck, (%e%+%1), roleB, (%e%+%1), roleB, x, '0',
                  'none', 'none', 'none', 'none', %s
           )[no_precomp] ▶₁ #i )
      case I_S1_classic
      by contradiction /* from formulas */
    qed
  next
    case split_case_3
    solve( IWait( pid, r, p, ck, (%e%+%1), roleA, (%e%+%1), roleA, x, '0',
                  'none', 'none', 'none', 'none', %s
           )[no_precomp] ▶₁ #i )
      case I_S1_classic
      by contradiction /* from formulas */
    qed
  qed
next
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( IWait( pid, r, p, ck, %e, g, (%e%+%1), flip(g), x, '1',
                  <ss, h(ek), h(ct)>, ss, ek, ct, %s
           )[no_precomp] ▶₁ #i )
      case I_S1_mix
      by contradiction
    qed
  next
    case split_case_2
    solve( IWait( pid, r, p, ck, %e, roleA, (%e%+%1), roleB, x, '1',
                  <ss, h(ek), h(ct)>, ss, ek, ct, %s
           )[no_precomp] ▶₁ #i )
      case I_S1_mix
      by contradiction
    qed
  next
    case split_case_3
    solve( IWait( pid, r, p, ck, %e, roleB, (%e%+%1), roleA, x, '1',
                  <ss, h(ek), h(ct)>, ss, ek, ct, %s
           )[no_precomp] ▶₁ #i )
      case I_S1_mix
      by contradiction
    qed
  qed
next
  case I_Timeout
  solve( BusySlot( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( IWait( pid, r, p, ck, %e, g, %n, ng, x, mode, pq, ss, ek, ct,
                  (%s%+%1)
           )[no_precomp] ▶₁ #i )
      case I_S1_classic
      by contradiction
    next
      case I_S1_mix
      by contradiction
    qed
  qed
next
  case R_Data_advance_epoch
  solve( splitEqs(0) )
    case split_case_1
    solve( RPending( pid, r, p, ck, ck1, (%e%+%1), flip(g), pq, ki, kr, %s
           )[no_precomp] ▶₁ #i )
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_2
    solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleB, pq, ki, kr, %s
           )[no_precomp] ▶₁ #i )
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_3
    solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleA, pq, ki, kr, %s
           )[no_precomp] ▶₁ #i )
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
    solve( !PositionValue( pid, (%e%+%1), flip(oldg) )[no_precomp] ▶₇ #i )
      case I_S2_mix
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), flip(oldg), pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_Data_advance_epoch
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), flip(oldg), pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_S2_mix
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), flip(oldg), pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    qed
  next
    case split_case_2
    solve( !PositionValue( pid, (%e%+%1), roleB )[no_precomp] ▶₇ #i )
      case I_S2_mix
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleB, pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_Data_advance_epoch
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleB, pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_S2_mix
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleB, pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    qed
  next
    case split_case_3
    solve( !PositionValue( pid, (%e%+%1), roleA )[no_precomp] ▶₇ #i )
      case I_S2_mix
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleA, pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_Data_advance_epoch
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleA, pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    next
      case R_S2_mix
      solve( RPending( pid, r, p, ck, ck1, (%e%+%1), roleA, pq, ki, kr, %s
             )[no_precomp] ▶₁ #i )
        case R_S2_classic
        by contradiction
      next
        case R_S2_mix
        by contradiction
      qed
    qed
  qed
next
  case R_Data_same_epoch
  solve( BusySlot( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( RPending( pid, r, p, ck, ck1, %e, g, pq, ki, kr, (%s%+%1)
           )[no_precomp] ▶₁ #i )
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
next
  case R_Timeout
  solve( BusySlot( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( RPending( pid, r, p, ck, ck1, %e, g, pq, ki, kr, (%s%+%1)
           )[no_precomp] ▶₁ #i )
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
next
  case R_Timeout_recovery_candidate
  solve( BusySlot( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( RPending( pid, r, p, ck, ck1, %e, g, pq, ki, kr, (%s%+%1)
           )[no_precomp] ▶₁ #i )
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
qed

lemma start_has_predecessor [reuse, heuristic={lifecycle}]:
  all-traces
  "∀ pid r %s #i.
    (ResumeStart( pid, r, %s ) @ #i) ⇒
    ((%s = (%1%+%1)) ∨
     (∃ %t #j.
       ((ResumeFinish( pid, r, %t ) @ #j) ∧ (%s = (%t%+%1))) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %s #i.
  (ResumeStart( pid, r, %s ) @ #i)
 ∧
  (¬(%s = (%1%+%1))) ∧
  (∀ %t #j.
    (ResumeFinish( pid, r, %t ) @ #j) ∧ (%s = (%t%+%1)) ⇒ ¬(#j < #i))"
*/
simplify
solve( ResumeStart( pid, r, %s ) @ #i )
  case I_S1_classic
  solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #vr )
      case Pair_case_1
      by contradiction
    next
      case Pair_case_2
      by contradiction
    next
      case Release_Resume
      solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #vr.1 )
        case B_Collision_Yield
        by contradiction
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
        case I_Timeout
        by contradiction
      next
        case R_Data_advance_epoch
        by contradiction
      next
        case R_Data_recovery_candidate
        by contradiction
      next
        case R_Data_same_epoch
        by contradiction
      next
        case R_Timeout
        by contradiction
      next
        case R_Timeout_recovery_candidate
        by contradiction
      qed
    qed
  qed
next
  case I_S1_mix
  solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #vr )
      case Pair_case_1
      by contradiction
    next
      case Pair_case_2
      by contradiction
    next
      case Release_Resume
      solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #vr.1 )
        case B_Collision_Yield
        by contradiction
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
        case I_Timeout
        by contradiction
      next
        case R_Data_advance_epoch
        by contradiction
      next
        case R_Data_recovery_candidate
        by contradiction
      next
        case R_Data_same_epoch
        by contradiction
      next
        case R_Timeout
        by contradiction
      next
        case R_Timeout_recovery_candidate
        by contradiction
      qed
    qed
  qed
next
  case R_S2_classic
  solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
    case Acquire_Resume
    solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #vr )
      case Pair_case_1
      by contradiction
    next
      case Pair_case_2
      by contradiction
    next
      case Release_Resume
      solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #vr.1 )
        case B_Collision_Yield
        by contradiction
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
        case I_Timeout
        by contradiction
      next
        case R_Data_advance_epoch
        by contradiction
      next
        case R_Data_recovery_candidate
        by contradiction
      next
        case R_Data_same_epoch
        by contradiction
      next
        case R_Timeout
        by contradiction
      next
        case R_Timeout_recovery_candidate
        by contradiction
      qed
    qed
  qed
next
  case R_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
      case Acquire_Resume
      solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #vr )
        case Pair_case_1
        by contradiction
      next
        case Pair_case_2
        by contradiction
      next
        case Release_Resume
        solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #vr.1 )
          case B_Collision_Yield
          by contradiction
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
          case I_Timeout
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_Data_recovery_candidate
          by contradiction
        next
          case R_Data_same_epoch
          by contradiction
        next
          case R_Timeout
          by contradiction
        next
          case R_Timeout_recovery_candidate
          by contradiction
        qed
      qed
    qed
  next
    case split_case_2
    solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
      case Acquire_Resume
      solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #vr )
        case Pair_case_1
        by contradiction
      next
        case Pair_case_2
        by contradiction
      next
        case Release_Resume
        solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #vr.1 )
          case B_Collision_Yield
          by contradiction
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
          case I_Timeout
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_Data_recovery_candidate
          by contradiction
        next
          case R_Data_same_epoch
          by contradiction
        next
          case R_Timeout
          by contradiction
        next
          case R_Timeout_recovery_candidate
          by contradiction
        qed
      qed
    qed
  next
    case split_case_3
    solve( StartPermit( pid, r, %s )[no_precomp] ▶₀ #i )
      case Acquire_Resume
      solve( ResumeSlot( pid, r, %s )[no_precomp] ▶₀ #vr )
        case Pair_case_1
        by contradiction
      next
        case Pair_case_2
        by contradiction
      next
        case Release_Resume
        solve( FinishPermit( pid, r, %s )[no_precomp] ▶₀ #vr.1 )
          case B_Collision_Yield
          by contradiction
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
          case I_Timeout
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_Data_recovery_candidate
          by contradiction
        next
          case R_Data_same_epoch
          by contradiction
        next
          case R_Timeout
          by contradiction
        next
          case R_Timeout_recovery_candidate
          by contradiction
        qed
      qed
    qed
  qed
qed
