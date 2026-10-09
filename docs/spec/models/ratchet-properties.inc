#include "ratchet-lifecycle.inc"

#include "ratchet-serialization.inc"

lemma lock_stage_order [use_induction, heuristic={serialization}]:
  "All pid r %s %t #i #j. LockStage(pid,r,%s)@i
     & LockStage(pid,r,%t)@j & #i < #j ==>
     Ex %previous #k. LockStage(pid,r,%previous)@k
       & %t=(%previous %+ %1) & (#i < #k | #i = #k) & #k < #j"

lemma initial_resume_serialized [use_induction, heuristic={serialization}]:
  "All pid ck x y pq rq #p #i #j. Init(pid,ck)@p
     & I_Start(pid,roleA,x,pq)@i & Cur(pid,roleA,ck)@i
     & I_Start(pid,roleA,y,rq)@j & Cur(pid,roleA,ck)@j & #i < #j ==>
     Ex %s #k. ResumeFinish(pid,roleA,%s)@k & #i < #k & #k < #j"

lemma resume_serialized [use_induction, heuristic={serialization}]:
  "All pid r %s %t #i #j. ResumeStart(pid,r,%s)@i & ResumeStart(pid,r,%t)@j & #i < #j ==>
     Ex %u #k. ResumeFinish(pid,r,%u)@k & #i < #k & #k < #j"

#include "ratchet-state-guards.inc"

#ifdef DISCLOSURE_SOURCES
#include "ratchet-disclosure-origins.inc"
#endif

#include "ratchet-origins.inc"

#include "ratchet-ck-origins.inc"

#include "ratchet-secrecy.inc"

#include "ratchet-epoch-security.inc"

#include "ratchet-progress.inc"

#include "ratchet-key-inputs.inc"

#include "ratchet-transfer-origins.inc"

#include "ratchet-transfer.inc"

#include "ratchet-acknowledgement.inc"

#include "ratchet-durability.inc"

#include "ratchet-positions.inc"

#include "ratchet-agreement.inc"
