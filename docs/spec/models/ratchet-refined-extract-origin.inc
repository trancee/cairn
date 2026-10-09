/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma extract_origin [reuse, use_induction]:
  all-traces
  "∀ ck ikm #i.
    (!KU( ext(ck, ikm) ) @ #i) ⇒
    (∃ #j #k.
      (((!KU( ck ) @ #j) ∧ (!KU( ikm ) @ #k)) ∧ (#j < #i)) ∧ (#k < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ ck ikm #i.
  (!KU( ext(ck, ikm) ) @ #i)
 ∧
  ∀ #j #k.
   (!KU( ck ) @ #j) ∧ (!KU( ikm ) @ #k)
  ⇒
   ((¬(#j < #i)) ∨ (¬(#k < #i)))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j #k.
           (!KU( ck ) @ #j) ∧ (!KU( ikm ) @ #k)
          ∧
           (¬(last(#k))) ∧ (¬(last(#j))) ∧ (#j < #i) ∧ (#k < #i)) )
    case case_1
    solve( !KU( ext(ck, ikm) ) @ #i )
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
      case c_ext
      by contradiction
    qed
  next
    case case_2
    by contradiction
  qed
qed
