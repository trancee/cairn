/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma kem_ciphertext_origin [sources, reuse, use_induction]:
  all-traces
  "∀ ss ek #i.
    (!KU( kem(ss, ek) ) @ #i) ⇒
    ((∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (#j < #i)) ∨
     (∃ #j. (!KU( ss ) @ #j) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ ss ek #i.
  (!KU( kem(ss, ek) ) @ #i)
 ∧
  (∀ pid #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ #j. (!KU( ss ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ #j. (!KU( ss ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
    case case_1
    solve( !KU( kem(ss, ek) ) @ #i )
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
      solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
        case I_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_classic_recovery_candidate
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case Pair
        by contradiction /* impossible chain */
      next
        case R_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case R_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      qed
    next
      case Reveal_SS
      solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
        case Decode_known_ciphertext
        solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
          case Pair_case_1
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk))  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk)) )
              case case_1
              by contradiction /* impossible chain */
            next
              case case_2
              by contradiction /* cyclic */
            qed
          qed
        next
          case Pair_case_2
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk))  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk)) )
              case case_1
              by contradiction /* impossible chain */
            next
              case case_2
              by contradiction /* cyclic */
            qed
          qed
        qed
      next
        case Prepare_encapsulation
        by contradiction
      qed
    next
      case Send_CT_tail
      by contradiction
    next
      case c_kem
      by contradiction
    qed
  next
    case case_2
    by contradiction
  next
    case case_3
    by contradiction
  qed
qed
