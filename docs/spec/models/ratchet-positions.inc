/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma position_has_predecessor [reuse, use_induction,
                                heuristic={positions}, hide_lemma=lock_stage_unique,
                                hide_lemma=start_stage_unique, hide_lemma=finish_has_start,
                                hide_lemma=start_has_predecessor, hide_lemma=kem_ciphertext_origin,
                                hide_lemma=fresh_dk_origin, hide_lemma=fresh_ss_origin,
                                hide_lemma=encrypted_origin, hide_lemma=extract_origin,
                                hide_lemma=ratchet_key_origin, hide_lemma=session_key_origin,
                                hide_lemma=derived_ck_origin, hide_lemma=derived_ck_predecessor,
                                hide_lemma=initial_ck_secret, hide_lemma=ck_secret,
                                hide_lemma=cur_secret, hide_lemma=declared_session_secret,
                                hide_lemma=epoch_secret, hide_lemma=mixed_key_origin,
                                hide_lemma=ek_authenticated, hide_lemma=ct_authenticated]:
  all-traces
  "∀ pid %e g #i.
    (Position( pid, %e, g ) @ #i) ⇒
    (((%e = %1) ∧ (g = roleA)) ∨
     (∃ %p previous #j.
       (((Position( pid, %p, previous ) @ #j) ∧ (%e = (%p%+%1))) ∧
        (((g = roleA) ∧ (previous = roleB)) ∨
         ((g = roleB) ∧ (previous = roleA)))) ∧
       (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid %e g #i.
  (Position( pid, %e, g ) @ #i)
 ∧
  (((¬(%e = %1)) ∨ (¬(g = roleA)))) ∧
  (∀ %p previous #j.
    (Position( pid, %p, previous ) @ #j) ∧ (%e = (%p%+%1))
   ⇒
    (((((¬(g = roleA)) ∨ (¬(previous = roleB)))) ∧
      (((¬(g = roleB)) ∨ (¬(previous = roleA))))) ∨
     (¬(#j < #i))))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( Position( pid, %e, g ) @ #i )
    case I_S2_mix
    solve( splitEqs(0) )
      case split_case_1
      by solve( !Party( pid, g, flip(g) )[no_precomp] ▶₆ #i )
    next
      case split_case_2
      solve( !Party( pid, roleA, roleB )[no_precomp] ▶₆ #i )
        case Pair
        solve( !PositionValue( ~pid, %e, roleA )[no_precomp] ▶₅ #i )
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case split_case_3
      solve( !Party( pid, roleB, roleA )[no_precomp] ▶₆ #i )
        case Pair
        solve( !PositionValue( ~pid, %e, roleB )[no_precomp] ▶₅ #i )
          case I_S2_mix
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    qed
  next
    case Pair
    by contradiction
  next
    case R_Data_advance_epoch
    solve( splitEqs(0) )
      case split_case_1
      by solve( !Party( pid, g, flip(g) )[no_precomp] ▶₄ #i )
    next
      case split_case_2
      solve( !Party( pid, roleB, roleA )[no_precomp] ▶₄ #i )
        case Pair
        solve( !PositionValue( ~pid, %e, roleB )[no_precomp] ▶₇ #i )
          case I_S2_mix
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case split_case_3
      solve( !Party( pid, roleA, roleB )[no_precomp] ▶₄ #i )
        case Pair
        solve( !PositionValue( ~pid, %e, roleA )[no_precomp] ▶₇ #i )
          case I_S2_mix
          by contradiction
        next
          case Pair
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    qed
  next
    case R_Data_recovery_candidate
    solve( splitEqs(0) )
      case split_case_1
      by solve( !Party( pid, oldg, flip(oldg) )[no_precomp] ▶₄ #i )
    next
      case split_case_2
      solve( !Party( pid, roleB, roleA )[no_precomp] ▶₄ #i )
        case Pair
        solve( !PositionValue( ~pid, (%e%+%1), roleA )[no_precomp] ▶₇ #i )
          case I_S2_mix
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    next
      case split_case_3
      solve( !Party( pid, roleA, roleB )[no_precomp] ▶₄ #i )
        case Pair
        solve( !PositionValue( ~pid, (%e%+%1), roleB )[no_precomp] ▶₇ #i )
          case I_S2_mix
          by contradiction
        next
          case R_Data_advance_epoch
          by contradiction
        next
          case R_S2_mix
          by contradiction
        qed
      qed
    qed
  next
    case R_S2_mix
    solve( splitEqs(0) )
      case split_case_1
      solve( !Party( pid, r, p )[no_precomp] ▶₁ #i )
        case Pair_case_1
        by solve( !Party( ~pid, g, flip(g) )[no_precomp] ▶₂ #i )
      next
        case Pair_case_2
        by solve( !Party( ~pid, g, flip(g) )[no_precomp] ▶₂ #i )
      qed
    next
      case split_case_2
      solve( !Party( pid, r, p )[no_precomp] ▶₁ #i )
        case Pair_case_1
        solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #i )
          case Pair
          solve( !PositionValue( ~pid, %e, roleA )[no_precomp] ▶₈ #i )
            case I_S2_mix
            by contradiction
          next
            case Pair
            by contradiction
          next
            case R_Data_advance_epoch
            by contradiction
          next
            case R_S2_mix
            by contradiction
          qed
        qed
      next
        case Pair_case_2
        solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #i )
          case Pair
          solve( !PositionValue( ~pid, %e, roleA )[no_precomp] ▶₈ #i )
            case I_S2_mix
            by contradiction
          next
            case Pair
            by contradiction
          next
            case R_Data_advance_epoch
            by contradiction
          next
            case R_S2_mix
            by contradiction
          qed
        qed
      qed
    next
      case split_case_3
      solve( !Party( pid, r, p )[no_precomp] ▶₁ #i )
        case Pair_case_1
        solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₂ #i )
          case Pair
          solve( !PositionValue( ~pid, %e, roleB )[no_precomp] ▶₈ #i )
            case I_S2_mix
            by contradiction
          next
            case R_Data_advance_epoch
            by contradiction
          next
            case R_S2_mix
            by contradiction
          qed
        qed
      next
        case Pair_case_2
        solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₂ #i )
          case Pair
          solve( !PositionValue( ~pid, %e, roleB )[no_precomp] ▶₈ #i )
            case I_S2_mix
            by contradiction
          next
            case R_Data_advance_epoch
            by contradiction
          next
            case R_S2_mix
            by contradiction
          qed
        qed
      qed
    qed
  qed
qed

lemma position_unique [reuse, use_induction, heuristic={positions},
                       hide_lemma=kem_ciphertext_origin, hide_lemma=fresh_dk_origin,
                       hide_lemma=fresh_ss_origin, hide_lemma=encrypted_origin,
                       hide_lemma=extract_origin, hide_lemma=ratchet_key_origin,
                       hide_lemma=session_key_origin, hide_lemma=derived_ck_origin,
                       hide_lemma=derived_ck_predecessor, hide_lemma=initial_ck_secret,
                       hide_lemma=ck_secret, hide_lemma=cur_secret,
                       hide_lemma=declared_session_secret, hide_lemma=epoch_secret]:
  all-traces
  "∀ pid %e g h #i #j.
    ((Position( pid, %e, g ) @ #i) ∧ (Position( pid, %e, h ) @ #j)) ⇒
    (g = h)"
/*
guarded formula characterizing all counter-examples:
"∃ pid %e g h #i #j.
  (Position( pid, %e, g ) @ #i) ∧ (Position( pid, %e, h ) @ #j) ∧ ¬(g = h)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( Position( pid, %e, g ) @ #i )
    case I_S2_mix
    solve( splitEqs(0) )
      case split_case_1
      by contradiction
    next
      case split_case_2
      by contradiction
    next
      case split_case_3
      by contradiction
    qed
  next
    case Pair
    solve( Position( ~pid, %1, h ) @ #j )
      case Pair
      by contradiction
    qed
  next
    case R_Data_advance_epoch
    solve( splitEqs(0) )
      case split_case_1
      by contradiction
    next
      case split_case_2
      by contradiction
    next
      case split_case_3
      by contradiction
    qed
  next
    case R_Data_recovery_candidate
    solve( splitEqs(0) )
      case split_case_1
      by contradiction
    next
      case split_case_2
      by contradiction
    next
      case split_case_3
      by contradiction
    qed
  next
    case R_S2_mix
    solve( splitEqs(0) )
      case split_case_1
      by contradiction
    next
      case split_case_2
      by contradiction
    next
      case split_case_3
      by contradiction
    qed
  qed
qed

lemma generator_position [reuse, heuristic={positions}]:
  all-traces
  "∀ pid r %e ek #i.
    (EpGen( pid, r, %e, ek ) @ #i) ⇒
    (∃ #j. (Position( pid, %e, r ) @ #j) ∧ (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e ek #i.
  (EpGen( pid, r, %e, ek ) @ #i)
 ∧
  ∀ #j. (Position( pid, %e, r ) @ #j) ⇒ ¬(#j < #i)"
*/
simplify
solve( !PositionValue( pid, %e, r )[no_precomp] ▶₅ #i )
  case I_S2_mix
  by contradiction
next
  case Pair
  by contradiction
next
  case R_Data_advance_epoch
  by contradiction
next
  case R_S2_mix
  by contradiction
qed

lemma position_step [reuse, heuristic={positions},
                     hide_lemma=kem_ciphertext_origin, hide_lemma=fresh_dk_origin,
                     hide_lemma=fresh_ss_origin, hide_lemma=encrypted_origin,
                     hide_lemma=extract_origin, hide_lemma=ratchet_key_origin,
                     hide_lemma=session_key_origin, hide_lemma=derived_ck_origin,
                     hide_lemma=derived_ck_predecessor, hide_lemma=initial_ck_secret,
                     hide_lemma=ck_secret, hide_lemma=cur_secret,
                     hide_lemma=declared_session_secret, hide_lemma=epoch_secret]:
  all-traces
  "∀ pid %e g h #i #j.
    ((Position( pid, %e, g ) @ #i) ∧ (Position( pid, (%e%+%1), h ) @ #j)) ⇒
    (¬(g = h))"
/*
guarded formula characterizing all counter-examples:
"∃ pid %e g h #i #j.
  (Position( pid, %e, g ) @ #i) ∧ (Position( pid, (%e%+%1), h ) @ #j)
 ∧
  g = h"
*/
simplify
solve( Position( pid, %e.1, g ) @ #i )
  case I_S2_mix
  solve( splitEqs(2) )
    case split_case_1
    by contradiction
  next
    case split_case_2
    by contradiction
  next
    case split_case_3
    by contradiction
  qed
next
  case Pair
  by contradiction
next
  case R_Data_advance_epoch
  solve( splitEqs(2) )
    case split_case_1
    by contradiction
  next
    case split_case_2
    by contradiction
  next
    case split_case_3
    by contradiction
  qed
next
  case R_Data_recovery_candidate
  solve( splitEqs(2) )
    case split_case_1
    by contradiction
  next
    case split_case_2
    by contradiction
  next
    case split_case_3
    by contradiction
  qed
next
  case R_S2_mix
  solve( splitEqs(2) )
    case split_case_1
    by contradiction
  next
    case split_case_2
    by contradiction
  next
    case split_case_3
    by contradiction
  qed
qed

lemma generator_unique [reuse, heuristic={positions},
                        hide_lemma=kem_ciphertext_origin, hide_lemma=fresh_dk_origin,
                        hide_lemma=fresh_ss_origin, hide_lemma=encrypted_origin,
                        hide_lemma=extract_origin, hide_lemma=ratchet_key_origin,
                        hide_lemma=session_key_origin, hide_lemma=derived_ck_origin,
                        hide_lemma=derived_ck_predecessor, hide_lemma=initial_ck_secret,
                        hide_lemma=ck_secret, hide_lemma=cur_secret,
                        hide_lemma=declared_session_secret, hide_lemma=epoch_secret]:
  all-traces
  "∀ pid r p %e ek pk #i #j.
    ((EpGen( pid, r, %e, ek ) @ #i) ∧ (EpGen( pid, p, %e, pk ) @ #j)) ⇒
    ((r = p) ∧ (ek = pk))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r p %e ek pk #i #j.
  (EpGen( pid, r, %e, ek ) @ #i) ∧ (EpGen( pid, p, %e, pk ) @ #j)
 ∧
  ((¬(r = p)) ∨ (¬(ek = pk)))"
*/
simplify
by contradiction

lemma generator_parity [heuristic={positions},
                        hide_lemma=kem_ciphertext_origin, hide_lemma=fresh_dk_origin,
                        hide_lemma=fresh_ss_origin, hide_lemma=encrypted_origin,
                        hide_lemma=extract_origin, hide_lemma=ratchet_key_origin,
                        hide_lemma=session_key_origin, hide_lemma=derived_ck_origin,
                        hide_lemma=derived_ck_predecessor, hide_lemma=initial_ck_secret,
                        hide_lemma=ck_secret, hide_lemma=cur_secret,
                        hide_lemma=declared_session_secret, hide_lemma=epoch_secret]:
  all-traces
  "∀ pid r p %e ek pk #i #j.
    ((EpGen( pid, r, %e, ek ) @ #i) ∧ (EpGen( pid, p, (%e%+%1), pk ) @ #j)) ⇒
    (¬(r = p))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r p %e ek pk #i #j.
  (EpGen( pid, r, %e, ek ) @ #i) ∧ (EpGen( pid, p, (%e%+%1), pk ) @ #j)
 ∧
  r = p"
*/
simplify
by contradiction

lemma generator_has_position [heuristic={committed_position},
                              hide_lemma=derived_ck_origin, hide_lemma=derived_ck_predecessor,
                              hide_lemma=ck_secret, hide_lemma=cur_secret, hide_lemma=epoch_secret]:
  all-traces
  "∀ pid r %e ek #i.
    (EpGen( pid, r, %e, ek ) @ #i) ⇒
    (((r = roleA) ∧ (%e = %1)) ∨
     (∃ p #j. (Advance( pid, r, p, %e ) @ #j) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r %e ek #i.
  (EpGen( pid, r, %e, ek ) @ #i)
 ∧
  (((¬(r = roleA)) ∨ (¬(%e = %1)))) ∧
  (∀ p #j. (Advance( pid, r, p, %e ) @ #j) ⇒ ¬(#j < #i))"
*/
simplify
solve( !Index( pid, r, %e, r )[-, no_precomp] ▶₀ #i )
  case I_S2_classic_recovery_candidate
  by contradiction /* from formulas */
next
  case I_S2_mix
  by contradiction /* from formulas */
next
  case Pair
  by contradiction /* from formulas */
next
  case R_Data_advance_epoch
  by contradiction /* from formulas */
next
  case R_Data_recovery_candidate
  by contradiction /* from formulas */
qed
