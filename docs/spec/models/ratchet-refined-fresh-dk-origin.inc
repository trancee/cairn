/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma fresh_dk_origin [reuse, use_induction]:
  all-traces
  "∀ pid dk #i #j.
    ((FreshDK( pid, dk ) @ #i) ∧ (!KU( dk ) @ #j)) ⇒
    (∃ q #d. (RevDK( q, pk(dk) ) @ #d) ∧ (#d < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid dk #i #j.
  (FreshDK( pid, dk ) @ #i) ∧ (!KU( dk ) @ #j)
 ∧
  ∀ q #d. (RevDK( q, pk(dk) ) @ #d) ⇒ ¬(#d < #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (last(#i))  ∥
         (∃ q #d. (RevDK( q, pk(~dk) ) @ #d) ∧ (¬(last(#d))) ∧ (#d < #j)) )
    case case_1
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~dk ) @ #j )
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
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( splitEqs(1) )
            case split_case_1
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk.2) ) @ #j) ∧ #j < #vk.2)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.2) )
              case case_1
              by solve( (#vl, 0) ~~> (#j, 0) )
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
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      qed
    next
      case Pair_case_2
      solve( !KU( ~dk ) @ #j )
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
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( splitEqs(1) )
            case split_case_1
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk.2) ) @ #j) ∧ #j < #vk.2)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.2) )
              case case_1
              by solve( (#vl, 0) ~~> (#j, 0) )
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
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      qed
    qed
  next
    case case_2
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~dk ) @ #j )
        case Reveal_CK
        by contradiction /* unannotated */
      next
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !KU( ~dk ) @ #j )
        case Reveal_CK
        by contradiction /* unannotated */
      next
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        by contradiction
      qed
    qed
  next
    case case_3
    by contradiction
  qed
qed
