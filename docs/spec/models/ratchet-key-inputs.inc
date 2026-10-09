/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma declared_keys_have_inputs :
  all-traces
  "∀ pid r ks kr #i.
    (KeyDeclared( pid, r, ks, kr ) @ #i) ⇒
    (∃ ck x y pq ctx.
      (DerivedCK( pid, ck, kdf(ext(ck, <x, y, pq>), 'ratchet', ctx) ) @ #i) ∧
      (((ks = kdf(ext(ck, <x, y, pq>), 'skI', ctx)) ∧
        (kr = kdf(ext(ck, <x, y, pq>), 'skR', ctx))) ∨
       ((ks = kdf(ext(ck, <x, y, pq>), 'skR', ctx)) ∧
        (kr = kdf(ext(ck, <x, y, pq>), 'skI', ctx)))))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r ks kr #i.
  (KeyDeclared( pid, r, ks, kr ) @ #i)
 ∧
  ∀ ck x y pq ctx.
   (DerivedCK( pid, ck, kdf(ext(ck, <x, y, pq>), 'ratchet', ctx) ) @ #i)
  ⇒
   (((¬(ks = kdf(ext(ck, <x, y, pq>), 'skI', ctx))) ∨
     (¬(kr = kdf(ext(ck, <x, y, pq>), 'skR', ctx))))) ∧
   (((¬(ks = kdf(ext(ck, <x, y, pq>), 'skR', ctx))) ∨
     (¬(kr = kdf(ext(ck, <x, y, pq>), 'skI', ctx)))))"
*/
simplify
solve( KeyDeclared( pid, r, ks, kr ) @ #i )
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
