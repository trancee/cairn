/* Generated from Tamarin 1.12.0's verified existential proof export. */
lemma executable [heuristic={witness}, hide_lemma=encrypted_origin,
                  hide_lemma=ek_authenticated, hide_lemma=ct_authenticated,
                  hide_lemma=derived_ck_predecessor]:
  exists-trace
  "∃ pid ck0 ck1 ck2 ek ct ss x y ki kr ki2 kr2 pq #p #u #r #a #b #g
     #c #d #s #t #i #j.
    (((((((((((((((((((((((((((((((((((((((((Init( pid, ck0 ) @ #p) ∧
                                            (I_Start( pid, roleA, x, 'none' ) @ #u)) ∧
                                           (ResumeStart( pid, roleA, (%1%+%1) ) @ #u)) ∧
                                          (R_Accept( pid, roleB, roleA, x, 'none', ki, kr ) @ #r)) ∧
                                         (ResumeStart( pid, roleB, (%1%+%1) ) @ #r)) ∧
                                        (I_Advance( pid, roleA, ck0, ck1, %1, %1 ) @ #a)) ∧
                                       (I_Commit( pid, roleA, roleB, x, 'none', ki, kr ) @ #a)) ∧
                                      (ResumeFinish( pid, roleA, (%1%+%1%+%1) ) @ #a)) ∧
                                     (R_Confirm( pid, roleB, roleA, 'none', ki, kr ) @ #b)) ∧
                                    (ConfirmedCK( pid, roleB, ck1, %1 ) @ #b)) ∧
                                   (ResumeFinish( pid, roleB, (%1%+%1%+%1) ) @ #b)) ∧
                                  (EpGen( pid, roleA, %1, ek ) @ #g)) ∧
                                 (EpEnc( pid, roleB, %1, ek, ct, ss ) @ #c)) ∧
                                (EpDec( pid, roleA, %1, ek, ct, ss ) @ #d)) ∧
                               (EpochHave( pid, roleA, %1, pq ) @ #d)) ∧
                              (Ready( pid, roleA, %1 ) @ #d)) ∧
                             (I_Start( pid, roleA, y, pq ) @ #s)) ∧
                            (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1) ) @ #s)) ∧
                           (R_Accept( pid, roleB, roleA, y, pq, ki2, kr2 ) @ #t)) ∧
                          (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1) ) @ #t)) ∧
                         (I_Advance( pid, roleA, ck1, ck2, %1, (%1%+%1) ) @ #i)) ∧
                        (I_Commit( pid, roleA, roleB, y, pq, ki2, kr2 ) @ #i)) ∧
                       (ResumeFinish( pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #i)) ∧
                      (MixedKey( pid, %1, ss, ek, ct, ck2 ) @ #i)) ∧
                     (R_Confirm( pid, roleB, roleA, pq, ki2, kr2 ) @ #j)) ∧
                    (ConfirmedCK( pid, roleB, ck2, (%1%+%1) ) @ #j)) ∧
                   (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #j)) ∧
                  (pq = <ss, h(ek), h(ct)>)) ∧
                 (#p < #u)) ∧
                (#u < #r)) ∧
               (#r < #a)) ∧
              (#a < #b)) ∧
             (#b < #g)) ∧
            (#g < #c)) ∧
           (#c < #d)) ∧
          (#d < #s)) ∧
         (#s < #t)) ∧
        (#t < #i)) ∧
       (#i < #j)) ∧
      (¬(∃ #v. RevCK( pid ) @ #v))) ∧
     (¬(∃ key #v. RevDK( pid, key ) @ #v))) ∧
    (¬(∃ secret #v. RevSS( pid, secret ) @ #v))"
/*
guarded formula characterizing all satisfying traces:
"∃ pid ck0 ck1 ck2 ek ct ss x y ki kr ki2 kr2 pq #p #u #r #a #b #g
   #c #d #s #t #i #j.
  (Init( pid, ck0 ) @ #p) ∧
  (I_Start( pid, roleA, x, 'none' ) @ #u) ∧
  (ResumeStart( pid, roleA, (%1%+%1) ) @ #u) ∧
  (R_Accept( pid, roleB, roleA, x, 'none', ki, kr ) @ #r) ∧
  (ResumeStart( pid, roleB, (%1%+%1) ) @ #r) ∧
  (I_Advance( pid, roleA, ck0, ck1, %1, %1 ) @ #a) ∧
  (I_Commit( pid, roleA, roleB, x, 'none', ki, kr ) @ #a) ∧
  (ResumeFinish( pid, roleA, (%1%+%1%+%1) ) @ #a) ∧
  (R_Confirm( pid, roleB, roleA, 'none', ki, kr ) @ #b) ∧
  (ConfirmedCK( pid, roleB, ck1, %1 ) @ #b) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1) ) @ #b) ∧
  (EpGen( pid, roleA, %1, ek ) @ #g) ∧
  (EpEnc( pid, roleB, %1, ek, ct, ss ) @ #c) ∧
  (EpDec( pid, roleA, %1, ek, ct, ss ) @ #d) ∧
  (EpochHave( pid, roleA, %1, pq ) @ #d) ∧
  (Ready( pid, roleA, %1 ) @ #d) ∧
  (I_Start( pid, roleA, y, pq ) @ #s) ∧
  (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1) ) @ #s) ∧
  (R_Accept( pid, roleB, roleA, y, pq, ki2, kr2 ) @ #t) ∧
  (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1) ) @ #t) ∧
  (I_Advance( pid, roleA, ck1, ck2, %1, (%1%+%1) ) @ #i) ∧
  (I_Commit( pid, roleA, roleB, y, pq, ki2, kr2 ) @ #i) ∧
  (ResumeFinish( pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #i) ∧
  (MixedKey( pid, %1, ss, ek, ct, ck2 ) @ #i) ∧
  (R_Confirm( pid, roleB, roleA, pq, ki2, kr2 ) @ #j) ∧
  (ConfirmedCK( pid, roleB, ck2, (%1%+%1) ) @ #j) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #j) ∧
  (pq = <ss, h(ek), h(ct)>)
 ∧
  (#p < #u) ∧
  (#u < #r) ∧
  (#r < #a) ∧
  (#a < #b) ∧
  (#b < #g) ∧
  (#g < #c) ∧
  (#c < #d) ∧
  (#d < #s) ∧
  (#s < #t) ∧
  (#t < #i) ∧
  (#i < #j) ∧
  (∀ #v. (RevCK( pid ) @ #v) ⇒ ⊥) ∧
  (∀ key #v. (RevDK( pid, key ) @ #v) ⇒ ⊥) ∧
  (∀ secret #v. (RevSS( pid, secret ) @ #v) ⇒ ⊥)"
*/
simplify
solve( I_Start( ~pid, roleA, x, 'none' ) @ #u )
case I_S1_classic
solve( ResumeStart( ~pid, roleA, (%1%+%1) ) @ #u )
case I_S1_classic
solve( !St( ~pid, roleA, ck.3, %e, g.2 )[no_precomp] ▶₂ #u )
case Pair
solve( R_Accept( ~pid, roleB, roleA, ~x, 'none', ki, kr.3 ) @ #r )
case R_S2_classic
solve( ResumeStart( ~pid, roleB, (%1%+%1) ) @ #r )
case R_S2_classic
solve( !St( ~pid, roleB, ck.3, %e, g.2 )[no_precomp] ▶₂ #r )
case Pair
solve( I_Advance( ~pid, roleA, ~ck.2, ck1, %1, %1 ) @ #a )
case I_S2_classic
solve( I_Commit( ~pid, roleA, roleB, ~x.1, 'none', kdf(ext(~ck, <~x.1, ~y.1, 'none'>), 'skI', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x.1>, ~y.1>)>), kdf(ext(~ck, <~x.1, ~y.1, 'none'>), 'skR', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x.1>, ~y.1>)>) ) @ #a )
case I_S2_classic
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1) ) @ #a )
case I_S2_classic
solve( IWait( ~pid, roleA, roleB, ~ck, %1, g, %1, g, ~x, '0', 'none', 'none', 'none', 'none', (%1%+%1) )[no_precomp] ▶₁ #a )
case I_S1_classic
solve( ConfirmedCK( ~pid, roleB, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), %1 ) @ #b.1 )
case R_Data_same_epoch
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1) ) @ #b.1 )
case R_Data_same_epoch
solve( R_Confirm( ~pid, roleB, roleA, 'none', kdf(ext(~ck, <~x, ~y, 'none'>), 'skI', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y >) >), kdf(ext(~ck, <~x, ~y, 'none'>), 'skR', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y >) >) ) @ #b.1 )
case R_Data_same_epoch
solve( RPending( ~pid, roleB, roleA, ck.3, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), %1, g.2, 'none', kdf(ext(~ck, <~x, ~y, 'none'>), 'skI', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), kdf(ext(~ck, <~x, ~y, 'none'>), 'skR', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), (%1%+%1) )[no_precomp] ▶₁ #b.1 )
case R_S2_classic
solve( !Index( ~pid, roleB, %1, roleA )[no_precomp] ▶₃ #b.1 )
case Pair
solve( CandidateState( ~pid, roleA, a.1, b )[no_precomp] ▶₂ #a )
case Pair
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #b )
case Pair
solve( I_Start( ~pid, roleA, y.1, <ss, h(pk(~dk)), h(ct)> ) @ #s )
case I_S1_mix
solve( ResumeStart( ~pid, roleA, (%1%+%1%+%1%+%1) ) @ #s )
case I_S1_mix
solve( !St( ~pid, roleA, ck.3, %e, g.2 )[no_precomp] ▶₃ #s )
case I_S2_classic
solve( R_Accept( ~pid, roleB, roleA, ~x.2, <ss, h(pk(~dk)), h(ct)>, ki2, kr2 ) @ #t )
case R_S2_mix
solve( ResumeStart( ~pid, roleB, (%1%+%1%+%1%+%1) ) @ #t )
case R_S2_mix
solve( !St( ~pid, roleB, ck.4, %e.1, g.3 )[no_precomp] ▶₃ #t )
case R_Data_same_epoch
solve( I_Advance( ~pid, roleA, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), ck2, %1, (%1%+%1) ) @ #i )
case I_S2_mix
solve( I_Commit( ~pid, roleA, roleB, ~x.3, <ss, h(pk(~dk)), h(ct)>, kdf(ext(ck.4, <~x.3, ~y.3, ss, h(pk(~dk)), h(ct)>), 'skI', <~pid, h(< <'S1', '1', kdf(ck.4, <'id', roleA>, ~pid), ~x.3>, ~y.3>) >), kdf(ext(ck.4, <~x.3, ~y.3, ss, h(pk(~dk)), h(ct)>), 'skR', <~pid, h(< <'S1', '1', kdf(ck.4, <'id', roleA>, ~pid), ~x.3>, ~y.3>) >) ) @ #i )
case I_S2_mix
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #i )
case I_S2_mix
solve( IWait( ~pid, roleA, roleB, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), %1, g.2, (%1%+%1), z, ~x.1, '1', <ss, h(pk(~dk)), h(ct)>, ss, pk(~dk), ct, (%1%+%1%+%1%+%1) )[no_precomp] ▶₁ #i )
case I_S1_mix
solve( ConfirmedCK( ~pid, roleB, kdf(ext(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >), (%1%+%1) ) @ #j )
case R_Data_advance_epoch
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #j )
case R_Data_advance_epoch
solve( R_Confirm( ~pid, roleB, roleA, <ss, h(pk(~dk)), h(ct)>, kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'skI', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA>, ~pid), ~x.1>, ~y.1>) >), kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'skR', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA>, ~pid), ~x.1>, ~y.1>) >) ) @ #j )
case R_Data_advance_epoch
solve( RPending( ~pid, roleB, roleA, ck.3, kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA>, ~pid), ~x.1>, ~y.1>) >), (%1%+%1), z, <ss, h(pk(~dk)), h(ct) >, kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'skI', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA>, ~pid), ~x.1>, ~y.1>) >), kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'skR', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA>, ~pid), ~x.1>, ~y.1>) >), (%1%+%1%+%1%+%1) )[no_precomp] ▶₁ #j )
case R_S2_mix
solve( !Index( ~pid, roleB, %1, g.2 )[no_precomp] ▶₃ #j )
case Pair
solve( MixedKey( ~pid, %1, ss, pk(~dk), ct, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1>, ~y.1>) >) ) @ #i )
case I_S2_mix
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #i )
case I_S2_classic
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #j )
case R_Data_same_epoch
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #u )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #r )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #s )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #s )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #t )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #t )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₆ #i )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₄ #j )
case Pair
solve( CandidateState( ~pid, roleB, a.2, b.1 )[no_precomp] ▶₂ #vr.3 )
case Pair
solve( CandidateState( ~pid, roleA, a.2, b.1 )[no_precomp] ▶₂ #vr.6 )
case Pair
solve( CandidateState( ~pid, roleB, a.2, b.1 )[no_precomp] ▶₂ #vr.6 )
case Pair
solve( BusySlot( ~pid, roleA, ( %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #i )
case Acquire_Resume
solve( BusySlot( ~pid, roleB, ( %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #j )
case Acquire_Resume
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr )
case Pair
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.1 )
case Pair
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.2 )
case Pair
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.2 )
case Pair
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.2 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.3 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.4 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.5 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.6 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.10 )
case Pair
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.8 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.10 )
case Pair
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.6 )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.8 )
case Pair
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.7 )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.8 )
case Pair
solve( !Index( ~pid, roleA, %1, roleA )[-, no_precomp] ▶₀ #g.2 )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₅ #g.2 )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₈ #t )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₅ #i )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₇ #j )
case Pair
solve( !Session( ~pid, roleA, ck.2, %1, g.1, ks.1, kr.1 )[no_precomp] ▶₂ #d )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.6 )
case Pair
solve( !Session( ~pid, roleA, ck.2, %1, roleA, ks.1, kr.1 )[-, no_precomp] ▶₁ #g.1 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.6 )
case Pair
solve( !Session( ~pid, roleB, ck.1, %1, g, ks, kr )[-, no_precomp] ▶₁ #c )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.6 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #g )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #d )
case I_S2_classic
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #c )
case R_S2_classic
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₄ #u )
case Pair
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₅ #r )
case Pair
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₄ #a )
case Pair
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₅ #b )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #g )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #c )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #d )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₇ #s )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₇ #t )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #i )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₆ #j )
case I_S2_classic
solve( DKMaterial( ~pid, roleA, ~dk ) ▶₃ #g )
case Prepare_DK
solve( EncMaterial( ~pid, roleB, pk(~dk), ct, ss ) ▶₃ #c )
case Prepare_encapsulation
solve( EpochHave( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) > ) @ #d )
case Receive_CT_tail
solve( Ready( ~pid, roleA, %1 ) @ #d )
case Receive_CT_tail
solve( !ReadyEpoch( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) > )[no_precomp] ▶₄ #s )
case Receive_CT_tail
solve( !Have( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)) )[no_precomp] ▶₅ #s )
case Receive_CT_tail
solve( !Have( ~pid, roleB, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)) )[no_precomp] ▶₄ #t )
case Encapsulate
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₀ #vr.6 )
case Pair
solve( !Party( ~pid, roleB, p.1 )[no_precomp] ▶₀ #vr.7 )
case Pair
solve( !Party( ~pid, roleB, p.1 )[no_precomp] ▶₀ #vr.13 )
case Pair
solve( !Index( ~pid, roleB, %1, roleA )[no_precomp] ▶₁ #vr.13 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₂ #vr.8 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.14 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.9 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.14 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₂ #vr.10 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.14 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.11 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.14 )
case Pair
solve( !Session( ~pid, roleB, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.12 )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.14 )
case Pair
solve( !Session( ~pid, roleB, ck.1, %1, roleA, ks, kr )[no_precomp] ▶₂ #vr.13 )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.14 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.8 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.9 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.10 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.11 )
case I_S2_classic
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.12 )
case R_S2_classic
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.13 )
case R_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.8 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.9 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.10 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.11 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.12 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.13 )
case I_S2_classic
solve( !GenKey( ~pid, roleA, %1, ~dk )[no_precomp] ▶₀ #d )
case Generate_EK
solve( !CT0( ~pid, roleA, %1, kem(~ss, pk(~dk)) ) ▶₁ #d )
case Receive_CT_prefix
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.14 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.15 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.14 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.14 )
case I_S2_classic
solve( !KU( senc(< 'CT', %1, 'half', kem(~ss, pk(~dk)) >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk )
case Send_CT_tail
solve( !Session( ~pid, roleB, ck.1, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₂ #vr.15 )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.16 )
case Pair
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.15 )
case R_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.15 )
case I_S2_classic
solve( !Progress( ~pid, roleB, %1, 'CT', 'half' )[no_precomp] ▶₁ #vr.15 )
case Receive_progress_CT
solve( !Session( ~pid, roleB, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.16 )
case R_Data_same_epoch
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.17 )
case Pair
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.16 )
case R_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.16 )
case I_S2_classic
solve( !KU( senc(< 'EK', %1, 'half', pk(~dk) >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.28 )
case Send_EK_tail
solve( !Session( ~pid, roleA, ck.1, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₂ #vr.17 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.17 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.17 )
case I_S2_classic
solve( !Progress( ~pid, roleA, %1, 'EK', 'half' )[no_precomp] ▶₁ #vr.17 )
case Receive_progress_EK
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.18 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.19 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.18 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.18 )
case I_S2_classic
solve( !KU( kdf(~ck, < 'id', roleA >, ~pid) ) @ #vk.10 )
case I_S1_classic
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₁ #vr.19 )
case Pair
solve( ResumeSlot( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.24 )
case Pair
solve( !KU( mac(kdf(~ck, < 'authI', roleA >, ~pid), < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >) ) @ #vk.12 )
case I_S1_classic
solve( !KU( mac(kdf(~ck, 'authR', ~pid), < 'S2', h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #vk.15 )
case R_S2_classic
solve( !KU( senc('data', kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.16 )
case I_S2_classic
solve( !KU( kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid) ) @ #vk.20 )
case I_S1_mix
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₁ #vr.25 )
case Pair
solve( !Party( ~pid, g.1, ng )[no_precomp] ▶₂ #vr.25 )
case Pair_case_1
solve( ResumeSlot( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.30 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.31 )
case I_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b.1 )[no_precomp] ▶₂ #vr.32 )
case Pair
solve( !KU( mac(kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'authI', roleA >, ~pid), < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >) ) @ #vk.22 )
case I_S1_mix
solve( !KU( mac(kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), 'authR', ~pid), < 'S2', h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) ) @ #vk.25 )
case R_S2_mix
solve( !KU( senc('data', kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'skI', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >)) ) @ #vk.26 )
case I_S2_mix
solve( !KU( senc(< 'CT', %1, 'prefix', kem(~ss, pk(~dk)) >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.28 )
case Encapsulate
solve( !KU( senc(< 'EK', %1, 'prefix', pk(~dk) >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.29 )
case Generate_EK
solve( !KU( senc(< 'PROGRESS', %1, 'CT', 'half' >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.30 )
case Receive_CT_prefix
solve( !Party( pid.1, r.1, p.1 )[no_precomp] ▶₀ #vr.33 )
case Pair_case_1
solve( !Index( ~pid.1, roleA, %1, roleA )[-, no_precomp] ▶₀ #vr.32 )
case Pair
solve( !PositionValue( ~pid.1, %1, roleA )[no_precomp] ▶₅ #vr.32 )
case Pair
solve( !Session( ~pid.1, roleA, ck.2, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₁ #vr.31 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.31 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.31 )
case I_S2_classic
solve( !KU( senc(< 'PROGRESS', %1, 'EK', 'half' >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.31 )
case Receive_EK_prefix
solve( !Party( pid.1, r.1, p.1 )[no_precomp] ▶₀ #vr.32 )
case Pair_case_2
solve( !Index( ~pid.1, roleB, %1, roleA )[no_precomp] ▶₁ #vr.32 )
case Pair
solve( !Session( ~pid.1, roleB, ck.2, %1, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₂ #vr.32 )
case R_Data_same_epoch
solve( CandidateState( ~pid.1, roleB, a.1, b.1 )[no_precomp] ▶₂ #vr.34 )
case Pair
solve( ResumeSlot( ~pid.1, roleB, %s.1 )[no_precomp] ▶₀ #vr.35 )
case Pair
solve( !Index( ~pid.1, roleB, %1, roleA )[no_precomp] ▶₃ #vr.34 )
case Pair
solve( RPending( ~pid.1, roleB, p.1, ck.3, ck.2, %1, roleA, pq, kr, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.34 )
case R_S2_classic
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.32 )
case R_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.32 )
case I_S2_classic
solve( !KU( ~x ) @ #vk.26 )
case I_S1_classic
solve( !KU( ~y ) @ #vk.27 )
case R_S2_classic
solve( !KU( ~x.1 ) @ #vk.29 )
case I_S1_mix
solve( !KU( ~y.1 ) @ #vk.30 )
case R_S2_mix
solve( !KU( pk(~dk) ) @ #vk.31 )
case Prepare_DK
solve( !Index( ~pid, roleA, %1, roleA )[no_precomp] ▶₅ #a )
case Pair
SOLVED // trace found
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
qed
