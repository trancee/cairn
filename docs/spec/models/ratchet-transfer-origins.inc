/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma encrypted_ek_generated [reuse]:
  all-traces
  "∀ %e ek key #i.
    (EncryptedOutput( <'EK', %e, 'prefix', ek>, key ) @ #i) ⇒
    ((∃ pid r other.
       (EpGen( pid, r, %e, ek ) @ #i) ∧
       (SessionUse( pid, r, key, other ) @ #i)) ∨
     (∃ pid r other #j.
       ((EpGen( pid, r, %e, ek ) @ #j) ∧
        (SessionUse( pid, r, key, other ) @ #i)) ∧
       (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ %e ek key #i.
  (EncryptedOutput( <'EK', %e, 'prefix', ek>, key ) @ #i)
 ∧
  (∀ pid r other.
    (EpGen( pid, r, %e, ek ) @ #i) ∧
    (SessionUse( pid, r, key, other ) @ #i)
   ⇒
    ⊥) ∧
  (∀ pid r other #j.
    (EpGen( pid, r, %e, ek ) @ #j) ∧
    (SessionUse( pid, r, key, other ) @ #i)
   ⇒
    ¬(#j < #i))"
*/
simplify
solve( EncryptedOutput( <'EK', %e, 'prefix', ek>, key ) @ #i )
  case Generate_EK
  by contradiction
next
  case Resend_EK_prefix
  solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
    case Generate_EK
    by contradiction
  qed
qed

lemma encrypted_ct_encapsulated [reuse]:
  all-traces
  "∀ %e ct key #i.
    (EncryptedOutput( <'CT', %e, 'prefix', ct>, key ) @ #i) ⇒
    ((∃ pid r ek ss other.
       (EpEnc( pid, r, %e, ek, ct, ss ) @ #i) ∧
       (SessionUse( pid, r, key, other ) @ #i)) ∨
     (∃ pid r ek ss other #j.
       ((EpEnc( pid, r, %e, ek, ct, ss ) @ #j) ∧
        (SessionUse( pid, r, key, other ) @ #i)) ∧
       (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ %e ct key #i.
  (EncryptedOutput( <'CT', %e, 'prefix', ct>, key ) @ #i)
 ∧
  (∀ pid r ek ss other.
    (EpEnc( pid, r, %e, ek, ct, ss ) @ #i) ∧
    (SessionUse( pid, r, key, other ) @ #i)
   ⇒
    ⊥) ∧
  (∀ pid r ek ss other #j.
    (EpEnc( pid, r, %e, ek, ct, ss ) @ #j) ∧
    (SessionUse( pid, r, key, other ) @ #i)
   ⇒
    ¬(#j < #i))"
*/
simplify
solve( EncryptedOutput( <'CT', %e, 'prefix', ct>, key ) @ #i )
  case Encapsulate
  by contradiction
next
  case Resend_CT_prefix
  solve( !EncWait( pid, r, %e, ct, pq )[no_precomp] ▶₀ #i )
    case Encapsulate
    by contradiction
  qed
qed

lemma encrypted_ct_tail_encapsulated [reuse]:
  all-traces
  "∀ %e ct key #i.
    (EncryptedOutput( <'CT', %e, 'half', ct>, key ) @ #i) ==>
    (∃ pid r ek ss other #j.
       ((EpEnc( pid, r, %e, ek, ct, ss ) @ #j) ∧
        (SessionUse( pid, r, key, other ) @ #i)) ∧
       (#j < #i))"
simplify
solve( EncryptedOutput( <'CT', %e, 'half', ct>, key ) @ #i )
  case Send_CT_tail
  solve( !EncWait( pid, r, %e, ct, pq )[no_precomp] ▶₀ #i )
    case Encapsulate
    by contradiction
  qed
qed
