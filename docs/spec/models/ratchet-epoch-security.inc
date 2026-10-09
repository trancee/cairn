/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma epoch_secret [reuse, hide_lemma=derived_ck_origin,
                    hide_lemma=derived_ck_predecessor, hide_lemma=ck_secret,
                    hide_lemma=cur_secret]:
  all-traces
  "∀ pid r g %e ek ct ss #i #j #k.
    (((EpEnc( pid, r, %e, ek, ct, ss ) @ #i) ∧
      (EpGen( pid, g, %e, ek ) @ #j)) ∧
     (!KU( ss ) @ #k)) ⇒
    ((∃ #d. RevDK( pid, ek ) @ #d) ∨ (∃ #d. RevSS( pid, ss ) @ #d))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r g %e ek ct ss #i #j #k.
  (EpEnc( pid, r, %e, ek, ct, ss ) @ #i) ∧
  (EpGen( pid, g, %e, ek ) @ #j) ∧
  (!KU( ss ) @ #k)
 ∧
  (∀ #d. (RevDK( pid, ek ) @ #d) ⇒ ⊥) ∧
  (∀ #d. (RevSS( pid, ss ) @ #d) ⇒ ⊥)"
*/
simplify
solve( EncMaterial( pid, r, pk(~dk), ct, ss ) ▶₃ #i )
  case Prepare_encapsulation
  solve( DKMaterial( pid, g.1, ~dk ) ▶₃ #j )
    case Prepare_DK
    solve( (∃ q #d. (RevSS( q, ~ss ) @ #d) ∧ #d < #k)  ∥
           (∃ dk.1 #k.1. (!KU( dk.1 ) @ #k.1) ∧ (pk(~dk) = pk(dk.1)) ∧ #k.1 < #k) )
      case case_1
      solve( !SSValue( q, ~ss )[no_precomp] ▶₀ #d )
        case Decode_known_ciphertext
        solve( (∃ pid #j. (FreshSS( pid, ~ss, pk(~dk.1) ) @ #j) ∧ #j < #vk.1)  ∥
               (∃ #j. (!KU( ~ss ) @ #j) ∧ #j < #vk.1) )
          case case_1
          by contradiction
        next
          case case_2
          by contradiction
        qed
      next
        case Prepare_encapsulation
        by contradiction
      qed
    next
      case case_2
      solve( !DKOwner( q, ~dk )[no_precomp] ▶₀ #d )
        case Prepare_DK
        by contradiction
      qed
    qed
  qed
qed

lemma binding [hide_lemma=derived_ck_origin,
               hide_lemma=derived_ck_predecessor, hide_lemma=ck_secret,
               hide_lemma=cur_secret, hide_lemma=epoch_secret]:
  all-traces
  "∀ pid %e f ss ts ek pk ct dt ck #i #j.
    ((MixedKey( pid, %e, ss, ek, ct, ck ) @ #i) ∧
     (MixedKey( pid, f, ts, pk, dt, ck ) @ #j)) ⇒
    (((ss = ts) ∧ (ek = pk)) ∧ (ct = dt))"
/*
guarded formula characterizing all counter-examples:
"∃ pid %e f ss ts ek pk ct dt ck #i #j.
  (MixedKey( pid, %e, ss, ek, ct, ck ) @ #i) ∧
  (MixedKey( pid, f, ts, pk, dt, ck ) @ #j)
 ∧
  ((¬(ss = ts)) ∨ (¬(ek = pk)) ∨ (¬(ct = dt)))"
*/
simplify
solve( MixedKey( pid, %e, ss, ek, ct, ck ) @ #i )
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( MixedKey( pid, f, ts, pk, dt,
                     kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                         <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
           ) @ #j.1 )
      case I_S2_mix
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_2
    solve( MixedKey( pid, f, ts, pk, dt,
                     kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                         <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
           ) @ #j.1 )
      case I_S2_mix
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_3
    solve( MixedKey( pid, f, ts, pk, dt,
                     kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                         <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
           ) @ #j.1 )
      case I_S2_mix
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
next
  case R_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( MixedKey( pid, f, ts, pk, dt,
                     kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                         <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>)
           ) @ #j )
      case I_S2_mix
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_2
    solve( MixedKey( pid, f, ts, pk, dt,
                     kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                         <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>)
           ) @ #j )
      case I_S2_mix
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  next
    case split_case_3
    solve( MixedKey( pid, f, ts, pk, dt,
                     kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                         <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>)
           ) @ #j )
      case I_S2_mix
      by contradiction
    next
      case R_S2_mix
      by contradiction
    qed
  qed
qed

lemma kem_decapsulation_agreement:
  all-traces
  "∀ pid r g %e ek ct ss ts #i #j.
    ((EpEnc( pid, r, %e, ek, ct, ss ) @ #i) ∧
     (EpDec( pid, g, %e, ek, ct, ts ) @ #j)) ⇒
    (ss = ts)"
/*
guarded formula characterizing all counter-examples:
"∃ pid r g %e ek ct ss ts #i #j.
  (EpEnc( pid, r, %e, ek, ct, ss ) @ #i) ∧
  (EpDec( pid, g, %e, ek, ct, ts ) @ #j)
 ∧
  ¬(ss = ts)"
*/
simplify
solve( splitEqs(1) )
  case split_case_1
  solve( EncMaterial( pid, r, pk(~dk), ct, ss ) ▶₃ #i )
    case Prepare_encapsulation
    by contradiction
  qed
next
  case split_case_2
  solve( EncMaterial( pid, r, pk(~dk), kem(ts, pk(~dk)), ss ) ▶₃ #i )
    case Prepare_encapsulation
    by contradiction
  qed
qed

lemma mixed_key_origin [reuse, hide_lemma=derived_ck_predecessor,
                        hide_lemma=derived_ck_origin, hide_lemma=initial_ck_secret,
                        hide_lemma=ck_secret, hide_lemma=cur_secret]:
  all-traces
  "∀ pid %e ss ek ct ck #i #j.
    ((MixedKey( pid, %e, ss, ek, ct, ck ) @ #i) ∧ (!KU( ck ) @ #j)) ⇒
    ((∃ #k. (!KU( ss ) @ #k) ∧ (#k < #j)) ∨ (∃ #d. RevCKv( pid, ck ) @ #d))"
/*
guarded formula characterizing all counter-examples:
"∃ pid %e ss ek ct ck #i #j.
  (MixedKey( pid, %e, ss, ek, ct, ck ) @ #i) ∧ (!KU( ck ) @ #j)
 ∧
  (∀ #k. (!KU( ss ) @ #k) ⇒ ¬(#k < #j)) ∧
  (∀ #d. (RevCKv( pid, ck ) @ #d) ⇒ ⊥)"
*/
simplify
solve( MixedKey( pid, %e, ss, ek, ct, ck ) @ #i )
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( (∃ #j.2.
             (!KU( ext(ck, <x, y, ss, h(ek), h(ct)>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
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
             (!KU( ext(ck, <x, y, ss, h(ek), h(ct)>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
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
             (!KU( ext(ck, <x, y, ss, h(ek), h(ct)>) ) @ #j.2) ∧ #j.2 < #j.1)  ∥
           (∃ pid.1 #j.2.
             (RevCKv( pid.1,
                      kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
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
  case R_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( (∃ #j.1.
             (!KU( ext(ck, <x, ~y, ss, h(ek), h(ct)>) ) @ #j.1) ∧ #j.1 < #j)  ∥
           (∃ pid.1 #j.1.
             (RevCKv( pid.1,
                      kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>)
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
             (!KU( ext(ck, <x, ~y, ss, h(ek), h(ct)>) ) @ #j.1) ∧ #j.1 < #j)  ∥
           (∃ pid.1 #j.1.
             (RevCKv( pid.1,
                      kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>)
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
             (!KU( ext(ck, <x, ~y, ss, h(ek), h(ct)>) ) @ #j.1) ∧ #j.1 < #j)  ∥
           (∃ pid.1 #j.1.
             (RevCKv( pid.1,
                      kdf(ext(ck, <x, ~y, ss, h(ek), h(ct)>), 'ratchet',
                          <pid, h(<<'S1', '1', kdf(ck, <'id', p>, pid), x>, ~y>)>)
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

lemma pcs_epoch [hide_lemma=derived_ck_predecessor,
                 hide_lemma=derived_ck_origin, hide_lemma=initial_ck_secret,
                 hide_lemma=ck_secret, hide_lemma=cur_secret]:
  all-traces
  "∀ pid %e r g ss ek ct ck #i #a #b.
    (((MixedKey( pid, %e, ss, ek, ct, ck ) @ #i) ∧
      (EpGen( pid, g, %e, ek ) @ #a)) ∧
     (EpEnc( pid, r, %e, ek, ct, ss ) @ #b)) ⇒
    ((((¬(∃ #k. K( ck ) @ #k)) ∨ (∃ #d. RevDK( pid, ek ) @ #d)) ∨
      (∃ #d. RevSS( pid, ss ) @ #d)) ∨
     (∃ #d. RevCKv( pid, ck ) @ #d))"
/*
guarded formula characterizing all counter-examples:
"∃ pid %e r g ss ek ct ck #i #a #b.
  (MixedKey( pid, %e, ss, ek, ct, ck ) @ #i) ∧
  (EpGen( pid, g, %e, ek ) @ #a) ∧
  (EpEnc( pid, r, %e, ek, ct, ss ) @ #b)
 ∧
  (∃ #k. (K( ck ) @ #k)) ∧
  (∀ #d. (RevDK( pid, ek ) @ #d) ⇒ ⊥) ∧
  (∀ #d. (RevSS( pid, ss ) @ #d) ⇒ ⊥) ∧
  (∀ #d. (RevCKv( pid, ck ) @ #d) ⇒ ⊥)"
*/
simplify
solve( MixedKey( pid, %e, ss, pk(~dk), ct, ck.2 ) @ #i )
  case I_S2_mix
  solve( (∃ #k. (!KU( ss ) @ #k) ∧ #k < #vk)  ∥
         (∃ #d.
           (RevCKv( pid,
                    kdf(ext(ck.2, <x, y, ss, h(pk(~dk)), h(ct)>), 'ratchet',
                        <pid, h(<<'S1', '1', kdf(ck.2, <'id', r.1>, pid), x>, y>)>)
            ) @ #d)) )
    case case_1
    solve( (∃ #d. (RevDK( pid, pk(~dk) ) @ #d))  ∥
           (∃ #d. (RevSS( pid, ss ) @ #d)) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case case_2
    by contradiction
  qed
next
  case R_S2_mix
  solve( (∃ #k. (!KU( ss ) @ #k) ∧ #k < #vk)  ∥
         (∃ #d.
           (RevCKv( pid,
                    kdf(ext(ck.2, <x, ~y, ss, h(pk(~dk)), h(ct)>), 'ratchet',
                        <pid, h(<<'S1', '1', kdf(ck.2, <'id', p>, pid), x>, ~y>)>)
            ) @ #d)) )
    case case_1
    solve( (∃ #d. (RevDK( pid, pk(~dk) ) @ #d))  ∥
           (∃ #d. (RevSS( pid, ss ) @ #d)) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case case_2
    by contradiction
  qed
qed

lemma hndl_secrecy:
  all-traces
  "∀ pid r p x pq ki kr #i.
    (I_Commit( pid, r, p, x, pq, ki, kr ) @ #i) ⇒
    (((¬(∃ #k. K( ki ) @ #k)) ∧ (¬(∃ #k. K( kr ) @ #k))) ∨
     (∃ #d. RevCK( pid ) @ #d))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r p x pq ki kr #i.
  (I_Commit( pid, r, p, x, pq, ki, kr ) @ #i)
 ∧
  (((∃ #k. (K( ki ) @ #k)) ∨ (∃ #k. (K( kr ) @ #k)))) ∧
  (∀ #d. (RevCK( pid ) @ #d) ⇒ ⊥)"
*/
simplify
solve( I_Commit( pid, r, p, x, pq, ki, kr ) @ #i )
  case I_S2_classic
  solve( (∃ #k.
           (K( kdf(ext(ck, <x, y, 'none'>), 'skI',
                   <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
            ) @ #k))  ∥
         (∃ #k.
           (K( kdf(ext(ck, <x, y, 'none'>), 'skR',
                   <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
            ) @ #k)) )
    case case_1
    by contradiction
  next
    case case_2
    by contradiction
  qed
next
  case I_S2_classic_recovery_candidate
  solve( (∃ #k.
           (K( kdf(ext(ck, <x, y, 'none'>), 'skI',
                   <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
            ) @ #k))  ∥
         (∃ #k.
           (K( kdf(ext(ck, <x, y, 'none'>), 'skR',
                   <pid, h(<<'S1', '0', kdf(ck, <'id', r>, pid), x>, y>)>)
            ) @ #k)) )
    case case_1
    by contradiction /* from formulas */
  next
    case case_2
    by contradiction /* from formulas */
  qed
next
  case I_S2_mix
  solve( splitEqs(0) )
    case split_case_1
    solve( (∃ #k.
             (K( kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skI',
                     <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
              ) @ #k))  ∥
           (∃ #k.
             (K( kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skR',
                     <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
              ) @ #k)) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case split_case_2
    solve( (∃ #k.
             (K( kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skI',
                     <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
              ) @ #k))  ∥
           (∃ #k.
             (K( kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skR',
                     <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
              ) @ #k)) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  next
    case split_case_3
    solve( (∃ #k.
             (K( kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skI',
                     <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
              ) @ #k))  ∥
           (∃ #k.
             (K( kdf(ext(ck, <x, y, ss, h(ek), h(ct)>), 'skR',
                     <pid, h(<<'S1', '1', kdf(ck, <'id', r>, pid), x>, y>)>)
              ) @ #k)) )
      case case_1
      by contradiction
    next
      case case_2
      by contradiction
    qed
  qed
qed
