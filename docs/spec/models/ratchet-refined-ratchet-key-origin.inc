/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma ratchet_key_origin [reuse, use_induction]:
  all-traces
  "∀ prk ctx #i.
    (!KU( kdf(prk, 'ratchet', ctx) ) @ #i) ⇒
    ((∃ #j. (!KU( prk ) @ #j) ∧ (#j < #i)) ∨
     (∃ pid #j.
       (RevCKv( pid, kdf(prk, 'ratchet', ctx) ) @ #j) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ prk ctx #i.
  (!KU( kdf(prk, 'ratchet', ctx) ) @ #i)
 ∧
  (∀ #j. (!KU( prk ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ pid #j.
    (RevCKv( pid, kdf(prk, 'ratchet', ctx) ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j. (!KU( prk ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ pid #j.
           (RevCKv( pid, kdf(prk, 'ratchet', ctx) ) @ #j)
          ∧
           (¬(last(#j))) ∧ (#j < #i)) )
    case case_1
    solve( !KU( kdf(prk, 'ratchet', ctx) ) @ #i )
      case Reveal_CK
      solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr ) /* unannotated */
        case I_S2_classic
        solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
          case kdf
          by contradiction /* unannotated */
        qed
      next
        case I_S2_classic_recovery_candidate
        solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
          case kdf
          by contradiction /* unannotated */
        qed
      next
        case I_S2_mix
        solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
          case kdf
          by contradiction /* unannotated */
        qed
      next
        case Pair
        by contradiction /* unannotated */
      next
        case R_S2_classic
        solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
          case kdf
          by contradiction /* unannotated */
        qed
      next
        case R_S2_mix
        solve( (#vl, 0) ~~> (#i, 0) ) /* unannotated */
          case kdf
          by contradiction /* unannotated */
        qed
      qed
    next
      case Reveal_CK_case_1
      by contradiction /* from formulas */
    next
      case Reveal_CK_case_2
      by contradiction /* from formulas */
    next
      case Reveal_CK_case_3
      by contradiction /* from formulas */
    next
      case Reveal_CK_case_4
      by contradiction /* from formulas */
    next
      case Reveal_CK_case_5
      by contradiction /* from formulas */
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
  next
    case case_3
    by contradiction
  qed
qed
