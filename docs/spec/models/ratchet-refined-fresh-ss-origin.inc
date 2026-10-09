/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma fresh_ss_origin [reuse, use_induction]:
  all-traces
  "∀ pid ss ek #i #j.
    ((FreshSS( pid, ss, ek ) @ #i) ∧ (!KU( ss ) @ #j)) ⇒
    ((∃ q #d. (RevSS( q, ss ) @ #d) ∧ (#d < #j)) ∨
     (∃ dk #k. ((!KU( dk ) @ #k) ∧ (ek = pk(dk))) ∧ (#k < #j)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ss ek #i #j.
  (FreshSS( pid, ss, ek ) @ #i) ∧ (!KU( ss ) @ #j)
 ∧
  (∀ q #d. (RevSS( q, ss ) @ #d) ⇒ ¬(#d < #j)) ∧
  (∀ dk #k. (!KU( dk ) @ #k) ∧ (ek = pk(dk)) ⇒ ¬(#k < #j))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (last(#i))  ∥
         (∃ q #d. (RevSS( q, ~ss ) @ #d) ∧ (¬(last(#d))) ∧ (#d < #j))  ∥
         (∃ dk #k.
           (!KU( dk ) @ #k) ∧ (ek = pk(dk)) ∧ (¬(last(#k))) ∧ (#k < #j)) )
    case case_1
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
        /* unannotated */
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case Pair
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
        /* unannotated */
          case Decode_known_ciphertext
          solve( !Party( pid.1, r.1, p )[no_precomp] ▶₀ #vr.3 )
          /* unannotated */
            case Pair_case_1
            solve( splitEqs(1) ) /* unannotated */
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
            next
              case split_case_2
              solve( (∃ pid #j.
                       (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
              /* unannotated */
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
                  case Var_fresh_1_ss
                  by contradiction /* unannotated */
                qed
              next
                case case_2
                by contradiction /* unannotated */
              qed
            qed
          next
            case Pair_case_2
            solve( splitEqs(1) ) /* unannotated */
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
            next
              case split_case_2
              solve( (∃ pid #j.
                       (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
              /* unannotated */
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
                  case Var_fresh_1_ss
                  by contradiction /* unannotated */
                qed
              next
                case case_2
                by contradiction /* unannotated */
              qed
            qed
          qed
        next
          case Prepare_encapsulation
          solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
            case Var_fresh_1_ss
            by contradiction /* unannotated */
          qed
        qed
      next
        case Reveal_SS_case_1
        by contradiction /* from formulas */
      next
        case Reveal_SS_case_2
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( splitEqs(1) )
            case split_case_1
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk.3)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.3) )
              case case_1
              solve( (#vl, 0) ~~> (#j, 0) )
                case Var_fresh_1_ss
                by contradiction /* from formulas */
              qed
            next
              case case_2
              by contradiction /* cyclic */
            qed
          next
            case split_case_2
            by solve( (#vl, 0) ~~> (#j, 0) )
          qed
        next
          case Prepare_encapsulation
          solve( (#vl, 0) ~~> (#j, 0) )
            case Var_fresh_1_ss
            by contradiction /* from formulas */
          qed
        qed
      next
        case Send_CT_tail
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
        /* unannotated */
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case Pair
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
        /* unannotated */
          case Decode_known_ciphertext
          solve( !Party( pid.1, r.1, p )[no_precomp] ▶₀ #vr.3 )
          /* unannotated */
            case Pair_case_1
            solve( splitEqs(1) ) /* unannotated */
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
            next
              case split_case_2
              solve( (∃ pid #j.
                       (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
              /* unannotated */
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
                  case Var_fresh_1_ss
                  by contradiction /* unannotated */
                qed
              next
                case case_2
                by contradiction /* unannotated */
              qed
            qed
          next
            case Pair_case_2
            solve( splitEqs(1) ) /* unannotated */
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
            next
              case split_case_2
              solve( (∃ pid #j.
                       (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
              /* unannotated */
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
                  case Var_fresh_1_ss
                  by contradiction /* unannotated */
                qed
              next
                case case_2
                by contradiction /* unannotated */
              qed
            qed
          qed
        next
          case Prepare_encapsulation
          solve( (#vl, 0) ~~> (#j, 0) ) /* unannotated */
            case Var_fresh_1_ss
            by contradiction /* unannotated */
          qed
        qed
      next
        case Reveal_SS_case_1
        by contradiction /* from formulas */
      next
        case Reveal_SS_case_2
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( splitEqs(1) )
            case split_case_1
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk.3)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.3) )
              case case_1
              solve( (#vl, 0) ~~> (#j, 0) )
                case Var_fresh_1_ss
                by contradiction /* from formulas */
              qed
            next
              case case_2
              by contradiction /* cyclic */
            qed
          next
            case split_case_2
            by solve( (#vl, 0) ~~> (#j, 0) )
          qed
        next
          case Prepare_encapsulation
          solve( (#vl, 0) ~~> (#j, 0) )
            case Var_fresh_1_ss
            by contradiction /* from formulas */
          qed
        qed
      next
        case Send_CT_tail
        by contradiction
      qed
    qed
  next
    case case_2
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        by contradiction /* unannotated */
      next
        case Reveal_SS
        by contradiction /* unannotated */
      next
        case Reveal_SS_case_1
        by contradiction /* from formulas */
      next
        case Reveal_SS_case_2
        by contradiction /* node #j after last node #i */
      next
        case Send_CT_tail
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        by contradiction /* unannotated */
      next
        case Reveal_SS
        by contradiction /* unannotated */
      next
        case Reveal_SS_case_1
        by contradiction /* from formulas */
      next
        case Reveal_SS_case_2
        by contradiction /* node #j after last node #i */
      next
        case Send_CT_tail
        by contradiction
      qed
    qed
  next
    case case_3
    by contradiction
  next
    case case_4
    by contradiction
  qed
qed
