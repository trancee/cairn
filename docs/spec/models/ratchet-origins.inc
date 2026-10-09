/* Generated from Tamarin 1.12.0's verified default-model proof export. */

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-kem-origin.inc"
#else
lemma kem_ciphertext_origin [reuse, use_induction]:
  all-traces
  "∀ ss ek #i.
    (!KU( kem(ss, ek) ) @ #i) ⇒
    ((∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (#j < #i)) ∨
     (∃ #j. (!KU( ss ) @ #j) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ ss ek #i.
  (!KU( kem(ss, ek) ) @ #i)
 ∧
  (∀ pid #j. (FreshSS( pid, ss, ek ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ #j. (!KU( ss ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ pid #j. (FreshSS( pid, ss, ek ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ #j. (!KU( ss ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
    case case_1
    solve( !KU( kem(ss, ek) ) @ #i )
      case Encapsulate
      by contradiction
    next
      case Prepare_encapsulation
      by contradiction
    next
      case Resend_CT_prefix
      by contradiction
    next
      case Reveal_CK
      solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
        case I_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_classic_recovery_candidate
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case R_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      qed
    next
      case Reveal_SS
      solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
        case Decode_known_ciphertext
        solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
          case Pair_case_1
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk))  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk)) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        next
          case Pair_case_2
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j.
                     (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk))  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #vk)) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      next
        case Prepare_encapsulation
        by contradiction
      qed
    next
      case Send_CT_tail
      by contradiction
    next
      case c_kem
      by contradiction
    qed
  next
    case case_2
    by contradiction
  next
    case case_3
    by contradiction
  qed
qed

#endif

lemma dk_reveal_owner [sources]:
  all-traces
  "∀ pid q dk #i #j.
    ((FreshDK( pid, dk ) @ #i) ∧ (RevDK( q, pk(dk) ) @ #j)) ⇒ (pid = q)"
/*
guarded formula characterizing all counter-examples:
"∃ pid q dk #i #j.
  (FreshDK( pid, dk ) @ #i) ∧ (RevDK( q, pk(dk) ) @ #j) ∧ ¬(pid = q)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (pid = q) )
    case case_1
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !DKOwner( q, ~dk )[no_precomp] ▶₀ #j )
        case Prepare_DK
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !DKOwner( q, ~dk )[no_precomp] ▶₀ #j )
        case Prepare_DK
        by contradiction
      qed
    qed
  next
    case case_2
    by contradiction
  qed
qed

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-encrypted-origin.inc"
#else
lemma encrypted_origin [reuse, use_induction]:
  all-traces
  "∀ m k #i.
    (!KU( senc(m, k) ) @ #i) ⇒
    ((∃ #j. (EncryptedOutput( m, k ) @ #j) ∧ (#j < #i)) ∨
     (∃ #j #l.
       (((!KU( m ) @ #j) ∧ (!KU( k ) @ #l)) ∧ (#j < #i)) ∧ (#l < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ m k #i.
  (!KU( senc(m, k) ) @ #i)
 ∧
  (∀ #j. (EncryptedOutput( m, k ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ #j #l.
    (!KU( m ) @ #j) ∧ (!KU( k ) @ #l) ⇒ ((¬(#j < #i)) ∨ (¬(#l < #i))))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j. (EncryptedOutput( m, k ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ #j #l.
           (!KU( m ) @ #j) ∧ (!KU( k ) @ #l)
          ∧
           (¬(last(#l))) ∧ (¬(last(#j))) ∧ (#j < #i) ∧ (#l < #i)) )
    case case_1
    solve( !KU( senc(m, k) ) @ #i )
      case Encapsulate
      by contradiction
    next
      case Generate_EK
      by contradiction
    next
      case I_S2_classic
      by contradiction
    next
      case I_S2_classic_recovery_candidate
      by contradiction /* from formulas */
    next
      case I_S2_mix
      by contradiction
    next
      case Receive_CT_duplicate_prefix_complete_case_1
      by contradiction
    next
      case Receive_CT_duplicate_prefix_complete_case_2
      by contradiction
    next
      case Receive_CT_prefix
      by contradiction
    next
      case Receive_CT_tail_case_1
      by contradiction
    next
      case Receive_CT_tail_case_2
      by contradiction
    next
      case Receive_EK_duplicate_prefix_complete
      by contradiction
    next
      case Receive_EK_prefix
      by contradiction
    next
      case Receive_EK_tail
      by contradiction
    next
      case Resend_CT_prefix
      by contradiction
    next
      case Resend_CT_progress_full_case_1
      by contradiction
    next
      case Resend_CT_progress_full_case_2
      by contradiction
    next
      case Resend_CT_progress_half
      by contradiction
    next
      case Resend_EK_prefix
      by contradiction
    next
      case Resend_EK_progress_full
      by contradiction
    next
      case Resend_EK_progress_half
      by contradiction
    next
      case Reveal_CK
      solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
        case I_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_classic_recovery_candidate
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case R_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      qed
    next
      case Reveal_SS
      solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
        case Decode_known_ciphertext
        solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
          case Pair_case_1
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        next
          case Pair_case_2
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      next
        case Prepare_encapsulation
        by contradiction
      qed
    next
      case Send_CT_tail
      by contradiction
    next
      case Send_EK_tail
      by contradiction
    next
      case c_senc
      by contradiction
    qed
  next
    case case_2
    by contradiction
  next
    case case_3
    by contradiction
  qed
qed
#endif

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-extract-origin.inc"
#else
lemma extract_origin [reuse, use_induction]:
  all-traces
  "∀ ck ikm #i.
    (!KU( ext(ck, ikm) ) @ #i) ⇒
    (∃ #j #k.
      (((!KU( ck ) @ #j) ∧ (!KU( ikm ) @ #k)) ∧ (#j < #i)) ∧ (#k < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ ck ikm #i.
  (!KU( ext(ck, ikm) ) @ #i)
 ∧
  ∀ #j #k.
   (!KU( ck ) @ #j) ∧ (!KU( ikm ) @ #k) ⇒ ((¬(#j < #i)) ∨ (¬(#k < #i)))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j #k.
           (!KU( ck ) @ #j) ∧ (!KU( ikm ) @ #k)
          ∧
           (¬(last(#k))) ∧ (¬(last(#j))) ∧ (#j < #i) ∧ (#k < #i)) )
    case case_1
    solve( !KU( ext(ck, ikm) ) @ #i )
      case Reveal_CK
      solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
        case I_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_classic_recovery_candidate
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case I_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        by solve( (#vl, 0) ~~> (#i, 0) )
      next
        case R_S2_mix
        by solve( (#vl, 0) ~~> (#i, 0) )
      qed
    next
      case Reveal_SS
      solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
        case Decode_known_ciphertext
        solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
          case Pair_case_1
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        next
          case Pair_case_2
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      next
        case Prepare_encapsulation
        by contradiction
      qed
    next
      case c_ext
      by contradiction
    qed
  next
    case case_2
    by contradiction
  qed
qed
#endif

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-ratchet-key-origin.inc"
#else
lemma ratchet_key_origin [reuse, use_induction]:
  all-traces
  "∀ prk ctx #i.
    (!KU( kdf(prk, 'ratchet', ctx) ) @ #i) ⇒
    ((∃ #j. (!KU( prk ) @ #j) ∧ (#j < #i)) ∨
     (∃ pid #j. (RevCKv( pid, kdf(prk, 'ratchet', ctx) ) @ #j) ∧ (#j < #i)))"
/*
guarded formula characterizing all counter-examples:
"∃ prk ctx #i.
  (!KU( kdf(prk, 'ratchet', ctx) ) @ #i)
 ∧
  (∀ #j. (!KU( prk ) @ #j) ⇒ ¬(#j < #i)) ∧
  (∀ pid #j. (RevCKv( pid, kdf(prk, 'ratchet', ctx) ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#i))  ∥
         (∃ #j. (!KU( prk ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i))  ∥
         (∃ pid #j.
           (RevCKv( pid, kdf(prk, 'ratchet', ctx) ) @ #j)
          ∧
           (¬(last(#j))) ∧ (#j < #i)) )
    case case_1
    solve( !KU( kdf(prk, 'ratchet', ctx) ) @ #i )
      case Reveal_CK
      solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
        case I_S2_classic
        solve( (#vl, 0) ~~> (#i, 0) )
          case kdf
          by contradiction
        qed
      next
        case I_S2_classic_recovery_candidate
        solve( (#vl, 0) ~~> (#i, 0) )
          case kdf
          by contradiction /* from formulas */
        qed
      next
        case I_S2_mix
        solve( (#vl, 0) ~~> (#i, 0) )
          case kdf
          by contradiction
        qed
      next
        case Pair
        by contradiction
      next
        case R_S2_classic
        solve( (#vl, 0) ~~> (#i, 0) )
          case kdf
          by contradiction
        qed
      next
        case R_S2_mix
        solve( (#vl, 0) ~~> (#i, 0) )
          case kdf
          by contradiction
        qed
      qed
    next
      case Reveal_SS
      solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
        case Decode_known_ciphertext
        solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
          case Pair_case_1
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        next
          case Pair_case_2
          solve( splitEqs(0) )
            case split_case_1
            by solve( (#vl, 0) ~~> (#i, 0) )
          next
            case split_case_2
            solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                   (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
              case case_1
              by contradiction
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      next
        case Prepare_encapsulation
        by contradiction
      qed
    next
      case c_kdf
      by contradiction
    qed
  next
    case case_2
    by contradiction
  next
    case case_3
    by contradiction
  qed
qed
#endif

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-session-key-origin.inc"
#else
lemma session_key_origin [reuse, use_induction]:
  all-traces
  "∀ prk label ctx #i.
    ((!KU( kdf(prk, label, ctx) ) @ #i) ∧
     ((label = 'skI') ∨ (label = 'skR'))) ⇒
    (∃ #j. (!KU( prk ) @ #j) ∧ (#j < #i))"
/*
guarded formula characterizing all counter-examples:
"∃ prk label ctx #i.
  (!KU( kdf(prk, label, ctx) ) @ #i)
 ∧
  (((label = 'skI') ∨ (label = 'skR'))) ∧
  (∀ #j. (!KU( prk ) @ #j) ⇒ ¬(#j < #i))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (label = 'skI')  ∥ (label = 'skR') )
    case case_1
    solve( (last(#i))  ∥
           (∃ #j. (!KU( prk ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
      case case_1
      solve( !KU( kdf(prk, 'skI', ctx) ) @ #i )
        case Reveal_CK
        solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) )
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
          case Decode_known_ciphertext
          solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
            case Pair_case_1
            solve( splitEqs(0) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#i, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by contradiction
              next
                case case_2
                by contradiction
              qed
            qed
          next
            case Pair_case_2
            solve( splitEqs(0) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#i, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by contradiction
              next
                case case_2
                by contradiction
              qed
            qed
          qed
        next
          case Prepare_encapsulation
          by contradiction
        qed
      next
        case c_kdf
        by contradiction
      qed
    next
      case case_2
      by contradiction
    qed
  next
    case case_2
    solve( (last(#i))  ∥
           (∃ #j. (!KU( prk ) @ #j) ∧ (¬(last(#j))) ∧ (#j < #i)) )
      case case_1
      solve( !KU( kdf(prk, 'skR', ctx) ) @ #i )
        case Reveal_CK
        solve( !CKValue( pid, t )[no_precomp] ▶₀ #vr )
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case Pair
          by contradiction
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#i, 0) )
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#i, 0) )
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid, t )[no_precomp] ▶₀ #vr )
          case Decode_known_ciphertext
          solve( !Party( pid, r.1, p )[no_precomp] ▶₀ #vr.2 )
            case Pair_case_1
            solve( splitEqs(0) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#i, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by contradiction
              next
                case case_2
                by contradiction
              qed
            qed
          next
            case Pair_case_2
            solve( splitEqs(0) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#i, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by contradiction
              next
                case case_2
                by contradiction
              qed
            qed
          qed
        next
          case Prepare_encapsulation
          by contradiction
        qed
      next
        case c_kdf
        by contradiction
      qed
    next
      case case_2
      by contradiction
    qed
  qed
qed
#endif

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-fresh-dk-origin.inc"
#else
lemma fresh_dk_origin [reuse, use_induction]:
  all-traces
  "∀ pid dk #i #j.
    ((FreshDK( pid, dk ) @ #i) ∧ (!KU( dk ) @ #j)) ⇒
    (∃ q #d. (RevDK( q, pk(dk) ) @ #d) ∧ (#d < #j))"
/*
guarded formula characterizing all counter-examples:
"∃ pid dk #i #j.
  (FreshDK( pid, dk ) @ #i) ∧ (!KU( dk ) @ #j)
 ∧
  ∀ q #d. (RevDK( q, pk(dk) ) @ #d) ⇒ ¬(#d < #j)"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (last(#i))  ∥
         (∃ q #d. (RevDK( q, pk(~dk) ) @ #d) ∧ (¬(last(#d))) ∧ (#d < #j)) )
    case case_1
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~dk ) @ #j )
        case Reveal_CK
        solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case Pair
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      next
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( !Party( pid.1, r.1, p )[no_precomp] ▶₀ #vr.3 )
            case Pair_case_1
            solve( splitEqs(1) )
              case split_case_1
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by solve( (#vl, 0) ~~> (#j, 0) )
              next
                case case_2
                by contradiction
              qed
            next
              case split_case_2
              by solve( (#vl, 0) ~~> (#j, 0) )
            qed
          next
            case Pair_case_2
            solve( splitEqs(1) )
              case split_case_1
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by solve( (#vl, 0) ~~> (#j, 0) )
              next
                case case_2
                by contradiction
              qed
            next
              case split_case_2
              by solve( (#vl, 0) ~~> (#j, 0) )
            qed
          qed
        next
          case Prepare_encapsulation
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      qed
    next
      case Pair_case_2
      solve( !KU( ~dk ) @ #j )
        case Reveal_CK
        solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case Pair
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      next
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( !Party( pid.1, r.1, p )[no_precomp] ▶₀ #vr.3 )
            case Pair_case_1
            solve( splitEqs(1) )
              case split_case_1
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by solve( (#vl, 0) ~~> (#j, 0) )
              next
                case case_2
                by contradiction
              qed
            next
              case split_case_2
              by solve( (#vl, 0) ~~> (#j, 0) )
            qed
          next
            case Pair_case_2
            solve( splitEqs(1) )
              case split_case_1
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk.1) ) @ #j) ∧ #j < #vk)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk) )
                case case_1
                by solve( (#vl, 0) ~~> (#j, 0) )
              next
                case case_2
                by contradiction
              qed
            next
              case split_case_2
              by solve( (#vl, 0) ~~> (#j, 0) )
            qed
          qed
        next
          case Prepare_encapsulation
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      qed
    qed
  next
    case case_2
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~dk ) @ #j )
        case Reveal_CK
        by contradiction
      next
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !KU( ~dk ) @ #j )
        case Reveal_CK
        by contradiction
      next
        case Reveal_DK
        by contradiction
      next
        case Reveal_SS
        by contradiction
      qed
    qed
  next
    case case_3
    by contradiction
  qed
qed
#endif

#ifdef DISCLOSURE_SOURCES
#include "ratchet-refined-fresh-ss-origin.inc"
#else
lemma fresh_ss_origin [reuse, use_induction]:
  all-traces
  "∀ pid ss ek #i #j.
    ((FreshSS( pid, ss, ek ) @ #i) ∧ (!KU( ss ) @ #j)) ⇒
    ((∃ q #d. (RevSS( q, ss ) @ #d) ∧ (#d < #j)) ∨
     (∃ dk #k. ((!KU( dk ) @ #k) ∧ (ek = pk(dk))) ∧ (#k < #j)))"
/*
guarded formula characterizing all counter-examples:
"∃ pid ss ek #i #j.
  (FreshSS( pid, ss, ek ) @ #i) ∧ (!KU( ss ) @ #j)
 ∧
  (∀ q #d. (RevSS( q, ss ) @ #d) ⇒ ¬(#d < #j)) ∧
  (∀ dk #k. (!KU( dk ) @ #k) ∧ (ek = pk(dk)) ⇒ ¬(#k < #j))"
*/
induction
  case empty_trace
  by contradiction
next
  case non_empty_trace
  solve( (last(#j))  ∥ (last(#i))  ∥
         (∃ q #d. (RevSS( q, ~ss ) @ #d) ∧ (¬(last(#d))) ∧ (#d < #j))  ∥
         (∃ dk #k. (!KU( dk ) @ #k) ∧ (ek = pk(dk)) ∧ (¬(last(#k))) ∧ (#k < #j)) )
    case case_1
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case Pair
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( !Party( pid.1, r.1, p )[no_precomp] ▶₀ #vr.3 )
            case Pair_case_1
            solve( splitEqs(1) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) )
                  case Var_fresh_1_ss
                  by contradiction
                qed
              next
                case case_2
                by contradiction
              qed
            qed
          next
            case Pair_case_2
            solve( splitEqs(1) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) )
                  case Var_fresh_1_ss
                  by contradiction
                qed
              next
                case case_2
                by contradiction
              qed
            qed
          qed
        next
          case Prepare_encapsulation
          solve( (#vl, 0) ~~> (#j, 0) )
            case Var_fresh_1_ss
            by contradiction
          qed
        qed
      next
        case Send_CT_tail
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        solve( !CKValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case I_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_classic_recovery_candidate
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case I_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case Pair
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_classic
          by solve( (#vl, 0) ~~> (#j, 0) )
        next
          case R_S2_mix
          by solve( (#vl, 0) ~~> (#j, 0) )
        qed
      next
        case Reveal_SS
        solve( !SSValue( pid.1, t )[no_precomp] ▶₀ #vr.1 )
          case Decode_known_ciphertext
          solve( !Party( pid.1, r.1, p )[no_precomp] ▶₀ #vr.3 )
            case Pair_case_1
            solve( splitEqs(1) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) )
                  case Var_fresh_1_ss
                  by contradiction
                qed
              next
                case case_2
                by contradiction
              qed
            qed
          next
            case Pair_case_2
            solve( splitEqs(1) )
              case split_case_1
              by solve( (#vl, 0) ~~> (#j, 0) )
            next
              case split_case_2
              solve( (∃ pid #j. (FreshSS( pid, t, pk(~dk) ) @ #j) ∧ #j < #vk.1)  ∥
                     (∃ #j. (!KU( t ) @ #j) ∧ #j < #vk.1) )
                case case_1
                solve( (#vl, 0) ~~> (#j, 0) )
                  case Var_fresh_1_ss
                  by contradiction
                qed
              next
                case case_2
                by contradiction
              qed
            qed
          qed
        next
          case Prepare_encapsulation
          solve( (#vl, 0) ~~> (#j, 0) )
            case Var_fresh_1_ss
            by contradiction
          qed
        qed
      next
        case Send_CT_tail
        by contradiction
      qed
    qed
  next
    case case_2
    solve( !Party( pid, r, p )[no_precomp] ▶₀ #i )
      case Pair_case_1
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        by contradiction
      next
        case Reveal_SS
        by contradiction
      next
        case Send_CT_tail
        by contradiction
      qed
    next
      case Pair_case_2
      solve( !KU( ~ss ) @ #j )
        case Encapsulate
        by contradiction
      next
        case Prepare_encapsulation
        by contradiction
      next
        case Resend_CT_prefix
        by contradiction
      next
        case Reveal_CK
        by contradiction
      next
        case Reveal_SS
        by contradiction
      next
        case Send_CT_tail
        by contradiction
      qed
    qed
  next
    case case_3
    by contradiction
  next
    case case_4
    by contradiction
  qed
qed
#endif

