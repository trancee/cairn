/* Generated from Tamarin 1.12.0's verified default-model proof export. */

lemma epoch_agreement [hide_lemma=acknowledgement_session,
                       hide_lemma=ck_secret, hide_lemma=cur_secret,
                       hide_lemma=declared_session_secret, hide_lemma=derived_ck_origin,
                       hide_lemma=derived_ck_predecessor, hide_lemma=directional_key_ownership,
                       hide_lemma=encrypted_ct_encapsulated, hide_lemma=encrypted_ek_generated,
                       hide_lemma=encrypted_origin, hide_lemma=encrypted_progress_durable,
                       hide_lemma=epoch_secret, hide_lemma=erased_is_retired,
                       hide_lemma=extract_origin, hide_lemma=finish_has_start,
                       hide_lemma=fresh_dk_origin, hide_lemma=fresh_ss_origin,
                       hide_lemma=generator_position, hide_lemma=incoming_session_secret,
                       hide_lemma=initial_ck_secret, hide_lemma=kem_ciphertext_origin,
                       hide_lemma=lock_stage_predecessor, hide_lemma=lock_stage_unique,
                       hide_lemma=mixed_key_origin, hide_lemma=position_has_predecessor,
                       hide_lemma=position_step, hide_lemma=position_unique,
                       hide_lemma=ratchet_key_origin, hide_lemma=ratchet_key_reveal_owner,
                       hide_lemma=session_key_origin, hide_lemma=session_use_declared,
                       hide_lemma=start_has_predecessor, hide_lemma=start_stage_unique]:
  all-traces
  "∀ pid r p %e pq rq #i #j.
    (((EpochHave( pid, r, %e, pq ) @ #i) ∧
      (EpochHave( pid, p, %e, rq ) @ #j)) ∧
     (¬(r = p))) ⇒
    ((pq = rq) ∨ (∃ #d. RevCK( pid ) @ #d))"
/*
guarded formula characterizing all counter-examples:
"∃ pid r p %e pq rq #i #j.
  (EpochHave( pid, r, %e, pq ) @ #i) ∧ (EpochHave( pid, p, %e, rq ) @ #j)
 ∧
  (¬(r = p)) ∧ (¬(pq = rq)) ∧ (∀ #d. (RevCK( pid ) @ #d) ⇒ ⊥)"
*/
simplify
solve( EpochHave( pid, r, %e, pq ) @ #i )
  case Encapsulate
  solve( EpochHave( pid, p, %e, rq ) @ #j )
    case Encapsulate
    solve( !CompleteEK( pid, r, %e, ek )[-, no_precomp] ▶₀ #i )
      case Receive_EK_tail
      solve( !CompleteEK( pid, p, %e, ek.1 )[-, no_precomp] ▶₀ #j )
        case Receive_EK_tail
        solve( (∃ p #j.
                 (EpGen( pid, p, %e, ek ) @ #j) ∧ (#j < #vr.1) ∧ (¬(p = r)))  ∥
               (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.1) )
          case case_1
          solve( (∃ p.1 #j.
                   (EpGen( pid, p.1, %e, ek ) @ #j) ∧ (#j < #vr.3) ∧ (¬(p.1 = p)))  ∥
                 (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.3) )
            case case_1
            solve( !Party( pid, r, p.2 )[no_precomp] ▶₀ #vr.1 )
              case Pair_case_1
              solve( !Party( ~pid, p, p.2 )[no_precomp] ▶₀ #vr.3 )
                case Pair_case_1
                by contradiction
              next
                case Pair_case_2
                solve( DKMaterial( ~pid, p, ~dk ) ▶₃ #j.1 )
                  case Prepare_DK
                  solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.5 )
                    case Pair_case_1
                    by contradiction
                  next
                    case Pair_case_2
                    by contradiction
                  qed
                qed
              qed
            next
              case Pair_case_2
              solve( !Party( ~pid, p, p.2 )[no_precomp] ▶₀ #vr.3 )
                case Pair_case_1
                solve( DKMaterial( ~pid, p, ~dk ) ▶₃ #j.1 )
                  case Prepare_DK
                  solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.5 )
                    case Pair_case_1
                    by contradiction
                  next
                    case Pair_case_2
                    by contradiction
                  qed
                qed
              next
                case Pair_case_2
                by contradiction
              qed
            qed
          next
            case case_2
            by contradiction
          qed
        next
          case case_2
          by contradiction
        qed
      qed
    qed
  next
    case Receive_CT_tail
    solve( splitEqs(1) )
      case split_case_1
      solve( !CompleteEK( pid, r, %e, ek )[-, no_precomp] ▶₀ #i )
        case Receive_EK_tail
        solve( !GenKey( pid, p, %e, ~dk )[no_precomp] ▶₀ #j )
          case Generate_EK
          solve( !CT0( pid, p, %e, ct.1 ) ▶₁ #j )
            case Receive_CT_prefix
            solve( (∃ p #j.
                     (EpGen( pid, p, %e, ek ) @ #j) ∧ (#j < #vr.1) ∧ (¬(p = r)))  ∥
                   (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.1) )
              case case_1
              solve( (∃ p.1 ek ss #j.
                       (EpEnc( pid, p.1, %e, ek, ct.1, ss ) @ #j)
                      ∧
                       (#j < #vr.4) ∧ (¬(p.1 = p)))  ∥
                     (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.4) )
                case case_1
                solve( !CompleteEK( pid, p.3, %e, ek )[-, no_precomp] ▶₀ #j.1 )
                  case Receive_EK_tail
                  solve( (∃ p.2 #j.
                           (EpGen( pid, p.2, %e, ek ) @ #j) ∧ (#j < #vr.6) ∧ (¬(p.2 = p.1)))  ∥
                         (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.6) )
                    case case_1
                    solve( !Party( pid, r, p.2 )[no_precomp] ▶₀ #vr.1 )
                      case Pair_case_1
                      solve( !Party( ~pid, p, p.2 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        by contradiction
                      next
                        case Pair_case_2
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          solve( EncMaterial( ~pid, roleA, pk(~dk), ct, ss ) ▶₃ #i )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        next
                          case Pair_case_2
                          by contradiction
                        qed
                      qed
                    next
                      case Pair_case_2
                      solve( !Party( ~pid, p, p.2 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          by contradiction
                        next
                          case Pair_case_2
                          solve( EncMaterial( ~pid, roleB, pk(~dk), ct, ss ) ▶₃ #i )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        qed
                      next
                        case Pair_case_2
                        by contradiction
                      qed
                    qed
                  next
                    case case_2
                    by contradiction
                  qed
                qed
              next
                case case_2
                by contradiction
              qed
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      qed
    next
      case split_case_2
      solve( !CompleteEK( pid, r, %e, ek )[-, no_precomp] ▶₀ #i )
        case Receive_EK_tail
        solve( !GenKey( pid, p, %e, ~dk )[no_precomp] ▶₀ #j )
          case Generate_EK
          solve( !CT0( pid, p, %e, kem(z, pk(~dk)) ) ▶₁ #j )
            case Receive_CT_prefix
            solve( (∃ p #j.
                     (EpGen( pid, p, %e, ek ) @ #j) ∧ (#j < #vr.1) ∧ (¬(p = r)))  ∥
                   (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.1) )
              case case_1
              solve( (∃ p.1 ek ss #j.
                       (EpEnc( pid, p.1, %e, ek, kem(z, pk(~dk)), ss ) @ #j)
                      ∧
                       (#j < #vr.4) ∧ (¬(p.1 = p)))  ∥
                     (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.4) )
                case case_1
                solve( !CompleteEK( pid, p.3, %e, ek )[-, no_precomp] ▶₀ #j.1 )
                  case Receive_EK_tail
                  solve( (∃ p.2 #j.
                           (EpGen( pid, p.2, %e, ek ) @ #j) ∧ (#j < #vr.6) ∧ (¬(p.2 = p.1)))  ∥
                         (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.6) )
                    case case_1
                    solve( !Party( pid, r, p.2 )[no_precomp] ▶₀ #vr.1 )
                      case Pair_case_1
                      solve( !Party( ~pid, p, p.2 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        by contradiction
                      next
                        case Pair_case_2
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          solve( EncMaterial( ~pid, roleA, pk(~dk), kem(z, pk(~dk)), ss ) ▶₃ #i )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        next
                          case Pair_case_2
                          by contradiction
                        qed
                      qed
                    next
                      case Pair_case_2
                      solve( !Party( ~pid, p, p.2 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          by contradiction
                        next
                          case Pair_case_2
                          solve( EncMaterial( ~pid, roleB, pk(~dk), kem(z, pk(~dk)), ss ) ▶₃ #i )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        qed
                      next
                        case Pair_case_2
                        by contradiction
                      qed
                    qed
                  next
                    case case_2
                    by contradiction
                  qed
                qed
              next
                case case_2
                by contradiction
              qed
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      qed
    qed
  qed
next
  case Receive_CT_tail
  solve( splitEqs(0) )
    case split_case_1
    solve( EpochHave( pid, p, %e, rq ) @ #j )
      case Encapsulate
      solve( !CompleteEK( pid, p, %e, ek )[-, no_precomp] ▶₀ #j )
        case Receive_EK_tail
        solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
          case Generate_EK
          solve( !CT0( pid, r, %e, ct ) ▶₁ #i )
            case Receive_CT_prefix
            solve( (∃ p.1 #j.
                     (EpGen( pid, p.1, %e, ek ) @ #j) ∧ (#j < #vr.1) ∧ (¬(p.1 = p)))  ∥
                   (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.1) )
              case case_1
              solve( (∃ p ek ss #j.
                       (EpEnc( pid, p, %e, ek, ct, ss ) @ #j) ∧ (#j < #vr.4) ∧ (¬(p = r)))  ∥
                     (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.4) )
                case case_1
                solve( !CompleteEK( pid, p.3, %e, ek )[-, no_precomp] ▶₀ #j.1 )
                  case Receive_EK_tail
                  solve( (∃ p.2 #j.
                           (EpGen( pid, p.2, %e, ek ) @ #j) ∧ (#j < #vr.6) ∧ (¬(p.2 = p.1)))  ∥
                         (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.6) )
                    case case_1
                    solve( !Party( pid, p, p.2 )[no_precomp] ▶₀ #vr.1 )
                      case Pair_case_1
                      solve( !Party( ~pid, r, p.1 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        by contradiction
                      next
                        case Pair_case_2
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          solve( EncMaterial( ~pid, roleA, pk(~dk), ct, ss ) ▶₃ #j )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        next
                          case Pair_case_2
                          by contradiction
                        qed
                      qed
                    next
                      case Pair_case_2
                      solve( !Party( ~pid, r, p.1 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          by contradiction
                        next
                          case Pair_case_2
                          solve( EncMaterial( ~pid, roleB, pk(~dk), ct, ss ) ▶₃ #j )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        qed
                      next
                        case Pair_case_2
                        by contradiction
                      qed
                    qed
                  next
                    case case_2
                    by contradiction
                  qed
                qed
              next
                case case_2
                by contradiction
              qed
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      qed
    next
      case Receive_CT_tail
      solve( splitEqs(2) )
        case split_case_1
        solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
          case Generate_EK
          solve( !GenKey( pid, p, %e, ~dk.1 )[no_precomp] ▶₀ #j )
            case Generate_EK
            by contradiction
          qed
        qed
      next
        case split_case_2
        solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
          case Generate_EK
          solve( !GenKey( pid, p, %e, ~dk.1 )[no_precomp] ▶₀ #j )
            case Generate_EK
            by contradiction
          qed
        qed
      qed
    qed
  next
    case split_case_2
    solve( EpochHave( pid, p, %e, rq ) @ #j )
      case Encapsulate
      solve( !CompleteEK( pid, p, %e, ek )[-, no_precomp] ▶₀ #j )
        case Receive_EK_tail
        solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
          case Generate_EK
          solve( !CT0( pid, r, %e, kem(z, pk(~dk)) ) ▶₁ #i )
            case Receive_CT_prefix
            solve( (∃ p.1 #j.
                     (EpGen( pid, p.1, %e, ek ) @ #j) ∧ (#j < #vr.1) ∧ (¬(p.1 = p)))  ∥
                   (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.1) )
              case case_1
              solve( (∃ p ek ss #j.
                       (EpEnc( pid, p, %e, ek, kem(z, pk(~dk)), ss ) @ #j)
                      ∧
                       (#j < #vr.4) ∧ (¬(p = r)))  ∥
                     (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.4) )
                case case_1
                solve( !CompleteEK( pid, p.3, %e, ek )[-, no_precomp] ▶₀ #j.1 )
                  case Receive_EK_tail
                  solve( (∃ p.2 #j.
                           (EpGen( pid, p.2, %e, ek ) @ #j) ∧ (#j < #vr.6) ∧ (¬(p.2 = p.1)))  ∥
                         (∃ #c. (RevCK( pid ) @ #c) ∧ #c < #vr.6) )
                    case case_1
                    solve( !Party( pid, p, p.2 )[no_precomp] ▶₀ #vr.1 )
                      case Pair_case_1
                      solve( !Party( ~pid, r, p.1 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        by contradiction
                      next
                        case Pair_case_2
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          solve( EncMaterial( ~pid, roleA, pk(~dk), kem(z, pk(~dk)), ss ) ▶₃ #j )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        next
                          case Pair_case_2
                          by contradiction
                        qed
                      qed
                    next
                      case Pair_case_2
                      solve( !Party( ~pid, r, p.1 )[no_precomp] ▶₀ #vr.3 )
                        case Pair_case_1
                        solve( !Party( ~pid, p, p.1 )[no_precomp] ▶₀ #vr.6 )
                          case Pair_case_1
                          by contradiction
                        next
                          case Pair_case_2
                          solve( EncMaterial( ~pid, roleB, pk(~dk), kem(z, pk(~dk)), ss ) ▶₃ #j )
                            case Prepare_encapsulation
                            by contradiction
                          qed
                        qed
                      next
                        case Pair_case_2
                        by contradiction
                      qed
                    qed
                  next
                    case case_2
                    by contradiction
                  qed
                qed
              next
                case case_2
                by contradiction
              qed
            next
              case case_2
              by contradiction
            qed
          qed
        qed
      qed
    next
      case Receive_CT_tail
      solve( splitEqs(2) )
        case split_case_1
        solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
          case Generate_EK
          solve( !GenKey( pid, p, %e, ~dk.1 )[no_precomp] ▶₀ #j )
            case Generate_EK
            by contradiction
          qed
        qed
      next
        case split_case_2
        solve( !GenKey( pid, r, %e, ~dk )[no_precomp] ▶₀ #i )
          case Generate_EK
          solve( !GenKey( pid, p, %e, ~dk.1 )[no_precomp] ▶₀ #j )
            case Generate_EK
            by contradiction
          qed
        qed
      qed
    qed
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
