/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma session_key_origin [reuse, use_induction]:
  all-traces
  "∀ prk label ctx #i.
    ((!KU( kdf(prk, label, ctx) ) @ #i) ∧
     ((label = 'skI') ∨ (label = 'skR'))) ⇒
    (∃ #j. (!KU( prk ) @ #j) ∧ (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ prk label ctx #i.
  (!KU( kdf(prk, label, ctx) ) @ #i)
 ∧
  (((label = 'skI') ∨ (label = 'skR'))) ∧
  (∀ #j. (!KU( prk ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (label = 'skI')  ∥ (label = 'skR') )
    case case_1
    solve( (last(#i))  ∥
           (∃ #j. (!KU( prk ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
      case case_1
      solve( !KU( kdf(prk, 'skI', ctx) ) @ #i )
        case Reveal_CK
        solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr ) /* unannotated */
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case Pair
          by contradiction /* unannotated */
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
          case Decode_known_ciphertext
          solve( splitEqs(0) )
            case split_case_1
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk.2)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.2) )
              case case_1
              by contradiction /* impossible chain */
            next
              case case_2
              by contradiction /* cyclic */
            qed
          next
            case split_case_2
            by solve( (#vl, 0) ~~> (#i, 0) )
          qed
        next
          case Prepare_encapsulation
          by contradiction
        qed
      next
        case c_kdf
        by contradiction
      qed
    next
      case case_2
      by contradiction
    qed
  next
    case case_2
    solve( (last(#i))  ∥
           (∃ #j. (!KU( prk ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
      case case_1
      solve( !KU( kdf(prk, 'skR', ctx) ) @ #i )
        case Reveal_CK
        solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr ) /* unannotated */
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case Pair
          by contradiction /* unannotated */
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
          case Decode_known_ciphertext
          solve( splitEqs(0) )
            case split_case_1
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk.2)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.2) )
              case case_1
              by contradiction /* impossible chain */
            next
              case case_2
              by contradiction /* cyclic */
            qed
          next
            case split_case_2
            by solve( (#vl, 0) ~~> (#i, 0) )
          qed
        next
          case Prepare_encapsulation
          by contradiction
        qed
      next
        case c_kdf
        by contradiction
      qed
    next
      case case_2
      by contradiction
    qed
  qed
qed
