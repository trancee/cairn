/* Generated from Tamarin 1.12.0 verified raw-source export. */

lemma kem_and_ct_tail_origin [sources, use_induction]:
  all-traces
  "(∀ ss ek #i.
     (!KU( kem(ss, ek) ) @ #i) ⇒
     ((∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (#j < #i)) ∨
      (∃ #j. (!KU( ss ) @ #j) ∧ (#j < #i)))) ∧
   (∀ ss ek e key #i.
     (!KU( senc(<'CT', e, 'half', kem(ss, ek)>, key) ) @ #i) ⇒
     ((∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (#j < #i)) ∨
      (∃ #j. (!KU( ss ) @ #j) ∧ (#j < #i))))"
/*
guarded formula characterizing all counter-examples:
"((∃ ss ek #i.
    (!KU( kem(ss, ek) ) @ #i)
   ∧
    (∀ pid #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
    (∀ #j. (!KU( ss ) @ #j) ⇒ ¬(#j < #i))) ∨
  (∃ ss ek e key #i.
    (!KU( senc(<'CT', e, 'half', kem(ss, ek)>, key) ) @ #i)
   ∧
    (∀ pid #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
    (∀ #j. (!KU( ss ) @ #j) ⇒ ¬(#j < #i))))"
*/
induction
  case empty_trace
  by contradiction /* from formulas */
next
  case non_empty_trace
  solve( (∃ ss ek #i.
           (!KU( kem(ss, ek) ) @ #i)
          ∧
           (∀ pid #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
           (∀ #j. (!KU( ss ) @ #j) ⇒ ¬(#j < #i)))  ∥
         (∃ ss ek e key #i.
           (!KU( senc(<'CT', e, 'half', kem(ss, ek)>, key) ) @ #i)
          ∧
           (∀ pid #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
           (∀ #j. (!KU( ss ) @ #j) ⇒ ¬(#j < #i))) )
    case case_1
    solve( (last(#i))  ∥
           (∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
           (∃ #j. (!KU( ss ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
      case case_1
      solve( !KU( kem(ss, ek) ) @ #i )
        case Encapsulate
        by contradiction /* from formulas */
      next
        case Prepare_encapsulation
        by contradiction /* from formulas */
      next
        case Resend_CT_prefix
        by contradiction /* from formulas */
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
          by contradiction /* impossible chain */
        qed
      next
        case Send_CT_tail
        by contradiction /* from formulas */
      next
        case c_kem
        by contradiction /* from formulas */
      qed
    next
      case case_2
      by contradiction /* from formulas */
    next
      case case_3
      by contradiction /* from formulas */
    qed
  next
    case case_2
    solve( (last(#i))  ∥
           (∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
           (∃ #j. (!KU( ss ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
      case case_1
      solve( !KU( senc(<'CT', e, 'half', kem(ss, ek)>, key) ) @ #i )
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
          by contradiction /* impossible chain */
        qed
      next
        case Send_CT_tail
        by contradiction /* from formulas */
      next
        case c_senc
        solve( (∃ pid #j.
                 (FreshSS( pid, ss, ek ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk.7))  ∥
               (∃ #j. (!KU( ss ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk.7)) )
          case case_1
          by contradiction /* from formulas */
        next
          case case_2
          by contradiction /* from formulas */
        qed
      qed
    next
      case case_2
      by contradiction /* from formulas */
    next
      case case_3
      by contradiction /* from formulas */
    qed
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

