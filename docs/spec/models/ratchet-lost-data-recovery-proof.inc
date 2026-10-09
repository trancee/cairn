/* Generated from Tamarin 1.12.0's verified existential proof export. */
lemma lost_data_recovery [heuristic={witness},
                          hide_lemma=encrypted_origin, hide_lemma=ek_authenticated,
                          hide_lemma=ct_authenticated, hide_lemma=derived_ck_predecessor]:
  exists-trace
  "∃ pid ck0 ck1 ck2 ck3 ek ct ss x y z ki kr ki2 kr2 ki3 kr3 pq #p
     #u #r #a #b #g #c #d #s #t #i #j #u3 #r3 #a3 #b3.
    (((((((((((((((((((((((((((((((((((((((((((((((((((((((((Init( pid,
                                                                   ck0
                                                             ) @ #p) ∧
                                                            (I_Start( pid, roleA, x, 'none'
                                                             ) @ #u)) ∧
                                                           (ResumeStart( pid, roleA, (%1%+%1)
                                                            ) @ #u)) ∧
                                                          (R_Accept( pid, roleB, roleA, x, 'none',
                                                                     ki, kr
                                                           ) @ #r)) ∧
                                                         (ResumeStart( pid, roleB, (%1%+%1)
                                                          ) @ #r)) ∧
                                                        (I_Advance( pid, roleA, ck0, ck1, %1, %1
                                                         ) @ #a)) ∧
                                                       (I_Commit( pid, roleA, roleB, x, 'none', ki,
                                                                  kr
                                                        ) @ #a)) ∧
                                                      (ResumeFinish( pid, roleA, (%1%+%1%+%1)
                                                       ) @ #a)) ∧
                                                     (R_Confirm( pid, roleB, roleA, 'none', ki, kr
                                                      ) @ #b)) ∧
                                                    (ConfirmedCK( pid, roleB, ck1, %1 ) @ #b)) ∧
                                                   (ResumeFinish( pid, roleB, (%1%+%1%+%1)
                                                    ) @ #b)) ∧
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
                                     (Timeout( pid, roleB, ck2, (%1%+%1) ) @ #j)) ∧
                                    (CandidateBefore( pid, roleB, ck1, 'none' ) @ #j)) ∧
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
                    (¬(∃ secret #v. RevSS( pid, secret ) @ #v))) ∧
                   (I_Start( pid, roleA, z, 'none' ) @ #u3)) ∧
                  (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #u3)) ∧
                 (R_Accept( pid, roleB, roleA, z, 'none', ki3, kr3 ) @ #r3)) ∧
                (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #r3)) ∧
               (I_Advance( pid, roleA, ck2, ck3, (%1%+%1), (%1%+%1) ) @ #a3)) ∧
              (I_Commit( pid, roleA, roleB, z, 'none', ki3, kr3 ) @ #a3)) ∧
             (ResumeFinish( pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #a3)) ∧
            (CandidateBefore( pid, roleA, ck2, 'none' ) @ #a3)) ∧
           (ConfirmedCK( pid, roleB, ck3, (%1%+%1) ) @ #b3)) ∧
          (R_Confirm( pid, roleB, roleA, 'none', ki3, kr3 ) @ #b3)) ∧
         (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #b3)) ∧
        (CandidateBefore( pid, roleB, ck1, ck2 ) @ #b3)) ∧
       (#j < #u3)) ∧
      (#u3 < #r3)) ∧
     (#r3 < #a3)) ∧
    (#a3 < #b3)"
/*
guarded formula characterizing all satisfying traces:
"∃ pid ck0 ck1 ck2 ck3 ek ct ss x y z ki kr ki2 kr2 ki3 kr3 pq #p
   #u #r #a #b #g #c #d #s #t #i #j #u3 #r3 #a3 #b3.
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
  (Timeout( pid, roleB, ck2, (%1%+%1) ) @ #j) ∧
  (CandidateBefore( pid, roleB, ck1, 'none' ) @ #j) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #j) ∧
  (pq = <ss, h(ek), h(ct)>) ∧
  (I_Start( pid, roleA, z, 'none' ) @ #u3) ∧
  (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #u3) ∧
  (R_Accept( pid, roleB, roleA, z, 'none', ki3, kr3 ) @ #r3) ∧
  (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #r3) ∧
  (I_Advance( pid, roleA, ck2, ck3, (%1%+%1), (%1%+%1) ) @ #a3) ∧
  (I_Commit( pid, roleA, roleB, z, 'none', ki3, kr3 ) @ #a3) ∧
  (ResumeFinish( pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #a3) ∧
  (CandidateBefore( pid, roleA, ck2, 'none' ) @ #a3) ∧
  (ConfirmedCK( pid, roleB, ck3, (%1%+%1) ) @ #b3) ∧
  (R_Confirm( pid, roleB, roleA, 'none', ki3, kr3 ) @ #b3) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #b3) ∧
  (CandidateBefore( pid, roleB, ck1, ck2 ) @ #b3)
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
  (∀ secret #v. (RevSS( pid, secret ) @ #v) ⇒ ⊥) ∧
  (#j < #u3) ∧
  (#u3 < #r3) ∧
  (#r3 < #a3) ∧
  (#a3 < #b3)"
*/
simplify
solve( I_Commit( ~pid, roleA, roleB, x, 'none', ki, kr.3 ) @ #a )
case I_S2_classic
solve( I_Commit( ~pid, roleA, roleB, y.1, <ss, h(pk(~dk)), h(ct)>, ki2, kr2 ) @ #i )
case I_S2_mix
solve( I_Commit( ~pid, roleA, roleB, z.1, 'none', ki3, kr3 ) @ #a3 )
case I_S2_classic
solve( I_Advance( ~pid, roleA, ~ck.5, ck1, %1, %1 ) @ #a )
case I_S2_classic
solve( I_Advance( ~pid, roleA, kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>)>), ck2, %1, (%1%+%1) ) @ #i )
case I_S2_mix
solve( I_Advance( ~pid, roleA, kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <y.2, y.3, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <'id', roleA>, ~pid), y.2>, y.3>) >), ck3, (%1%+%1), (%1%+%1) ) @ #a3 )
case I_S2_classic
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1) ) @ #a )
case I_S2_classic
solve( ConfirmedCK( ~pid, roleB, kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), %1 ) @ #b.3 )
case R_Data_same_epoch
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1) ) @ #b.3 )
case R_Data_same_epoch
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #i )
case I_S2_mix
solve( Timeout( ~pid, roleB, kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y >) >), <y.1, y.2, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <'id', roleA>, ~pid), y.1>, y.2>) >), (%1%+%1) ) @ #j )
case R_Timeout
solve( CandidateBefore( ~pid, roleB, kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x >, y>) >), 'none' ) @ #j )
case R_Timeout
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #j )
case R_Timeout
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #a3 )
case I_S2_classic
solve( CandidateBefore( ~pid, roleA, kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <y.1, y.2, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <'id', roleA>, ~pid), y.1>, y.2>) >), 'none' ) @ #a3 )
case I_S2_classic
solve( ConfirmedCK( ~pid, roleB, kdf(ext(kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <y.1, y.2, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <'id', roleA>, ~pid), y.1>, y.2>) >), <z, y.3, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <y.1, y.2, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <'id', roleA>, ~pid), y.1>, y.2>) >), <'id', roleA>, ~pid), z>, y.3>) >), (%1%+%1) ) @ #b3 )
case R_Data_recovery_candidate
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #b3 )
case R_Data_recovery_candidate
solve( CandidateBefore( ~pid, roleB, kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x >, y>) >), kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <y.1, y.2, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <'id', roleA>, ~pid), y.1>, y.2>) >) ) @ #b3 )
case R_Data_recovery_candidate
solve( I_Start( ~pid, roleA, x, 'none' ) @ #u )
case I_S1_classic
solve( I_Start( ~pid, roleA, y.1, <ss, h(pk(~dk)), h(ct)> ) @ #s.1 )
case I_S1_mix
solve( I_Start( ~pid, roleA, z, 'none' ) @ #u3 )
case I_S1_classic
solve( ResumeStart( ~pid, roleA, (%1%+%1) ) @ #u )
case I_S1_classic
solve( R_Accept( ~pid, roleB, roleA, ~x, 'none', kdf(ext(~ck, <~x, y, 'none'>), 'skI', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, y>) >), kdf(ext(~ck, <~x, y, 'none'>), 'skR', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, y>) >) ) @ #r )
case R_S2_classic
solve( ResumeStart( ~pid, roleB, (%1%+%1) ) @ #r )
case R_S2_classic
solve( R_Confirm( ~pid, roleB, roleA, 'none', kdf(ext(~ck, <~x, ~y, 'none'>), 'skI', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), kdf(ext(~ck, <~x, ~y, 'none'>), 'skR', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >) ) @ #b.2 )
case R_Data_same_epoch
solve( ResumeStart( ~pid, roleA, (%1%+%1%+%1%+%1) ) @ #s.1 )
case I_S1_mix
solve( R_Accept( ~pid, roleB, roleA, ~x.1, <ss, h(pk(~dk)), h(ct)>, kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), <~x.1, y.1, ss, h(pk(~dk)), h(ct)>), 'skI', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <'id', roleA>, ~pid), ~x.1>, y.1>) >), kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), <~x.1, y.1, ss, h(pk(~dk)), h(ct)>), 'skR', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <'id', roleA>, ~pid), ~x.1>, y.1>) >) ) @ #t )
case R_S2_mix
solve( ResumeStart( ~pid, roleB, (%1%+%1%+%1%+%1) ) @ #t )
case R_S2_mix
solve( ResumeStart( ~pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #u3 )
case I_S1_classic
solve( R_Accept( ~pid, roleB, roleA, ~x.2, 'none', kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1>, ~y.1>) >), <~x.2, y.2, 'none'>), 'skI', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), <'id', roleA >, ~pid), ~x.2>, y.2>) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1>, ~y.1>) >), <~x.2, y.2, 'none'>), 'skR', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), <'id', roleA >, ~pid), ~x.2>, y.2>) >) ) @ #r3 )
case R_S2_classic
solve( ResumeStart( ~pid, roleB, (%1%+%1%+%1%+%1%+ %1%+%1) ) @ #r3 )
case R_S2_classic
solve( R_Confirm( ~pid, roleB, roleA, 'none', kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), <~x.2, ~y.2, 'none'>), 'skI', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), <'id', roleA >, ~pid), ~x.2>, ~y.2>) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), <~x.2, ~y.2, 'none'>), 'skR', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), <'id', roleA >, ~pid), ~x.2>, ~y.2>) >) ) @ #b3 )
case R_Data_recovery_candidate
solve( MixedKey( ~pid, %1, ss, pk(~dk), ct, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(ct)>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1>, ~y.1>) >) ) @ #i )
case I_S2_mix
solve( EpochHave( ~pid, roleA, %1, <ss, h(pk(~dk)), h(ct)> ) @ #d )
case Receive_CT_tail
solve( IWait( ~pid, roleA, roleB, ~ck, %1, g, %1, g, ~x, '0', 'none', 'none', 'none', 'none', (%1%+%1) )[no_precomp] ▶₁ #a )
case I_S1_classic
solve( IWait( ~pid, roleA, roleB, kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), %1, g.4, (%1%+%1), z.1, ~x.1, '1', <ss, h(pk(~dk)), h(ct)>, ss, pk(~dk), ct, (%1%+%1%+%1%+%1) )[no_precomp] ▶₁ #i )
case I_S1_mix
solve( IWait( ~pid, roleA, roleB, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', <~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1>) >), (%1%+%1), g.1, (%1%+%1), g.1, ~x.2, '0', 'none', 'none', 'none', 'none', (%1%+%1%+%1%+ %1%+%1%+%1) )[no_precomp] ▶₁ #a3 )
case I_S1_classic
solve( RPending( ~pid, roleB, roleA, ck.3, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, g.9, 'none', kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), (%1%+%1) )[no_precomp] ▶₁ #b.2 )
case R_S2_classic
solve( RPending( ~pid, roleB, p, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), (%1%+%1 ), g.5, pq, ki, kr.2, (%1%+ %1%+ %1%+%1 ) )[no_precomp] ▶₁ #j )
case R_S2_mix
solve( RPending( ~pid, roleB, roleA, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid), ~x.2 >, ~y.2 >) >), (%1%+ %1), z, 'none', kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid), ~x.2 >, ~y.2 >) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid), ~x.2 >, ~y.2 >) >), (%1%+ %1%+ %1%+ %1%+ %1%+ %1) )[no_precomp] ▶₁ #b3 )
case R_S2_classic
solve( CandidateState( ~pid, roleA, a.1, b )[no_precomp] ▶₂ #a )
case Pair
solve( CandidateState( ~pid, roleA, a.1, b )[no_precomp] ▶₂ #i )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.3, %e, g.8, %e, g.8, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.6 )
case I_S1_classic
solve( CandidateState( ~pid, roleA, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), 'none' )[no_precomp] ▶₂ #a3 )
case I_S2_mix
solve( CandidateState( ~pid, roleB, a.1, b.1 )[no_precomp] ▶₂ #b )
case Pair
solve( CandidateState( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), 'none' )[no_precomp] ▶₂ #j )
case R_Data_same_epoch
solve( RPending( ~pid, roleB, p.2, ck.5, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %e.1, g.9, pq, ki, kr.3, ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.11 )
case R_S2_classic
solve( CandidateState( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₂ #b3 )
case R_Timeout
solve( RPending( ~pid, roleB, p.2, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), %e.1, g.9, pq, ki, kr.3, ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.12 )
case R_S2_mix
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr )
case Pair
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.1 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.2 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.3 )
case Pair
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.4 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.5 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.10 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.11 )
case Pair
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.11 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.12 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.2, ck.5, %e.1, g.9, %e.1, g.9, x.4, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.18 )
case I_S1_classic
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.13 )
case I_S2_mix
solve( IWait( ~pid, roleA, p.3, ck.6, %e.2, g.10, ( %e.2%+ %1 ), z.2, x.5, '1', < ss.1, h(ek), h(ct.1) >, ss.1, ek, ct.1, ( %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₁ #vr.22 )
case I_S1_mix
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.14 )
case R_Data_same_epoch
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.15 )
case R_Timeout
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.16 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.6, ck.9, %e.5, g.13, %e.5, g.13, x.6, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.30 )
case I_S1_classic
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.17 )
case R_Data_same_epoch
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.19 )
case Pair
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.20 )
case Pair
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.19 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.21 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.23 )
case Pair
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.23 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.25 )
case Pair
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.23 )
case Pair
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.20 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.4, ck.7, %e.3, g.11, %e.3, g.11, x.5, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.23 )
case I_S1_classic
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.21 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.5, ck.8, %e.4, g.12, %e.4, g.12, x.6, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.27 )
case I_S1_classic
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.22 )
case R_Data_same_epoch
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.24 )
case Pair
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.18 )
case Pair
solve( !Index( ~pid, roleA, %1, g )[no_precomp] ▶₅ #a )
case Pair
solve( !Index( ~pid, roleA, ( %1%+ %1 ), g )[no_precomp] ▶₅ #a3 )
case I_S2_mix
solve( !Index( ~pid, roleB, %1, g.1 )[no_precomp] ▶₃ #b )
case Pair
solve( !Index( ~pid, roleB, %1, oldg )[no_precomp] ▶₃ #b3 )
case Pair
solve( !Index( ~pid, roleA, %1, roleA )[-, no_precomp] ▶₀ #g.5 )
case Pair
solve( !St( ~pid, roleA, ~ck, %1, roleA )[no_precomp] ▶₂ #u )
case Pair
solve( !St( ~pid, roleA, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), ( %1%+ %1 ), g )[no_precomp] ▶₂ #u3 )
case I_S2_mix
solve( !St( ~pid, roleB, ~ck, %1, roleA )[no_precomp] ▶₂ #r )
case Pair
solve( !St( ~pid, roleB, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), ( %1%+ %1 ), roleB )[no_precomp] ▶₂ #r3 )
case R_Timeout
solve( RPending( ~pid, roleB, p.2, ck.5, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ss, h(pk(~dk)), h(ct) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), ( %1%+ %1 ), roleB, pq, ki, kr.3, ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.14 )
case R_S2_mix
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₅ #g.4 )
case Pair
solve( !PositionValue( ~pid, %1, g.3 )[no_precomp] ▶₅ #i )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₈ #t )
case Pair
solve( DKMaterial( ~pid, roleA, ~dk ) ▶₃ #g.2 )
case Prepare_DK
solve( EncMaterial( ~pid, roleB, pk(~dk), ct, ss ) ▶₃ #c )
case Prepare_encapsulation
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₆ #i )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₄ #b3 )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #u )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #s )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #s )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #u3 )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #r )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #t )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #t )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #r3 )
case Pair
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₁ #vr.8 )
case Pair
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₀ #vr.14 )
case Pair
solve( !Party( ~pid, roleB, p.1 )[no_precomp] ▶₀ #vr.15 )
case Pair
solve( BusySlot( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #a3 )
case Acquire_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.16 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.17 )
case I_S2_mix
solve( IWait( ~pid, roleA, p.1, ck.5, %e.1, g.4, ( %e.1%+ %1 ), z, x.4, '1', < ss.1, h(ek), h(ct) >, ss.1, ek, ct, ( %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₁ #vr.18 )
case I_S1_mix
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.19 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.21 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.22 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.2, ck.6, %e.2, g.5, %e.2, g.5, x.5, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.24 )
case I_S1_classic
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.23 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.3, ck.7, %e.3, g.6, %e.3, g.6, x.6, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #vr.28 )
case I_S1_classic
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.25 )
case Pair
solve( BusySlot( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #b3 )
case Acquire_Resume
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.16 )
case Release_Resume
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.17 )
case R_Timeout
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.19 )
case Release_Resume
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.20 )
case R_Data_same_epoch
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.22 )
case Pair
solve( !GenKey( ~pid, roleA, %1, ~dk )[no_precomp] ▶₀ #d )
case Generate_EK
solve( !CT0( ~pid, roleA, %1, kem(~ss, pk(~dk)) ) ▶₁ #d )
case Receive_CT_prefix
solve( !ReadyEpoch( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) > )[no_precomp] ▶₄ #s )
case Receive_CT_tail
solve( !Have( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)) )[no_precomp] ▶₅ #s )
case Receive_CT_tail
solve( !Have( ~pid, roleB, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)) )[no_precomp] ▶₄ #t )
case Encapsulate
solve( !Index( ~pid, roleB, %1, p.1 )[no_precomp] ▶₁ #vr.22 )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₀ #vr.22 )
case Pair
solve( Ready( ~pid, roleA, %1 ) @ #d )
case Receive_CT_tail
solve( !St( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, roleA )[no_precomp] ▶₃ #s )
case I_S2_classic
solve( !St( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, roleA )[no_precomp] ▶₃ #t )
case R_Data_same_epoch
solve( RPending( ~pid, roleB, p.1, ck.12, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, roleA, pq, ki, kr.10, ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.23 )
case R_S2_classic
solve( !St( ~pid, roleA, ck.3, %e, g.3 )[no_precomp] ▶₂ #vr.8 )
case Pair
solve( !PositionValue( ~pid, ( %1%+ %1 ), roleB )[no_precomp] ▶₇ #b3 )
case I_S2_mix
solve( IWait( ~pid, r.1, p.1, ck.11, %1, roleA, ( %1%+ %1 ), roleB, x.3, '1', < ss.1, h(ek), h(ct) >, ss.1, ek, ct, ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_mix
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₆ #vr.19 )
case Pair
solve( !Party( ~pid, r.1, p.1 )[no_precomp] ▶₁ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.2, %1, g.1, ks.1, kr.1 )[no_precomp] ▶₂ #d )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.2, %1, g.1, %1, g.1, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.1 )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !St( ~pid, roleA, ck.2, %1, roleA )[no_precomp] ▶₂ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.3, %1, g.2, ks.2, kr.2 )[no_precomp] ▶₁ #vr.12 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.3, %1, g.2, %1, g.2, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.2 )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !St( ~pid, roleA, ck.3, %1, roleA )[no_precomp] ▶₂ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.3, %1, g.2, ks.2, kr.2 )[no_precomp] ▶₂ #vr.13 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.3, %1, g.2, %1, g.2, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.2 )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !St( ~pid, roleA, ck.3, %1, roleA )[no_precomp] ▶₂ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.3, %1, g.2, ks.2, kr.2 )[no_precomp] ▶₁ #vr.14 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.3, %1, g.2, %1, g.2, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.2 )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !St( ~pid, roleA, ck.3, %1, roleA )[no_precomp] ▶₂ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.3, %1, g.2, ks.2, kr.2 )[no_precomp] ▶₂ #vr.15 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.3, %1, g.2, %1, g.2, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.2 )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !St( ~pid, roleA, ck.3, %1, roleA )[no_precomp] ▶₂ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.3, %1, g.2, ks.2, kr.2 )[no_precomp] ▶₁ #vr.16 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.3, %1, g.2, %1, g.2, x.3, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.2 )[no_precomp] ▶₅ #vr.19 )
case Pair
solve( !St( ~pid, roleA, ck.3, %1, roleA )[no_precomp] ▶₂ #vr.21 )
case Pair
solve( !Session( ~pid, roleB, ck.3, %1, g.2, ks.2, kr.2 )[no_precomp] ▶₁ #vr.17 )
case R_Data_same_epoch
solve( !Index( ~pid, roleB, %1, g.2 )[no_precomp] ▶₃ #vr.19 )
case Pair
solve( !Session( ~pid, roleB, ck.4, %1, roleA, ks.3, kr.3 )[no_precomp] ▶₂ #vr.18 )
case R_Data_same_epoch
solve( !Index( ~pid, roleB, %1, roleA )[no_precomp] ▶₃ #vr.21 )
case Pair
solve( !Session( ~pid, roleA, ck.2, %1, roleA, ks.1, kr.1 )[-, no_precomp] ▶₁ #g.1 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.3, ck.2, %1, roleA, %1, roleA, x.3, '0', 'none', 'none', 'none', 'none', ( %s.3%+ %1 ) )[no_precomp] ▶₁ #vr.23 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, roleA )[no_precomp] ▶₅ #vr.23 )
case Pair
solve( !St( ~pid, roleA, ck.2, %1, roleA )[no_precomp] ▶₂ #vr.25 )
case Pair
solve( !Session( ~pid, roleB, ck.1, %1, g, ks, kr )[-, no_precomp] ▶₁ #c )
case R_Data_same_epoch
solve( !Index( ~pid, roleB, %1, g )[no_precomp] ▶₃ #vr.23 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #g )
case I_S2_classic
solve( !SKValue( ~pid, roleB, ks, kr )[no_precomp] ▶₂ #c )
case R_S2_classic
solve( !St( ~pid, roleB, ck.2, %e, g.1 )[no_precomp] ▶₂ #vr.25 )
case Pair
solve( !Party( ~pid, roleB, p )[no_precomp] ▶₁ #vr.25 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #d )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.12 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.13 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.14 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.15 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.16 )
case I_S2_classic
solve( !SKValue( ~pid, roleB, ks, kr )[no_precomp] ▶₂ #vr.17 )
case R_S2_classic
solve( !St( ~pid, roleB, ck.3, %e, g.1 )[no_precomp] ▶₂ #vr.27 )
case Pair
solve( !Party( ~pid, roleB, p.1 )[no_precomp] ▶₁ #vr.27 )
case Pair
solve( !SKValue( ~pid, roleB, ks, kr )[no_precomp] ▶₃ #vr.18 )
case R_S2_classic
solve( !St( ~pid, roleB, ck.4, %e, g.1 )[no_precomp] ▶₂ #vr.29 )
case Pair
solve( !Party( ~pid, roleB, p.1 )[no_precomp] ▶₁ #vr.29 )
case Pair
solve( !KU( senc(< 'CT', %1, 'half', kem(~ss, pk(~dk)) >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk )
case Send_CT_tail
solve( !Progress( ~pid, roleB, %1, 'CT', 'half' )[no_precomp] ▶₁ #vr.31 )
case Receive_progress_CT
solve( !Session( ~pid, roleB, ck.7, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₂ #vr.31 )
case R_Data_same_epoch
solve( !Index( ~pid, roleB, %1, g.1 )[no_precomp] ▶₃ #vr.33 )
case Pair
solve( !Session( ~pid, roleB, ck.8, %1, g.1, ks, kr.1 )[no_precomp] ▶₁ #vr.32 )
case R_Data_same_epoch
solve( !Index( ~pid, roleB, %1, g.1 )[no_precomp] ▶₃ #vr.35 )
case Pair
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₃ #vr.31 )
case R_S2_classic
solve( !SKValue( ~pid, roleB, ks, kr )[no_precomp] ▶₂ #vr.32 )
case R_S2_classic
solve( !St( ~pid, roleB, ck.9, %e, g.1 )[no_precomp] ▶₂ #vr.37 )
case Pair
solve( !Party( ~pid, roleB, p.4 )[no_precomp] ▶₁ #vr.37 )
case Pair
solve( !KU( senc(< 'CT', %1, 'prefix', kem(~ss, pk(~dk)) >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.53 )
case Encapsulate
solve( !KU( senc(< 'EK', %1, 'half', pk(~dk) >, kdf(ext(~ck, < x.3, ~y.3, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), x.3 >, ~y.3 >) >)) ) @ #vk.50 )
case Send_EK_tail
solve( !Progress( ~pid, roleA, %1, 'EK', 'half' )[no_precomp] ▶₁ #vr.37 )
case Receive_progress_EK
solve( !Session( ~pid, roleA, ck.11, %1, g.1, kdf(ext(~ck, < x.3, ~y.3, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), x.3 >, ~y.3 >) >), kr )[no_precomp] ▶₂ #vr.37 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.11, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.36 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.6, ck.11, %1, g.1, %1, g.1, x.5, '0', 'none', 'none', 'none', 'none', ( %s.8%+ %1 ) )[no_precomp] ▶₁ #vr.37 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.1 )[no_precomp] ▶₅ #vr.37 )
case Pair
solve( !St( ~pid, roleA, ck.11, %1, roleA )[no_precomp] ▶₂ #vr.39 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.35 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.36 )
case I_S2_classic
solve( !KU( senc(< 'EK', %1, 'prefix', pk(~dk) >, kdf(ext(~ck, < x.3, ~y.3, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), x.3 >, ~y.3 >) >)) ) @ #vk.47 )
case Generate_EK
solve( !KU( senc(< 'PROGRESS', %1, 'CT', 'half' >, kdf(ext(~ck, < x.3, ~y.3, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), x.3 >, ~y.3 >) >)) ) @ #vk.44 )
case Receive_CT_prefix
solve( !Index( pid.1, r.1, %1, r.1 )[-, no_precomp] ▶₀ #vr.36 )
case Pair
solve( !PositionValue( ~pid.1, %1, roleA )[no_precomp] ▶₅ #vr.36 )
case Pair
solve( !Party( ~pid.1, roleA, p.6 )[no_precomp] ▶₀ #vr.37 )
case Pair
solve( !Session( ~pid.1, roleA, ck.11, %1, g.1, kdf(ext(~ck, < x.3, ~y.3, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), x.3 >, ~y.3 >) >), kr )[no_precomp] ▶₁ #vr.35 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.33 )
case I_S2_classic
solve( !KU( mac(kdf(~ck, 'authR', ~pid), < 'S2', h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #vk.7 )
case R_S2_classic
solve( !KU( mac(kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), 'authR', ~pid), < 'S2', h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) ) @ #vk.10 )
case R_S2_mix
solve( !KU( mac(kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), 'authR', ~pid), < 'S2', h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid), ~x.2 >, ~y.2 >) >) ) @ #vk.13 )
case R_S2_classic
solve( !KU( senc('data', kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.14 )
case I_S2_classic
solve( !KU( senc('data', kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid), ~x.2 >, ~y.2 >) >)) ) @ #vk.15 )
case I_S2_classic
solve( !KU( mac(kdf(~ck, < 'authI', roleA >, ~pid), < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >) ) @ #vk.29 )
case I_S1_classic
solve( !KU( mac(kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'authI', roleA >, ~pid), < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >) ) @ #vk.35 )
case I_S1_mix
solve( !KU( mac(kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'authI', roleA >, ~pid), < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid), ~x.2 >) ) @ #vk.39 )
case I_S1_classic
solve( !KU( senc(< 'PROGRESS', %1, 'EK', 'half' >, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.41 )
case Receive_EK_prefix
solve( !Index( pid.1, r.1, %1, p.6 )[no_precomp] ▶₁ #vr.40 )
case Pair_case_2
solve( !Party( ~pid.1, roleB, roleA )[no_precomp] ▶₀ #vr.40 )
case Pair
solve( !Session( ~pid.1, roleB, ck.12, %1, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₂ #vr.40 )
case R_Data_same_epoch
solve( !Index( ~pid.1, roleB, %1, roleA )[no_precomp] ▶₃ #vr.42 )
case Pair
solve( !SKValue( ~pid.1, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₃ #vr.40 )
case R_S2_classic
solve( !KU( pk(~dk) ) @ #vk.41 )
case Prepare_DK
solve( !KU( ~y ) @ #vk.21 )
case R_S2_classic
solve( !KU( ~x ) @ #vk.33 )
case I_S1_classic
solve( !KU( ~y.1 ) @ #vk.23 )
case R_S2_mix
solve( !KU( ~x.1 ) @ #vk.38 )
case I_S1_mix
solve( !KU( ~y.2 ) @ #vk.27 )
case R_S2_classic
solve( !KU( ~x.2 ) @ #vk.41 )
case I_S1_classic
solve( RPending( ~pid, roleB, p.1, ck.4, ck.2, %1, roleA, pq, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case R_S2_classic
solve( RPending( ~pid, roleB, p.1, ck.3, ck.2, %1, roleA, pq, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case R_S2_classic
solve( RPending( ~pid, roleB, p.1, ck.2, ck.1, %1, roleA, pq, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.19 )
case R_S2_classic
solve( RPending( ~pid, roleB, p.1, ck.3, ck.1, %1, roleA, pq, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.21 )
case R_S2_classic
solve( RPending( ~pid, roleB, p.1, ck.2, ck.1, %1, roleA, pq, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.21 )
case R_S2_classic
solve( RPending( ~pid, roleB, p.1, ck.2, ck.1, %1, roleA, pq, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.31 )
case R_S2_classic
solve( !KU( kdf(~ck, < 'id', roleA >, ~pid) ) @ #vk.38 )
case I_S1_classic
solve( !St( ~pid, roleA, ~ck, %e, g.1 )[no_precomp] ▶₂ #vr.46 )
case Pair
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₁ #vr.46 )
case Pair
solve( ResumeSlot( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.51 )
case Pair
solve( !KU( kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid) ) @ #vk.40 )
case I_S1_mix
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₁ #vr.47 )
case Pair
solve( !Party( ~pid, g.1, ng )[no_precomp] ▶₂ #vr.47 )
case Pair_case_1
solve( !ReadyEpoch( ~pid, roleA, %e, < ss.1, h(ek), h(ct) > )[no_precomp] ▶₄ #vr.47 )
case Receive_CT_tail
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₀ #vr.56 )
case Pair
solve( !Have( ~pid, roleA, %e, < ss.1, h(pk(~dk.1)), h(ct) >, ss.1, pk(~dk.1), ct )[no_precomp] ▶₅ #vr.47 )
case Receive_CT_tail
solve( !St( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %e, roleA )[no_precomp] ▶₃ #vr.47 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₂ #vr.53 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.1, %1, g.1, %1, g.1, x.4, '0', 'none', 'none', 'none', 'none', ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.57 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.1 )[no_precomp] ▶₅ #vr.57 )
case Pair
solve( !St( ~pid, roleA, ck.1, %1, roleA )[no_precomp] ▶₂ #vr.59 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.54 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.1, %1, g.1, %1, g.1, x.4, '0', 'none', 'none', 'none', 'none', ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.57 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.1 )[no_precomp] ▶₅ #vr.57 )
case Pair
solve( !St( ~pid, roleA, ck.1, %1, roleA )[no_precomp] ▶₂ #vr.59 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₂ #vr.55 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.1, %1, g.1, %1, g.1, x.4, '0', 'none', 'none', 'none', 'none', ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.57 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.1 )[no_precomp] ▶₅ #vr.57 )
case Pair
solve( !St( ~pid, roleA, ck.1, %1, roleA )[no_precomp] ▶₂ #vr.59 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.56 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.1, %1, g.1, %1, g.1, x.4, '0', 'none', 'none', 'none', 'none', ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.57 )
case I_S1_classic
solve( !Index( ~pid, roleA, %1, g.1 )[no_precomp] ▶₅ #vr.57 )
case Pair
solve( !St( ~pid, roleA, ck.1, %1, roleA )[no_precomp] ▶₂ #vr.59 )
case Pair
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.53 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.54 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.55 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.56 )
case I_S2_classic
solve( ResumeSlot( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.52 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.57 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.1, ck.1, %e, g.1, %e, g.1, x.4, '0', 'none', 'none', 'none', 'none', ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.58 )
case I_S1_classic
solve( !St( ~pid, roleA, ck.1, %e, g.1 )[no_precomp] ▶₂ #vr.60 )
case Pair
solve( !KU( kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleA >, ~pid) ) @ #vk.41 )
case I_S1_classic
solve( !Party( ~pid, roleA, p.1 )[no_precomp] ▶₁ #vr.48 )
case Pair
solve( !St( ~pid, roleA, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), %e, g.1 )[no_precomp] ▶₂ #vr.48 )
case I_S2_mix
solve( ResumeSlot( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.53 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, %s.1 )[no_precomp] ▶₀ #vr.54 )
case I_S2_mix
solve( IWait( ~pid, roleA, p.1, ck.1, %e, g.1, ( %e%+ %1 ), z, x.4, '1', < ss.1, h(ek), h(ct) >, ss.1, ek, ct, ( %s.1%+ %1 ) )[no_precomp] ▶₁ #vr.55 )
case I_S1_mix
solve( !St( ~pid, roleA, ck.1, %e, g.1 )[no_precomp] ▶₃ #vr.57 )
case I_S2_classic
solve( IWait( ~pid, roleA, p.2, ck.1, %e, g.1, %e, g.1, x.4, '0', 'none', 'none', 'none', 'none', ( %s.2%+ %1 ) )[no_precomp] ▶₁ #vr.59 )
case I_S1_classic
solve( !St( ~pid, roleA, ck.1, %e, g.1 )[no_precomp] ▶₂ #vr.61 )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #g )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #c )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #d )
case I_S2_classic
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₄ #a )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #i )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₄ #a3 )
case I_S2_mix
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₅ #b )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #j )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₆ #b3 )
case I_S2_mix
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₄ #u )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₇ #s )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₄ #u3 )
case I_S2_mix
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₅ #r )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₇ #t )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₅ #r3 )
case I_S2_mix
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.12 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.13 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.14 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.15 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.16 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.17 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.18 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.19 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.20 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.21 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.22 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.23 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.30 )
case I_S2_classic
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
