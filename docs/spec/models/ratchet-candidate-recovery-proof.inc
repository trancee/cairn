/* Generated from Tamarin 1.12.0's verified existential proof export. */
lemma initiator_candidate_recovery [heuristic={honest_trace},
                                    hide_lemma=encrypted_origin, hide_lemma=ek_authenticated,
                                    hide_lemma=ct_authenticated, hide_lemma=derived_ck_predecessor]:
  exists-trace
  "∃ pid ck0 ck1 candidate next ek ct ss following x y z ki kr ki2 kr2 ki3
     kr3 #p #u #r #a #b #g1 #ep #eat #et #eaf #c #ctp #cat #ctt #d #s #q #m #t
     #u2 #r2 #i #g.
    (((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((Init( pid,
                                                                                               ck0
                                                                                         ) @ #p) ∧
                                                                                        (I_Start( pid, roleA,
                                                                                                  x, 'none'
                                                                                         ) @ #u)) ∧
                                                                                       (ResumeStart( pid,
                                                                                                     roleA,
                                                                                                     (%1%+%1)
                                                                                        ) @ #u)) ∧
                                                                                      (R_Accept( pid, roleB,
                                                                                                 roleA, x,
                                                                                                 'none', ki,
                                                                                                 kr
                                                                                       ) @ #r)) ∧
                                                                                     (ResumeStart( pid, roleB,
                                                                                                   (%1%+%1)
                                                                                      ) @ #r)) ∧
                                                                                    (I_Advance( pid, roleA,
                                                                                                ck0, ck1, %1,
                                                                                                %1
                                                                                     ) @ #a)) ∧
                                                                                   (I_Commit( pid, roleA,
                                                                                              roleB, x,
                                                                                              'none', ki, kr
                                                                                    ) @ #a)) ∧
                                                                                  (ResumeFinish( pid, roleA,
                                                                                                 (%1%+%1%+%1)
                                                                                   ) @ #a)) ∧
                                                                                 (CandidateBefore( pid, roleA,
                                                                                                   ck0, 'none'
                                                                                  ) @ #a)) ∧
                                                                                (ConfirmedCK( pid, roleB, ck1,
                                                                                              %1
                                                                                 ) @ #b)) ∧
                                                                               (ResumeFinish( pid, roleB,
                                                                                              (%1%+%1%+%1)
                                                                                ) @ #b)) ∧
                                                                              (CandidateBefore( pid, roleB,
                                                                                                ck0, 'none'
                                                                               ) @ #b)) ∧
                                                                             (EpGen( pid, roleA, %1, ek
                                                                              ) @ #g1)) ∧
                                                                            (SessionUse( pid, roleA, ki, kr
                                                                             ) @ #g1)) ∧
                                                                           (Durable( pid, roleB, %1, 'EK',
                                                                                     'half'
                                                                            ) @ #ep)) ∧
                                                                          (SessionUse( pid, roleB, kr, ki
                                                                           ) @ #ep)) ∧
                                                                         (Ack( pid, roleA, %1, 'EK', 'half'
                                                                          ) @ #eat)) ∧
                                                                        (SessionUse( pid, roleA, ki, kr
                                                                         ) @ #eat)) ∧
                                                                       (Sent( pid, roleA, %1, 'EK', 'full'
                                                                        ) @ #et)) ∧
                                                                      (SessionUse( pid, roleA, ki, kr
                                                                       ) @ #et)) ∧
                                                                     (Durable( pid, roleB, %1, 'EK', 'full'
                                                                      ) @ #eaf)) ∧
                                                                    (SessionUse( pid, roleB, kr, ki
                                                                     ) @ #eaf)) ∧
                                                                   (EpEnc( pid, roleB, %1, ek, ct, ss
                                                                    ) @ #c)) ∧
                                                                  (SessionUse( pid, roleB, kr, ki ) @ #c)) ∧
                                                                 (Durable( pid, roleA, %1, 'CT', 'half'
                                                                  ) @ #ctp)) ∧
                                                                (SessionUse( pid, roleA, ki, kr ) @ #ctp)) ∧
                                                               (Ack( pid, roleB, %1, 'CT', 'half' ) @ #cat)) ∧
                                                              (SessionUse( pid, roleB, kr, ki ) @ #cat)) ∧
                                                             (Sent( pid, roleB, %1, 'CT', 'full' ) @ #ctt)) ∧
                                                            (SessionUse( pid, roleB, kr, ki ) @ #ctt)) ∧
                                                           (EpDec( pid, roleA, %1, ek, ct, ss ) @ #d)) ∧
                                                          (SessionUse( pid, roleA, ki, kr ) @ #d)) ∧
                                                         (I_Start( pid, roleA, y, <ss, h(ek), h(ct)>
                                                          ) @ #s)) ∧
                                                        (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1) ) @ #s)) ∧
                                                       (R_Accept( pid, roleB, roleA, y, <ss, h(ek), h(ct)>,
                                                                  ki2, kr2
                                                        ) @ #q)) ∧
                                                      (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1) ) @ #q)) ∧
                                                     (I_Advance( pid, roleA, ck1, candidate, %1, (%1%+%1)
                                                      ) @ #m)) ∧
                                                    (I_Commit( pid, roleA, roleB, y, <ss, h(ek), h(ct)>, ki2,
                                                               kr2
                                                     ) @ #m)) ∧
                                                   (ResumeFinish( pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #m)) ∧
                                                  (CandidateBefore( pid, roleA, ck1, 'none' ) @ #m)) ∧
                                                 (MixedKey( pid, %1, ss, ek, ct, candidate ) @ #m)) ∧
                                                (Timeout( pid, roleB, candidate, (%1%+%1) ) @ #t)) ∧
                                               (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #t)) ∧
                                              (CandidateBefore( pid, roleB, ck1, 'none' ) @ #t)) ∧
                                             (I_Start( pid, roleB, z, 'none' ) @ #u2)) ∧
                                            (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #u2)) ∧
                                           (R_Accept( pid, roleA, roleB, z, 'none', ki3, kr3 ) @ #r2)) ∧
                                          (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #r2)) ∧
                                         (I_Advance( pid, roleB, candidate, next, (%1%+%1), (%1%+%1)
                                          ) @ #i)) ∧
                                        (I_Commit( pid, roleB, roleA, z, 'none', ki3, kr3 ) @ #i)) ∧
                                       (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #i)) ∧
                                      (CandidateBefore( pid, roleB, ck1, candidate ) @ #i)) ∧
                                     (EpGen( pid, roleB, (%1%+%1), following ) @ #g)) ∧
                                    (SessionUse( pid, roleB, ki3, kr3 ) @ #g)) ∧
                                   (#p < #u)) ∧
                                  (#u < #r)) ∧
                                 (#r < #a)) ∧
                                (#a < #b)) ∧
                               (#b < #g1)) ∧
                              (#g1 < #ep)) ∧
                             (#ep < #eat)) ∧
                            (#eat < #et)) ∧
                           (#et < #eaf)) ∧
                          (#eaf < #c)) ∧
                         (#c < #ctp)) ∧
                        (#ctp < #cat)) ∧
                       (#cat < #ctt)) ∧
                      (#ctt < #d)) ∧
                     (#d < #s)) ∧
                    (#s < #q)) ∧
                   (#q < #m)) ∧
                  (#m < #t)) ∧
                 (#t < #u2)) ∧
                (#u2 < #r2)) ∧
               (#r2 < #i)) ∧
              (#i < #g)) ∧
             (¬(∃ old new #j.
                 (I_Advance( pid, roleB, old, new, %1, (%1%+%1) ) @ #j) ∧ (#j < #g)))) ∧
            (¬(∃ current #j.
                (ConfirmedCK( pid, roleB, current, (%1%+%1) ) @ #j) ∧ (#j < #g)))) ∧
           (¬(∃ #v. RevCK( pid ) @ #v))) ∧
          (¬(∃ key #v. RevDK( pid, key ) @ #v))) ∧
         (¬(∃ secret #v. RevSS( pid, secret ) @ #v))) ∧
        (∀ peer nonce contribution #event.
          (I_Start( pid, peer, nonce, contribution ) @ #event) ⇒
          (((#event = #u) ∨ (#event = #s)) ∨ (#event = #u2)))) ∧
       (∀ peer other nonce contribution send receive #event.
         (R_Accept( pid, peer, other, nonce, contribution, send, receive
          ) @ #event) ⇒
         (((#event = #r) ∨ (#event = #q)) ∨ (#event = #r2)))) ∧
      (∀ peer other nonce contribution send receive #event.
        (I_Commit( pid, peer, other, nonce, contribution, send, receive
         ) @ #event) ⇒
        (((#event = #a) ∨ (#event = #m)) ∨ (#event = #i)))) ∧
     (∀ peer current position #event.
       (ConfirmedCK( pid, peer, current, position ) @ #event) ⇒
       (#event = #b))) ∧
    (∀ peer current position #event.
      (Timeout( pid, peer, current, position ) @ #event) ⇒ (#event = #t))"
/*
guarded formula characterizing all satisfying traces:
"∃ pid ck0 ck1 candidate next ek ct ss following x y z ki kr ki2 kr2 ki3
   kr3 #p #u #r #a #b #g1 #ep #eat #et #eaf #c #ctp #cat #ctt #d #s #q #m #t
   #u2 #r2 #i #g.
  (Init( pid, ck0 ) @ #p) ∧
  (I_Start( pid, roleA, x, 'none' ) @ #u) ∧
  (ResumeStart( pid, roleA, (%1%+%1) ) @ #u) ∧
  (R_Accept( pid, roleB, roleA, x, 'none', ki, kr ) @ #r) ∧
  (ResumeStart( pid, roleB, (%1%+%1) ) @ #r) ∧
  (I_Advance( pid, roleA, ck0, ck1, %1, %1 ) @ #a) ∧
  (I_Commit( pid, roleA, roleB, x, 'none', ki, kr ) @ #a) ∧
  (ResumeFinish( pid, roleA, (%1%+%1%+%1) ) @ #a) ∧
  (CandidateBefore( pid, roleA, ck0, 'none' ) @ #a) ∧
  (ConfirmedCK( pid, roleB, ck1, %1 ) @ #b) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1) ) @ #b) ∧
  (CandidateBefore( pid, roleB, ck0, 'none' ) @ #b) ∧
  (EpGen( pid, roleA, %1, ek ) @ #g1) ∧
  (SessionUse( pid, roleA, ki, kr ) @ #g1) ∧
  (Durable( pid, roleB, %1, 'EK', 'half' ) @ #ep) ∧
  (SessionUse( pid, roleB, kr, ki ) @ #ep) ∧
  (Ack( pid, roleA, %1, 'EK', 'half' ) @ #eat) ∧
  (SessionUse( pid, roleA, ki, kr ) @ #eat) ∧
  (Sent( pid, roleA, %1, 'EK', 'full' ) @ #et) ∧
  (SessionUse( pid, roleA, ki, kr ) @ #et) ∧
  (Durable( pid, roleB, %1, 'EK', 'full' ) @ #eaf) ∧
  (SessionUse( pid, roleB, kr, ki ) @ #eaf) ∧
  (EpEnc( pid, roleB, %1, ek, ct, ss ) @ #c) ∧
  (SessionUse( pid, roleB, kr, ki ) @ #c) ∧
  (Durable( pid, roleA, %1, 'CT', 'half' ) @ #ctp) ∧
  (SessionUse( pid, roleA, ki, kr ) @ #ctp) ∧
  (Ack( pid, roleB, %1, 'CT', 'half' ) @ #cat) ∧
  (SessionUse( pid, roleB, kr, ki ) @ #cat) ∧
  (Sent( pid, roleB, %1, 'CT', 'full' ) @ #ctt) ∧
  (SessionUse( pid, roleB, kr, ki ) @ #ctt) ∧
  (EpDec( pid, roleA, %1, ek, ct, ss ) @ #d) ∧
  (SessionUse( pid, roleA, ki, kr ) @ #d) ∧
  (I_Start( pid, roleA, y, <ss, h(ek), h(ct)> ) @ #s) ∧
  (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1) ) @ #s) ∧
  (R_Accept( pid, roleB, roleA, y, <ss, h(ek), h(ct)>, ki2, kr2 ) @ #q) ∧
  (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1) ) @ #q) ∧
  (I_Advance( pid, roleA, ck1, candidate, %1, (%1%+%1) ) @ #m) ∧
  (I_Commit( pid, roleA, roleB, y, <ss, h(ek), h(ct)>, ki2, kr2 ) @ #m) ∧
  (ResumeFinish( pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #m) ∧
  (CandidateBefore( pid, roleA, ck1, 'none' ) @ #m) ∧
  (MixedKey( pid, %1, ss, ek, ct, candidate ) @ #m) ∧
  (Timeout( pid, roleB, candidate, (%1%+%1) ) @ #t) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #t) ∧
  (CandidateBefore( pid, roleB, ck1, 'none' ) @ #t) ∧
  (I_Start( pid, roleB, z, 'none' ) @ #u2) ∧
  (ResumeStart( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #u2) ∧
  (R_Accept( pid, roleA, roleB, z, 'none', ki3, kr3 ) @ #r2) ∧
  (ResumeStart( pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #r2) ∧
  (I_Advance( pid, roleB, candidate, next, (%1%+%1), (%1%+%1) ) @ #i) ∧
  (I_Commit( pid, roleB, roleA, z, 'none', ki3, kr3 ) @ #i) ∧
  (ResumeFinish( pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1%+%1) ) @ #i) ∧
  (CandidateBefore( pid, roleB, ck1, candidate ) @ #i) ∧
  (EpGen( pid, roleB, (%1%+%1), following ) @ #g) ∧
  (SessionUse( pid, roleB, ki3, kr3 ) @ #g)
 ∧
  (#p < #u) ∧
  (#u < #r) ∧
  (#r < #a) ∧
  (#a < #b) ∧
  (#b < #g1) ∧
  (#g1 < #ep) ∧
  (#ep < #eat) ∧
  (#eat < #et) ∧
  (#et < #eaf) ∧
  (#eaf < #c) ∧
  (#c < #ctp) ∧
  (#ctp < #cat) ∧
  (#cat < #ctt) ∧
  (#ctt < #d) ∧
  (#d < #s) ∧
  (#s < #q) ∧
  (#q < #m) ∧
  (#m < #t) ∧
  (#t < #u2) ∧
  (#u2 < #r2) ∧
  (#r2 < #i) ∧
  (#i < #g) ∧
  (∀ old new #j.
    (I_Advance( pid, roleB, old, new, %1, (%1%+%1) ) @ #j) ⇒ ¬(#j < #g)) ∧
  (∀ current #j.
    (ConfirmedCK( pid, roleB, current, (%1%+%1) ) @ #j) ⇒ ¬(#j < #g)) ∧
  (∀ #v. (RevCK( pid ) @ #v) ⇒ ⊥) ∧
  (∀ key #v. (RevDK( pid, key ) @ #v) ⇒ ⊥) ∧
  (∀ secret #v. (RevSS( pid, secret ) @ #v) ⇒ ⊥) ∧
  (∀ peer nonce contribution #event.
    (I_Start( pid, peer, nonce, contribution ) @ #event)
   ⇒
    ((#event = #u) ∨ (#event = #s) ∨ (#event = #u2))) ∧
  (∀ peer other nonce contribution send receive #event.
    (R_Accept( pid, peer, other, nonce, contribution, send, receive
     ) @ #event)
   ⇒
    ((#event = #r) ∨ (#event = #q) ∨ (#event = #r2))) ∧
  (∀ peer other nonce contribution send receive #event.
    (I_Commit( pid, peer, other, nonce, contribution, send, receive
     ) @ #event)
   ⇒
    ((#event = #a) ∨ (#event = #m) ∨ (#event = #i))) ∧
  (∀ peer current position #event.
    (ConfirmedCK( pid, peer, current, position ) @ #event) ⇒ #event = #b) ∧
  (∀ peer current position #event.
    (Timeout( pid, peer, current, position ) @ #event) ⇒ #event = #t)"
*/
simplify
solve( splitEqs(3) )
case split_case_1
solve( I_Advance( ~pid, roleA, ~ck.3, ck1, %1, %1 ) @ #a )
case I_S2_classic
solve( I_Commit( ~pid, roleA, roleB, x.1, 'none', ki, kr.4 ) @ #a )
case I_S2_classic
solve( I_Advance( ~pid, roleA, kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>)>), candidate, %1, (%1%+%1) ) @ #m )
case I_S2_mix
solve( splitEqs(7) )
case split_case_3
solve( I_Commit( ~pid, roleA, roleB, y.2, <ss, h(pk(~dk)), h(kem(ss, pk(~dk)))>, ki2, kr2 ) @ #m )
case I_S2_mix
solve( I_Advance( ~pid, roleB, kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>)>), <x.1, y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk)))>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>)>), <'id', roleA>, ~pid), x.1>, y.1>) >), next, (%1%+%1), (%1%+%1) ) @ #i )
case I_S2_classic_recovery_candidate
solve( splitEqs(9) )
case split_case_2
solve( I_Commit( ~pid, roleB, roleA, z.1, 'none', ki3, kr3 ) @ #i )
case I_S2_classic_recovery_candidate
solve( ConfirmedCK( ~pid, roleB, kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>)>), %1 ) @ #b.2 )
case R_Data_same_epoch
solve( Timeout( ~pid, roleB, kdf(ext(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>) >), <x.1, y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk)))>), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <x, y, 'none'>), 'ratchet', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), x>, y>)>), <'id', roleA>, ~pid), x.1>, y.1>) >), (%1%+%1) ) @ #t )
case R_Timeout
solve( I_Start( ~pid, roleA, x, 'none' ) @ #u )
case I_S1_classic
solve( I_Start( ~pid, roleA, x.1, <ss, h(pk(~dk)), h(kem(ss, pk(~dk)))> ) @ #s.6 )
case I_S1_mix
solve( I_Start( ~pid, roleB, z, 'none' ) @ #u2 )
case I_S1_classic
solve( ResumeStart( ~pid, roleA, (%1%+%1) ) @ #u )
case I_S1_classic
solve( R_Accept( ~pid, roleB, roleA, ~x, 'none', kdf(ext(~ck, <~x, y, 'none'>), 'skI', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, y>)>), kdf(ext(~ck, <~x, y, 'none'>), 'skR', <~pid, h(<<'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, y>)>) ) @ #r )
case R_S2_classic
solve( ResumeStart( ~pid, roleB, (%1%+%1) ) @ #r )
case R_S2_classic
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1) ) @ #a )
case I_S2_classic
solve( CandidateBefore( ~pid, roleA, ~ck, 'none' ) @ #a )
case I_S2_classic
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1) ) @ #b.1 )
case R_Data_same_epoch
solve( CandidateBefore( ~pid, roleB, ~ck, 'none' ) @ #b.1 )
case R_Data_same_epoch
solve( ResumeStart( ~pid, roleA, (%1%+%1%+%1%+%1) ) @ #s.4 )
case I_S1_mix
solve( R_Accept( ~pid, roleB, roleA, ~x.1, <ss, h(pk(~dk)), h(kem(ss, pk(~dk)))>, kdf(ext(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), <~x.1, y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk)))>), 'skI', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), <'id', roleA>, ~pid), ~x.1>, y.1>) >), kdf(ext(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), <~x.1, y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk)))>), 'skR', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), <'id', roleA>, ~pid), ~x.1>, y.1>) >) ) @ #q )
case R_S2_mix
solve( splitEqs(23) )
case split_case_3
solve( ResumeStart( ~pid, roleB, (%1%+%1%+%1%+%1) ) @ #q )
case R_S2_mix
solve( ResumeFinish( ~pid, roleA, (%1%+%1%+%1%+%1%+%1) ) @ #m )
case I_S2_mix
solve( CandidateBefore( ~pid, roleA, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), 'none' ) @ #m )
case I_S2_mix
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1%+%1%+%1) ) @ #t )
case R_Timeout
solve( CandidateBefore( ~pid, roleB, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA>, ~pid), ~x>, ~y>) >), 'none' ) @ #t )
case R_Timeout
solve( ResumeStart( ~pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #u2 )
case I_S1_classic
solve( R_Accept( ~pid, roleA, roleB, ~x.2, 'none', kdf(ext(kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk))) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >), <~x.2, y.2, 'none'>), 'skI', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk))) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >), <'id', roleB>, ~pid), ~x.2>, y.2>) >), kdf(ext(kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk))) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >), <~x.2, y.2, 'none'>), 'skR', <~pid, h(< <'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk))) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >), <'id', roleB>, ~pid), ~x.2>, y.2>) >) ) @ #r2 )
case R_S2_classic
solve( ResumeStart( ~pid, roleA, (%1%+%1%+%1%+%1%+%1%+%1) ) @ #r2 )
case R_S2_classic
solve( ResumeFinish( ~pid, roleB, (%1%+%1%+%1%+%1%+%1%+%1%+ %1) ) @ #i )
case I_S2_classic_recovery_candidate
solve( CandidateBefore( ~pid, roleB, kdf(ext(~ck, <~x, ~y, 'none'>), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, <'id', roleA >, ~pid), ~x>, ~y>) >), kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk))) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >) ) @ #i )
case I_S2_classic_recovery_candidate
solve( MixedKey( ~pid, %1, ss, pk(~dk), kem(ss, pk(~dk)), kdf(ext(kdf(ext(~ck, <~x, ~y, 'none' >), 'ratchet', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), <~x.1, ~y.1, ss, h(pk(~dk)), h(kem(ss, pk(~dk))) >), 'ratchet', <~pid, h(< <'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y>) >), <'id', roleA >, ~pid), ~x.1>, ~y.1>) >) ) @ #m )
case I_S2_mix
solve( DKMaterial( ~pid, roleA, ~dk ) ▶₃ #g1 )
case Prepare_DK
solve( EncMaterial( ~pid, roleB, pk(~dk), kem(ss, pk(~dk)), ss ) ▶₃ #c )
case Prepare_encapsulation
solve( DKMaterial( ~pid, roleB, ~dk.1 ) ▶₃ #g.10 )
case Prepare_DK
solve( SessionUse( ~pid, roleA, kdf(ext(~ck, <~x, ~y, 'none' >), 'skI', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >), kdf(ext(~ck, <~x, ~y, 'none' >), 'skR', <~pid, h(< <'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x>, ~y>) >) ) @ #g1 )
case Generate_EK
solve( Durable( ~pid, roleB, %1, 'EK', 'half' ) @ #ep )
case Receive_EK_prefix
solve( SessionUse( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', <~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #ep )
case Receive_EK_prefix
solve( Ack( ~pid, roleA, %1, 'EK', 'half' ) @ #eat )
case Receive_progress_EK
solve( SessionUse( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #eat )
case Receive_progress_EK
solve( Sent( ~pid, roleA, %1, 'EK', 'full' ) @ #et )
case Send_EK_tail
solve( SessionUse( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #et )
case Send_EK_tail
solve( Durable( ~pid, roleB, %1, 'EK', 'full' ) @ #eaf )
case Receive_EK_tail
solve( SessionUse( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #eaf )
case Receive_EK_tail
solve( SessionUse( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #c )
case Encapsulate
solve( Durable( ~pid, roleA, %1, 'CT', 'half' ) @ #ctp )
case Receive_CT_prefix
solve( SessionUse( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #ctp )
case Receive_CT_prefix
solve( Ack( ~pid, roleB, %1, 'CT', 'half' ) @ #cat )
case Receive_progress_CT
solve( SessionUse( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #cat )
case Receive_progress_CT
solve( Sent( ~pid, roleB, %1, 'CT', 'full' ) @ #ctt )
case Send_CT_tail
solve( SessionUse( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #ctt )
case Send_CT_tail
solve( SessionUse( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #d )
case Receive_CT_tail
solve( SessionUse( ~pid, roleB, kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >) ) @ #g.16 )
case Generate_EK
solve( IWait( ~pid, roleA, roleB, ~ck, %1, g, %1, g, ~x, '0', 'none', 'none', 'none', 'none', ( %1%+ %1 ) )[no_precomp] ▶₁ #a )
case I_S1_classic
solve( CandidateState( ~pid, roleA, ~ck, 'none' )[no_precomp] ▶₂ #a )
case Pair
solve( IWait( ~pid, roleA, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, roleA, ( %1%+ %1 ), roleB, ~x.1, '1', < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)), ( %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₁ #m )
case I_S1_mix
solve( CandidateState( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), 'none' )[no_precomp] ▶₂ #m )
case I_S2_classic
solve( IWait( ~pid, roleB, roleA, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), ( %1%+ %1 ), roleB, ( %1%+ %1 ), roleB, ~x.2, '0', 'none', 'none', 'none', 'none', ( %1%+ %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₁ #i )
case I_S1_classic
solve( CandidateState( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₂ #i )
case R_Timeout
solve( RPending( ~pid, roleB, p, ck.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, g.1, pq, ki, kr, ( %1%+ %1 ) )[no_precomp] ▶₁ #b )
case R_S2_classic
solve( CandidateState( ~pid, roleB, ~ck, 'none' )[no_precomp] ▶₂ #b )
case Pair
solve( RPending( ~pid, roleB, p.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), ( %1%+ %1 ), g.11, pq.2, ki, kr, ( %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₁ #t )
case R_S2_mix
solve( CandidateState( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), 'none' )[no_precomp] ▶₂ #t )
case R_Data_same_epoch
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.3 )
case Pair
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.4 )
case Release_Resume
solve( ResumeSlot( ~pid, roleA, %1 )[no_precomp] ▶₀ #vr.5 )
case Pair
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.5 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.6 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.7 )
case Pair
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.8 )
case Release_Resume
solve( ResumeSlot( ~pid, roleB, %1 )[no_precomp] ▶₀ #vr.9 )
case Pair
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.9 )
case I_S2_classic
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.10 )
case R_Timeout
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.11 )
case R_Data_same_epoch
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.12 )
case R_Data_same_epoch
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₅ #g1 )
case Pair
solve( !Index( ~pid, roleA, %1, g )[no_precomp] ▶₅ #a )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₅ #m )
case Pair
solve( !Index( ~pid, roleB, %1, roleA )[no_precomp] ▶₅ #i )
case Pair
solve( !Index( ~pid, roleB, %1, g )[no_precomp] ▶₃ #b )
case Pair
solve( !PositionValue( ~pid, %1, roleA )[no_precomp] ▶₈ #q )
case Pair
solve( !Index( ~pid, roleB, %1, p )[no_precomp] ▶₁ #ep )
case Pair
solve( !Index( ~pid, roleA, %1, roleA )[-, no_precomp] ▶₀ #g1 )
case Pair
solve( !Index( ~pid, roleB, ( %1%+ %1 ), roleB )[-, no_precomp] ▶₀ #g.9 )
case I_S2_classic_recovery_candidate
solve( ResumeSlot( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.11 )
case Release_Resume
solve( FinishPermit( ~pid, roleB, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.12 )
case R_Timeout
solve( !St( ~pid, roleA, ~ck, %1, roleA )[no_precomp] ▶₂ #u )
case Pair
solve( !St( ~pid, roleB, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), ( %1%+ %1 ), roleB )[no_precomp] ▶₂ #u2 )
case R_Timeout
solve( !St( ~pid, roleB, ~ck, %1, roleA )[no_precomp] ▶₂ #r )
case Pair
solve( !St( ~pid, roleA, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), %e, g.8 )[no_precomp] ▶₂ #r2 )
case I_S2_mix
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.11 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.12 )
case I_S2_classic
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₆ #m )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₆ #i )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #u )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #s )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #s )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #u2 )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #r )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₁ #q )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₂ #q )
case Pair
solve( !Party( ~pid, roleA, roleB )[no_precomp] ▶₁ #r2 )
case Pair
solve( !Party( ~pid, roleA, p )[no_precomp] ▶₀ #vr )
case Pair
solve( !Party( ~pid, roleB, p )[no_precomp] ▶₀ #vr.1 )
case Pair
solve( !Party( ~pid, roleB, p.1 )[no_precomp] ▶₀ #vr.2 )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₀ #ep )
case Pair
solve( StartPermit( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #r2 )
case Acquire_Resume
solve( ResumeSlot( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.11 )
case Release_Resume
solve( FinishPermit( ~pid, roleA, ( %1%+ %1%+ %1%+ %1%+ %1 ) )[no_precomp] ▶₀ #vr.12 )
case I_S2_mix
solve( !GenKey( ~pid, roleA, %1, ~dk )[no_precomp] ▶₀ #d )
case Generate_EK
solve( !CT0( ~pid, roleA, %1, kem(~ss, pk(~dk)) ) ▶₁ #d )
case Receive_CT_prefix
solve( !ReadyEpoch( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) > )[no_precomp] ▶₄ #s )
case Receive_CT_tail
solve( !Have( ~pid, roleA, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)) )[no_precomp] ▶₅ #s )
case Receive_CT_tail
solve( !Have( ~pid, roleB, %1, < ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >, ~ss, pk(~dk), kem(~ss, pk(~dk)) )[no_precomp] ▶₄ #q )
case Encapsulate
solve( !Index( ~pid, roleB, %1, p.1 )[no_precomp] ▶₁ #vr.19 )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₀ #vr.19 )
case Pair
solve( !GenKey( ~pid, roleA, %1, ~dk.2 )[no_precomp] ▶₀ #eat )
case Generate_EK
solve( !GenKey( ~pid, roleA, %1, ~dk.2 )[no_precomp] ▶₀ #et )
case Generate_EK
solve( !Progress( ~pid, roleA, %1, 'EK', 'half' )[no_precomp] ▶₁ #et )
case Receive_progress_EK
solve( !EK0( ~pid, roleB, %1, ek ) ▶₀ #eaf )
case Receive_EK_prefix
solve( !Index( ~pid, roleB, %1, p.1 )[no_precomp] ▶₁ #vr.21 )
case Pair
solve( !Party( ~pid, roleB, roleA )[no_precomp] ▶₀ #vr.21 )
case Pair
solve( !GenKey( ~pid, roleA, %1, ~dk.1 )[no_precomp] ▶₀ #ctp )
case Generate_EK
solve( !EncWait( ~pid, roleB, %1, ct, pq )[no_precomp] ▶₀ #cat )
case Encapsulate
solve( !EncWait( ~pid, roleB, %1, ct, pq )[no_precomp] ▶₀ #ctt )
case Encapsulate
solve( !Progress( ~pid, roleB, %1, 'CT', 'half' )[no_precomp] ▶₁ #ctt )
case Receive_progress_CT
solve( !PositionValue( ~pid, ( %1%+ %1 ), roleB )[no_precomp] ▶₅ #g.8 )
case I_S2_mix
solve( !PositionValue( ~pid, ( %1%+ %1 ), roleB )[no_precomp] ▶₇ #i )
case I_S2_mix
solve( !SKValue( ~pid, roleB, kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >) )[no_precomp] ▶₂ #g.8 )
case I_S2_classic_recovery_candidate
solve( !St( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, roleA )[no_precomp] ▶₃ #s )
case I_S2_classic
solve( !St( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), %1, roleA )[no_precomp] ▶₃ #q )
case R_Data_same_epoch
solve( !Session( ~pid, roleB, ck.11, ( %1%+ %1 ), roleB, kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >), kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >) )[-, no_precomp] ▶₁ #g.8 )
case I_S2_classic_recovery_candidate
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #g1 )
case I_S2_classic
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #c )
case R_S2_classic
solve( !Session( ~pid, roleA, ck.5, %1, g.4, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #d )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #d )
case I_S2_classic
solve( !Session( ~pid, roleB, ck.7, %1, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #ep )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #ep )
case R_S2_classic
solve( !Session( ~pid, roleA, ck.6, %1, g.5, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #eat )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #eat )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.6, %1, g.5, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #et )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #et )
case I_S2_classic
solve( !Session( ~pid, roleB, ck.5, %1, g.4, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #eaf )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #eaf )
case R_S2_classic
solve( !Session( ~pid, roleA, ck.3, %1, g.2, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #ctp )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #ctp )
case I_S2_classic
solve( !Session( ~pid, roleB, ck.2, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #cat )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #cat )
case R_S2_classic
solve( !Session( ~pid, roleB, ck.2, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #ctt )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #ctt )
case R_S2_classic
solve( !Session( ~pid, roleA, ck.2, %1, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[-, no_precomp] ▶₁ #g1 )
case I_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, g, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[-, no_precomp] ▶₁ #c )
case R_Data_same_epoch
solve( !KU( senc(< 'CT', %1, 'prefix', kem(~ss, pk(~dk)) >, kr) ) @ #vk.41 )
case Encapsulate
solve( !KU( senc(< 'CT', %1, 'half', kem(~ss, pk(~dk)) >, kr) ) @ #vk.41 )
case Send_CT_tail
solve( !Progress( ~pid, roleB, %1, 'CT', 'half' )[no_precomp] ▶₁ #vr.23 )
case Receive_progress_CT
solve( !KU( senc(< 'CT', %1, 'prefix', kem(~ss, pk(~dk)) >, kr.1) ) @ #vk.42 )
case Encapsulate
solve( !KU( senc(< 'CT', %1, 'half', kem(~ss, pk(~dk)) >, kr.1) ) @ #vk.42 )
case Send_CT_tail
solve( !Progress( ~pid, roleB, %1, 'CT', 'half' )[no_precomp] ▶₁ #vr.25 )
case Receive_progress_CT
solve( !KU( senc(< 'CT', %1, 'prefix', kem(~ss, pk(~dk)) >, kr.2) ) @ #vk.43 )
case Encapsulate
solve( !KU( senc(< 'EK', %1, 'half', pk(~dk) >, kr.2) ) @ #vk.43 )
case Send_EK_tail
solve( !Progress( ~pid, roleA, %1, 'EK', 'half' )[no_precomp] ▶₁ #vr.27 )
case Receive_progress_EK
solve( !KU( senc(< 'EK', %1, 'prefix', pk(~dk) >, kr.3) ) @ #vk.44 )
case Generate_EK
solve( !KU( senc(< 'EK', %1, 'prefix', pk(~dk) >, kr.4) ) @ #vk.45 )
case Generate_EK
solve( !KU( senc(< 'PROGRESS', %1, 'EK', 'half' >, kr.3) ) @ #vk.44 )
case Receive_EK_prefix
solve( !Party( pid.1, r.1, p.1 )[no_precomp] ▶₀ #vr.29 )
case Pair_case_2
solve( !Index( ~pid.1, roleB, %1, roleA )[no_precomp] ▶₁ #vr.29 )
case Pair
solve( !KU( senc(< 'PROGRESS', %1, 'CT', 'half' >, kr.4) ) @ #vk.45 )
case Receive_CT_prefix
solve( !PositionValue( pid.2, %1, r.1 )[no_precomp] ▶₅ #vr.32 )
case Pair
solve( !Index( ~pid.2, roleA, %1, roleA )[-, no_precomp] ▶₀ #vr.32 )
case Pair
solve( !Party( ~pid.2, roleA, p.1 )[no_precomp] ▶₀ #vr.33 )
case Pair
solve( !KU( senc(< 'PROGRESS', %1, 'CT', 'half' >, kr.6) ) @ #vk.46 )
case Receive_CT_prefix
solve( !PositionValue( pid.3, %1, r.1 )[no_precomp] ▶₅ #vr.36 )
case Pair
solve( !Index( ~pid.3, roleA, %1, roleA )[-, no_precomp] ▶₀ #vr.36 )
case Pair
solve( !Party( ~pid.3, roleA, p.1 )[no_precomp] ▶₀ #vr.37 )
case Pair
solve( !KU( senc(< 'PROGRESS', %1, 'CT', 'half' >, kr.8) ) @ #vk.47 )
case Receive_CT_prefix
solve( !PositionValue( pid.4, %1, r.1 )[no_precomp] ▶₅ #vr.40 )
case Pair
solve( !Index( ~pid.4, roleA, %1, roleA )[-, no_precomp] ▶₀ #vr.40 )
case Pair
solve( !Party( ~pid.4, roleA, p.1 )[no_precomp] ▶₀ #vr.41 )
case Pair
solve( !KU( senc(< 'PROGRESS', %1, 'EK', 'half' >, kr.10) ) @ #vk.48 )
case Receive_EK_prefix
solve( !Party( pid.5, r.1, p.1 )[no_precomp] ▶₀ #vr.43 )
case Pair_case_2
solve( !Index( ~pid.5, roleB, %1, roleA )[no_precomp] ▶₁ #vr.43 )
case Pair
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #vr.13 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.13 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₂ #vr.14 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.14 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #vr.15 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.15 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₂ #vr.16 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.16 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₁ #vr.17 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.17 )
case I_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.18 )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.18 )
case R_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, roleA, ks, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.19 )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.19 )
case R_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.20 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.20 )
case I_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, roleA, ks, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.21 )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.21 )
case R_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.22 )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.22 )
case R_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr.2 )[no_precomp] ▶₂ #vr.23 )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.23 )
case R_S2_classic
solve( !Session( ~pid, roleB, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.24 )
case R_Data_same_epoch
solve( !SKValue( ~pid, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.24 )
case R_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr.1 )[no_precomp] ▶₂ #vr.25 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #vr.25 )
case I_S2_classic
solve( !Session( ~pid, roleA, ck.1, %1, g.1, ks, kr )[no_precomp] ▶₁ #vr.26 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.26 )
case I_S2_classic
solve( !Session( ~pid.1, roleB, ck.1, %1, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₂ #vr.27 )
case R_Data_same_epoch
solve( !Index( ~pid.1, roleB, %1, roleA )[no_precomp] ▶₃ #vr.33 )
case Pair
solve( !SKValue( ~pid.1, roleB, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₃ #vr.27 )
case R_S2_classic
solve( !Session( ~pid.1, roleA, ck.1, %1, g.1, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kr )[no_precomp] ▶₁ #vr.28 )
case I_S2_classic
solve( !SKValue( ~pid, roleA, kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), kdf(ext(~ck, < ~x, ~y, 'none' >), 'skR', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₂ #vr.28 )
case I_S2_classic
solve( !KU( mac(kdf(~ck, 'authR', ~pid), < 'S2', h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) ) @ #vk.8 )
case R_S2_classic
solve( !KU( mac(kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), 'authR', ~pid), < 'S2', h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) ) @ #vk.11 )
case R_S2_mix
solve( !KU( mac(kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), 'authR', ~pid), < 'S2', h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >) ) @ #vk.14 )
case R_S2_classic
solve( !KU( senc('data', kdf(ext(~ck, < ~x, ~y, 'none' >), 'skI', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >)) ) @ #vk.15 )
case I_S2_classic
solve( !KU( mac(kdf(~ck, < 'authI', roleA >, ~pid), < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >) ) @ #vk.29 )
case I_S1_classic
solve( !KU( mac(kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'authI', roleA >, ~pid), < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >) ) @ #vk.35 )
case I_S1_mix
solve( !KU( mac(kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'authI', roleB >, ~pid), < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >) ) @ #vk.39 )
case I_S1_classic
solve( !KU( pk(~dk) ) @ #vk.40 )
case Prepare_DK
solve( !KU( ~y ) @ #vk.20 )
case R_S2_classic
solve( !KU( ~x ) @ #vk.32 )
case I_S1_classic
solve( !KU( ~y.1 ) @ #vk.22 )
case R_S2_mix
solve( !KU( ~x.1 ) @ #vk.37 )
case I_S1_mix
solve( !KU( ~y.2 ) @ #vk.26 )
case R_S2_classic
solve( !KU( ~x.2 ) @ #vk.40 )
case I_S1_classic
solve( !KU( kdf(~ck, < 'id', roleA >, ~pid) ) @ #vk.36 )
case I_S1_classic
solve( !KU( kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid) ) @ #vk.39 )
case I_S1_mix
solve( !KU( kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid) ) @ #vk.40 )
case I_S1_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #g1 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #c )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #d )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < ~x.2, ~y.2, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >), < 'id', roleB >, ~pid), ~x.2 >, ~y.2 >) >) )[no_precomp] ▶₄ #g )
case I_S2_classic_recovery_candidate
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₄ #a )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #m )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₄ #i )
case I_S2_mix
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₅ #b )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₃ #t )
case I_S2_classic
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₄ #u )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₇ #s )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₄ #u2 )
case I_S2_mix
solve( !CKValue( ~pid, ~ck )[no_precomp] ▶₅ #r )
case Pair
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₇ #q )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < ~x.1, ~y.1, ~ss, h(pk(~dk)), h(kem(~ss, pk(~dk))) >), 'ratchet', < ~pid, h(< < 'S1', '1', kdf(kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >), < 'id', roleA >, ~pid), ~x.1 >, ~y.1 >) >) )[no_precomp] ▶₅ #r2 )
case I_S2_mix
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #ep )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #eat )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #et )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #eaf )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #ctp )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #cat )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #ctt )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.13 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.14 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.15 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.16 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.17 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.18 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.19 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.20 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.21 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.22 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.23 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.24 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.25 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.26 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₅ #vr.27 )
case I_S2_classic
solve( !CKValue( ~pid, kdf(ext(~ck, < ~x, ~y, 'none' >), 'ratchet', < ~pid, h(< < 'S1', '0', kdf(~ck, < 'id', roleA >, ~pid), ~x >, ~y >) >) )[no_precomp] ▶₄ #vr.28 )
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
