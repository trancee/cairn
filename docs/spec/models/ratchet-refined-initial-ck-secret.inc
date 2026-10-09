/* Generated from Tamarin 1.12.0 verified disclosure-profile export. */

lemma initial_ck_secret [reuse, use_induction,
                         heuristic={key_birth}]:
  all-traces
  "∀ pid ck #i #j.
    ((Init( pid, ck ) @ #i) ∧ (!KU( ck ) @ #j)) ⇒
    (∃ #r. (RevCK( pid ) @ #r) ∧ (#r < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ck #i #j.
  (Init( pid, ck ) @ #i) ∧ (!KU( ck ) @ #j)
 ∧
  ∀ #r. (RevCK( pid ) @ #r) ⇒ ¬(#r < #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( !KU( ~ck ) @ #j )
    case Reveal_CK
    by contradiction /* from formulas */
  next
    case Reveal_SS
    solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr )
      case Decode_known_ciphertext
      solve( splitEqs(1) )
        case split_case_1
        solve( (#vl, 0) ~~> (#j, 0) )
          case Var_msg_t
          solve( (∃ pid #j.
                   (FreshSS( pid, ~ck, pk(~dk.1) ) @ #j) ∧ #j < #vk.2)  ∥
                 (∃ #j. (!KU( ~ck ) @ #j) ∧ #j < #vk.2) )
            case case_2
            by contradiction /* cyclic */
          qed
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
