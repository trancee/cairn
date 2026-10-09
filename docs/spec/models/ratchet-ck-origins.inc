/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma ratchet_key_reveal_owner [reuse, heuristic={key_birth}]:
  all-traces
  "∀ pid q prk ctx #i.
    (RevCKv( q, kdf(prk, 'ratchet', <pid, ctx>) ) @ #i) ⇒ (pid = q)"
/*
guarded formula characterizing all counter-examples:
"∃ pid q prk ctx #i.
  (RevCKv( q, kdf(prk, 'ratchet', <pid, ctx>) ) @ #i) ∧ ¬(pid = q)"
*/
simplify
solve( !CKValue( q, kdf(prk, 'ratchet', <pid, ctx>) )[no_precomp] ▶₀ #i )
  case I_S2_classic
  by contradiction
next
  case I_S2_classic_recovery_candidate
  by contradiction /* from formulas */
next
  case I_S2_mix
  by contradiction
next
  case R_S2_classic
  by contradiction
next
  case R_S2_mix
  by contradiction
qed

lemma derived_ck_origin [reuse, heuristic={key_origin}]:
  all-traces
  "∀ pid old new #i #j.
    ((DerivedCK( pid, old, new ) @ #i) ∧ (!KU( new ) @ #j)) ⇒
    ((∃ #k. (!KU( old ) @ #k) ∧ (#k < #j)) ∨
     (∃ #r. (RevCK( pid ) @ #r) ∧ (#r < #j)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid old new #i #j.
  (DerivedCK( pid, old, new ) @ #i) ∧ (!KU( new ) @ #j)
 ∧
  (∀ #k. (!KU( old ) @ #k) ⇒ ¬(#k < #j)) ∧
  (∀ #r. (RevCK( pid ) @ #r) ⇒ ¬(#r < #j))"
*/
simplify
solve( DerivedCK( pid, old, new ) @ #i )
  case I_S2_classic
  solve( (∃ #j.2.
           (!KU( ext(old, <x, y, 'none'>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
         (∃ pid.1 #j.2.
           (RevCKv( pid.1,
                    kdf(ext(old, <x, y, 'none'>), 'ratchet',
                        <pid, h(<<'S1', '0', kdf(old, <'id', r>, pid), x>, y>)>)
            ) @ #j.2)
          ∧
           #j.2 < #j.1) )
    case case_1
    by contradiction
  next
    case case_2
    by contradiction
  qed
next
  case I_S2_classic_recovery_candidate
  solve( splitEqs(0) )
    case split_case_1
    solve( (∃ #j.2.
             (!KU( ext(old, <x, y, 'none'>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, y, 'none'>), 'ratchet',
                          <pid, h(<<'S1', '0', kdf(old, <'id', r>, pid), x>, y>)>)
              ) @ #j.2)
            ∧
             #j.2 < #j.1) )
      case case_1
      by contradiction /* from formulas */
    next
      case case_2
      by contradiction /* from formulas */
    qed
  next
    case split_case_2
    solve( (∃ #j.2.
             (!KU( ext(old, <x, y, 'none'>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, y, 'none'>), 'ratchet',
                          <pid, h(<<'S1', '0', kdf(old, <'id', r>, pid), x>, y>)>)
              ) @ #j.2)
            ∧
             #j.2 < #j.1) )
      case case_1
      by contradiction /* from formulas */
    next
      case case_2
      by contradiction /* from formulas */
    qed
  next
    case split_case_3
    solve( (∃ #j.2.
             (!KU( ext(old, <x, y, 'none'>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, y, 'none'>), 'ratchet',
                          <pid, h(<<'S1', '0', kdf(old, <'id', r>, pid), x>, y>)>)
              ) @ #j.2)
            ∧
             #j.2 < #j.1) )
      case case_1
      by contradiction /* from formulas */
    next
      case case_2
      by contradiction /* from formulas */
    qed
  qed
next
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( (∃ #j.2.
             (!KU( ext(old, <x, y, ss, h(ek), h(ct)>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(old, <'id', r>, pid), x>, y>)>)
              ) @ #j.2)
            ∧
             #j.2 < #j.1) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case split_case_2
    solve( (∃ #j.2.
             (!KU( ext(old, <x, y, ss, h(ek), h(ct)>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(old, <'id', r>, pid), x>, y>)>)
              ) @ #j.2)
            ∧
             #j.2 < #j.1) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case split_case_3
    solve( (∃ #j.2.
             (!KU( ext(old, <x, y, ss, h(ek), h(ct)>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(old, <'id', r>, pid), x>, y>)>)
              ) @ #j.2)
            ∧
             #j.2 < #j.1) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  qed
next
  case R_S2_classic
  solve( (∃ #j.1. (!KU( ext(old, <x, ~y, 'none'>) ) @ #j.1) ∧ #j.1 < #j)  ∥
         (∃ pid.1 #j.1.
           (RevCKv( pid.1,
                    kdf(ext(old, <x, ~y, 'none'>), 'ratchet',
                        <pid, h(<<'S1', '0', kdf(old, <'id', p>, pid), x>, ~y>)>)
            ) @ #j.1)
          ∧
           #j.1 < #j) )
    case case_1
    by contradiction
  next
    case case_2
    by contradiction
  qed
next
  case R_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( (∃ #j.1.
             (!KU( ext(old, <x, ~y, ss, h(ek), h(ct)>) ) @ #j.1) ∧ #j.1 < #j)  ∥
           (∃ pid.1 #j.1.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(old, <'id', p>, pid), x>, ~y>)>)
              ) @ #j.1)
            ∧
             #j.1 < #j) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case split_case_2
    solve( (∃ #j.1.
             (!KU( ext(old, <x, ~y, ss, h(ek), h(ct)>) ) @ #j.1) ∧ #j.1 < #j)  ∥
           (∃ pid.1 #j.1.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(old, <'id', p>, pid), x>, ~y>)>)
              ) @ #j.1)
            ∧
             #j.1 < #j) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case split_case_3
    solve( (∃ #j.1.
             (!KU( ext(old, <x, ~y, ss, h(ek), h(ct)>) ) @ #j.1) ∧ #j.1 < #j)  ∥
           (∃ pid.1 #j.1.
             (RevCKv( pid.1,
                      kdf(ext(old, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(old, <'id', p>, pid), x>, ~y>)>)
              ) @ #j.1)
            ∧
             #j.1 < #j) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  qed
qed

lemma derived_ck_predecessor [reuse, heuristic={key_birth}]:
  all-traces
  "∀ pid old new #i.
    (DerivedCK( pid, old, new ) @ #i) ⇒
    (∃ #k. (CK( pid, old ) @ #k) ∧ (#k < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ pid old new #i.
  (DerivedCK( pid, old, new ) @ #i)
 ∧
  ∀ #k. (CK( pid, old ) @ #k) ⇒ ¬(#k < #i)"
*/
simplify
solve( DerivedCK( pid, old, new ) @ #i )
  case I_S2_classic
  solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
    case I_S2_classic
    by contradiction
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction
  next
    case Pair
    by contradiction
  next
    case R_S2_classic
    by contradiction
  next
    case R_S2_mix
    by contradiction
  qed
next
  case I_S2_classic_recovery_candidate
  solve( splitEqs(0) )
    case split_case_1
    solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
      case I_S2_classic
      by contradiction /* from formulas */
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction /* from formulas */
    next
      case Pair
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
    solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
      case I_S2_classic
      by contradiction /* from formulas */
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction /* from formulas */
    next
      case Pair
      by contradiction /* from formulas */
    next
      case R_S2_classic
      by contradiction /* from formulas */
    next
      case R_S2_mix
      by contradiction /* from formulas */
    qed
  next
    case split_case_3
    solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
      case I_S2_classic
      by contradiction /* from formulas */
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction /* from formulas */
    next
      case Pair
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
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_2
    solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_3
    solve( !CKValue( pid, old )[no_precomp] ▶₄ #i )
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
next
  case R_S2_classic
  solve( !CKValue( pid, old )[no_precomp] ▶₅ #i )
    case I_S2_classic
    by contradiction
  next
    case I_S2_classic_recovery_candidate
    by contradiction /* from formulas */
  next
    case I_S2_mix
    by contradiction
  next
    case Pair
    by contradiction
  next
    case R_S2_classic
    by contradiction
  next
    case R_S2_mix
    by contradiction
  qed
next
  case R_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( !CKValue( pid, old )[no_precomp] ▶₇ #i )
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_2
    solve( !CKValue( pid, old )[no_precomp] ▶₇ #i )
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_3
    solve( !CKValue( pid, old )[no_precomp] ▶₇ #i )
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Pair
      by contradiction
    next
      case R_S2_classic
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
qed
