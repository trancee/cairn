/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma incoming_session_secret [reuse]:
  all-traces
  "∀ pid r ks kr #i #j.
    ((KeyDeclared( pid, r, ks, kr ) @ #i) ∧ (!KU( kr ) @ #j)) ⇒
    (∃ #d. (RevCK( pid ) @ #d) ∧ (#d < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ks kr #i #j.
  (KeyDeclared( pid, r, ks, kr ) @ #i) ∧ (!KU( kr ) @ #j)
 ∧
  ∀ #d. (RevCK( pid ) @ #d) ⇒ ¬(#d < #j)"
*/
simplify
by contradiction /* from formulas */

lemma session_use_declared [reuse, heuristic={authenticated_transfer}]:
  all-traces
  "∀ pid r ks kr #i.
    (SessionUse( pid, r, ks, kr ) @ #i) ⇒
    (∃ #j. (KeyDeclared( pid, r, ks, kr ) @ #j) ∧ (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ks kr #i.
  (SessionUse( pid, r, ks, kr ) @ #i)
 ∧
  ∀ #j. (KeyDeclared( pid, r, ks, kr ) @ #j) ⇒ ¬(#j < #i)"
*/
simplify
solve( SessionUse( pid, r, ks, kr ) @ #i )
  case Encapsulate
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Generate_EK
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_CT_duplicate_prefix_complete
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_CT_prefix
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_CT_tail
  solve( splitEqs(0) )
    case split_case_1
    solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₃ #i )
      case I_S2_classic
      by contradiction /* from formulas */
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction /* from formulas */
    next
      case R_S2_classic
      by contradiction /* from formulas */
    next
      case R_S2_mix
      by contradiction /* from formulas */
    qed
  next
    case split_case_2
    solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₃ #i )
      case I_S2_classic
      by contradiction /* from formulas */
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction /* from formulas */
    next
      case R_S2_classic
      by contradiction /* from formulas */
    next
      case R_S2_mix
      by contradiction /* from formulas */
    qed
  qed
next
  case Receive_DONE
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_EK_duplicate_prefix_complete
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_EK_prefix
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₃ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_EK_tail
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_progress_CT
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_progress_EK
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Receive_progress_full
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Resend_CT_prefix
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Resend_CT_progress_full
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Resend_CT_progress_half
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Resend_EK_prefix
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Resend_EK_progress_full
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Resend_EK_progress_half
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₂ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Send_CT_tail
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₃ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
next
  case Send_EK_tail
  solve( !SKValue( pid, r, ks, kr )[no_precomp] ▶₃ #i )
    case I_S2_classic
    by contradiction /* from formulas */
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction /* from formulas */
  next
    case R_S2_classic
    by contradiction /* from formulas */
  next
    case R_S2_mix
    by contradiction /* from formulas */
  qed
qed

lemma encrypted_progress_durable [reuse, heuristic={storage_origin}]:
  all-traces
  "∀ %e kind pos key #i.
    (EncryptedOutput( <'PROGRESS', %e, kind, pos>, key ) @ #i) ⇒
    (∃ pid r other #j #k.
      (((Durable( pid, r, %e, kind, pos ) @ #j) ∧
        (KeyDeclared( pid, r, key, other ) @ #k)) ∧
       ((#j < #i) ∨ (#j = #i))) ∧
      (#k < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ %e kind pos key #i.
  (EncryptedOutput( <'PROGRESS', %e, kind, pos>, key ) @ #i)
 ∧
  ∀ pid r other #j #k.
   (Durable( pid, r, %e, kind, pos ) @ #j) ∧
   (KeyDeclared( pid, r, key, other ) @ #k)
  ⇒
   (((¬(#j < #i)) ∧ (¬(#j = #i))) ∨ (¬(#k < #i)))"
*/
simplify
solve( EncryptedOutput( <'PROGRESS', %e, kind, pos>, key ) @ #i )
  case Receive_CT_duplicate_prefix_complete
  solve( !CompleteCT( pid, r, %e, ct )[no_precomp] ▶₀ #i )
    case Receive_CT_tail
    by contradiction /* from formulas */
  qed
next
  case Receive_CT_prefix
  by contradiction /* from formulas */
next
  case Receive_CT_tail
  by contradiction /* from formulas */
next
  case Receive_EK_duplicate_prefix_complete
  solve( !CompleteEK( pid, r, %e, ek )[no_precomp] ▶₀ #i )
    case Receive_EK_tail
    by contradiction /* from formulas */
  qed
next
  case Receive_EK_prefix
  by contradiction /* from formulas */
next
  case Receive_EK_tail
  by contradiction /* from formulas */
next
  case Resend_CT_progress_full
  solve( !CompleteCT( pid, r, %e, ct )[no_precomp] ▶₀ #i )
    case Receive_CT_tail
    by contradiction /* from formulas */
  qed
next
  case Resend_CT_progress_half
  solve( !CT0( pid, r, %e, ct ) ▶₀ #i )
    case Receive_CT_prefix
    by contradiction /* from formulas */
  qed
next
  case Resend_EK_progress_full
  solve( !CompleteEK( pid, r, %e, ek )[no_precomp] ▶₀ #i )
    case Receive_EK_tail
    by contradiction /* from formulas */
  qed
next
  case Resend_EK_progress_half
  solve( !EK0( pid, r, %e, ek ) ▶₀ #i )
    case Receive_EK_prefix
    by contradiction /* from formulas */
  qed
qed
