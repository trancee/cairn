/* Generated from Tamarin 1.12.0 raw-source certificate exports. */

lemma ck_disclosure_origin [sources]:
  all-traces
  "∀ pid ck #i.
    (RevCKv( pid, ck ) @ #i) ⇒
    ((∃ #j. (Init( pid, ck ) @ #j) ∧ (#j < #i)) ∨
     (∃ old prk ctx #j.
       ((DerivedCK( pid, old, kdf(prk, 'ratchet', <pid, ctx>) ) @ #j) ∧
        (ck = kdf(prk, 'ratchet', <pid, ctx>))) ∧
       (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ck #i.
  (RevCKv( pid, ck ) @ #i)
 ∧
  (∀ #j. (Init( pid, ck ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ old prk ctx #j.
    (DerivedCK( pid, old, kdf(prk, 'ratchet', <pid, ctx>) ) @ #j) ∧
    (ck = kdf(prk, 'ratchet', <pid, ctx>))
   ⇒
    ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction /* from formulas */
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j. (Init( pid, ck ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ old prk ctx #j.
           (DerivedCK( pid, old, kdf(prk, 'ratchet', <pid, ctx>) ) @ #j) ∧
           (ck = kdf(prk, 'ratchet', <pid, ctx>))
          ∧
           (¬(last(#j))) ∧ (#j < #i)) )
    case case_1
    solve( !CKValue( pid, ck )[no_precomp] ▶₀ #i )
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
    case case_2
    by contradiction /* from formulas */
  next
    case case_3
    by contradiction /* from formulas */
  qed
qed

lemma ss_disclosure_origin [sources]:
  all-traces
  "∀ pid ss #i.
    (RevSS( pid, ss ) @ #i) ⇒
    ((∃ ek #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (#j < #i)) ∨
     (∃ r e ek ct #j. (EpDec( pid, r, e, ek, ct, ss ) @ #j) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ss #i.
  (RevSS( pid, ss ) @ #i)
 ∧
  (∀ ek #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ r e ek ct #j. (EpDec( pid, r, e, ek, ct, ss ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction /* from formulas */
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ ek #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ r e ek ct #j.
           (EpDec( pid, r, e, ek, ct, ss ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
    case case_1
    solve( !Have( pid, r, %e, pq, ss, ek, ct )[-, no_precomp] ▶₁ #i )
      case Encapsulate
      by contradiction /* from formulas */
    next
      case Receive_CT_tail
      by contradiction /* from formulas */
    qed
  next
    case case_2
    by contradiction /* from formulas */
  next
    case case_3
    by contradiction /* from formulas */
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

