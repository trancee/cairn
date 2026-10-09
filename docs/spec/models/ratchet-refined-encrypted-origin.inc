/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma encrypted_origin [reuse, use_induction]:
  all-traces
  "∀ m k #i.
    (!KU( senc(m, k) ) @ #i) ⇒
    ((∃ #j. (EncryptedOutput( m, k ) @ #j) ∧ (#j < #i)) ∨
     (∃ #j #l.
       (((!KU( m ) @ #j) ∧ (!KU( k ) @ #l)) ∧ (#j < #i)) ∧ (#l < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ m k #i.
  (!KU( senc(m, k) ) @ #i)
 ∧
  (∀ #j. (EncryptedOutput( m, k ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ #j #l.
    (!KU( m ) @ #j) ∧ (!KU( k ) @ #l) ⇒ ((¬(#j < #i)) ∨ (¬(#l < #i))))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j.
           (EncryptedOutput( m, k ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ #j #l.
           (!KU( m ) @ #j) ∧ (!KU( k ) @ #l)
          ∧
           (¬(last(#l))) ∧ (¬(last(#j))) ∧ (#j < #i) ∧ (#l < #i)) )
    case case_1
    solve( !KU( senc(m, k) ) @ #i )
      case Encapsulate
      by contradiction
    next
      case Generate_EK
      by contradiction
    next
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction
    next
      case I_S2_mix
      by contradiction
    next
      case Receive_CT_duplicate_prefix_complete_case_1
      by contradiction
    next
      case Receive_CT_duplicate_prefix_complete_case_2
      by contradiction
    next
      case Receive_CT_prefix
      by contradiction
    next
      case Receive_CT_tail_case_1
      by contradiction
    next
      case Receive_CT_tail_case_2
      by contradiction
    next
      case Receive_EK_duplicate_prefix_complete
      by contradiction
    next
      case Receive_EK_prefix
      by contradiction
    next
      case Receive_EK_tail
      by contradiction
    next
      case Resend_CT_prefix
      by contradiction
    next
      case Resend_CT_progress_full_case_1
      by contradiction
    next
      case Resend_CT_progress_full_case_2
      by contradiction
    next
      case Resend_CT_progress_half
      by contradiction
    next
      case Resend_EK_prefix
      by contradiction
    next
      case Resend_EK_progress_full
      by contradiction
    next
      case Resend_EK_progress_half
      by contradiction
    next
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
      case Send_CT_tail
      by contradiction
    next
      case Send_EK_tail
      by contradiction
    next
      case c_senc
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
