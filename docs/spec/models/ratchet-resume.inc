/* Resume: the epoch is local metadata, not an added S1 field. */
/* Reserving/releasing the linear mutex is separate from cryptographic work.
 * LockStage records each ordinal once: Pair seeds it, Acquire advances it, and
 * completion advances it before Release. LockRelease records the unlock.
 * The stage is a ghost ordinal, not a packet field or a bounded counter.
 * no_precomp leaves mutex histories to proof search without changing traces. */
rule Acquire_Resume:
  [ ResumeSlot(pid,r,%s)[no_precomp] ]
--[ TraceStep(pid,r,'Acquire_Resume',%s),  LockStage(pid,r,(%s %+ %1)), LockAcquire(pid,r,(%s %+ %1)) ]->
  [ StartPermit(pid,r,(%s %+ %1)), BusySlot(pid,r,(%s %+ %1)) ]

rule Release_Resume:
  [ FinishPermit(pid,r,%s)[no_precomp] ]
--[ TraceStep(pid,r,'Release_Resume',%s),  LockStage(pid,r,%s), LockRelease(pid,r,%s) ]-> [ ResumeSlot(pid,r,%s) ]

rule I_S1_classic:
  let m = <'S1','0',kdf(ck,<'id',r>,pid),~x>
  in
  [ StartPermit(pid,r,%s)[no_precomp], !Party(pid,r,p)[no_precomp], !St(pid,r,ck,%e,g)[no_precomp], Fr(~x), !CKValue(pid,ck)[no_precomp] ]
--[ TraceStep(pid,r,'I_S1_classic',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeStart(pid,r,%s), ClassicStart(pid,r,%e), I_Start(pid,r,~x,'none') ]->
  [ IWait(pid,r,p,ck,%e,g,%e,g,~x,'0','none','none','none','none',%s),
    Out(<m,mac(kdf(ck,<'authI',r>,pid),m)>) ]

rule I_S1_mix:
  let pq = <ss,h(ek),h(ct)>
      m = <'S1','1',kdf(ck,<'id',r>,pid),~x>
  in
  [ StartPermit(pid,r,%s)[no_precomp], !Party(pid,r,p)[no_precomp], !Party(pid,g,ng)[no_precomp], !St(pid,r,ck,%e,g)[no_precomp], !ReadyEpoch(pid,r,%e,pq)[no_precomp],
    !Have(pid,r,%e,pq,ss,ek,ct)[no_precomp], Fr(~x), !CKValue(pid,ck)[no_precomp] ]
--[ TraceStep(pid,r,'I_S1_mix',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeStart(pid,r,%s), I_Start(pid,r,~x,pq), MixStart(pid,r,%e,pq) ]->
  [ IWait(pid,r,p,ck,%e,g,(%e %+ %1),ng,~x,'1',pq,ss,ek,ct,%s),
    Out(<m,mac(kdf(ck,<'authI',r>,pid),m)>) ]

rule R_S2_classic:
  let y = ~y
      m = <'S1','0',kdf(ck,<'id',p>,pid),x>
      th = h(<m,y>)
      prk = ext(ck,<x,y,'none'>)
      ki = kdf(prk,'skI',<pid,th>)
      kr = kdf(prk,'skR',<pid,th>)
      ck1 = kdf(prk,'ratchet',<pid,th>)
  in
  [ StartPermit(pid,r,%s)[no_precomp], !Party(pid,r,p)[no_precomp], !St(pid,r,ck,%e,g)[no_precomp], In(<m,mac(kdf(ck,<'authI',p>,pid),m)>), Fr(~y), !CKValue(pid,ck)[no_precomp] ]
--[ TraceStep(pid,r,'R_S2_classic',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeStart(pid,r,%s), R_Accept(pid,r,p,x,'none',ki,kr),
    DerivedCK(pid,ck,ck1), CK(pid,ck1), KeyDeclared(pid,r,kr,ki) ]->
  [ !SKValue(pid,r,kr,ki), !CKValue(pid,ck1), RPending(pid,r,p,ck,ck1,%e,g,'none',ki,kr,%s),
    Out(<y,mac(kdf(ck,'authR',pid),<'S2',th>)>) ]

rule R_S2_mix:
  let pq = <ss,h(ek),h(ct)>
      ng = flip(g)
      y = ~y
      m = <'S1','1',kdf(ck,<'id',p>,pid),x>
      th = h(<m,y>)
      prk = ext(ck,<x,y,pq>)
      ki = kdf(prk,'skI',<pid,th>)
      kr = kdf(prk,'skR',<pid,th>)
      ck1 = kdf(prk,'ratchet',<pid,th>)
  in
  [ StartPermit(pid,r,%s)[no_precomp], !Party(pid,r,p)[no_precomp], !Party(pid,g,ng)[no_precomp], !St(pid,r,ck,%e,g)[no_precomp], !Have(pid,r,%e,pq,ss,ek,ct)[no_precomp],
    In(<m,mac(kdf(ck,<'authI',p>,pid),m)>), Fr(~y), !CKValue(pid,ck)[no_precomp],
    !PositionValue(pid,%e,g)[no_precomp] ]
--[ TraceStep(pid,r,'R_S2_mix',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeStart(pid,r,%s), R_Accept(pid,r,p,x,pq,ki,kr),
    DerivedCK(pid,ck,ck1), MixedKey(pid,%e,ss,ek,ct,ck1), CK(pid,ck1),
    KeyDeclared(pid,r,kr,ki), Position(pid,(%e %+ %1),ng) ]->
  [ !PositionValue(pid,(%e %+ %1),ng), !SKValue(pid,r,kr,ki), !CKValue(pid,ck1), RPending(pid,r,p,ck,ck1,(%e %+ %1),ng,pq,ki,kr,%s),     Out(<y,mac(kdf(ck,'authR',pid),<'S2',th>)>) ]

rule I_S2_classic:
  let m = <'S1','0',kdf(ck,<'id',r>,pid),x>
      th = h(<m,y>)
      prk = ext(ck,<x,y,'none'>)
      ki = kdf(prk,'skI',<pid,th>)
      kr = kdf(prk,'skR',<pid,th>)
      ck1 = kdf(prk,'ratchet',<pid,th>)
  in
  [ BusySlot(pid,r,%s)[no_precomp], IWait(pid,r,p,ck,%e,g,%e,g,x,'0','none','none','none','none',%s)[no_precomp], CandidateState(pid,r,a,b)[no_precomp],
    In(<y,mac(kdf(ck,'authR',pid),<'S2',th>)>), !CKValue(pid,ck)[no_precomp],
    !Index(pid,r,%e,g)[no_precomp] ]
--[ TraceStep(pid,r,'I_S2_classic',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeFinish(pid,r,(%s %+ %1)), Retire(pid,r,ck),
    CandidateBefore(pid,r,a,b), Retire(pid,r,a), Retire(pid,r,b), ErasedBranch(pid,r,a), ErasedBranch(pid,r,b),
    I_Commit(pid,r,p,x,'none',ki,kr), I_Advance(pid,r,ck,ck1,%e,%e),
    DerivedCK(pid,ck,ck1), CK(pid,ck1), KeyDeclared(pid,r,ki,kr), EncryptedOutput('data',ki),
    Candidates(pid,r,ck1,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck1,'none'), !SKValue(pid,r,ki,kr), !CKValue(pid,ck1), !St(pid,r,ck1,%e,g), !Session(pid,r,ck1,%e,g,ki,kr), Out(senc('data',ki)) ]

/* Selecting an already-mixed candidate commits its position, not another MIX. */
rule I_S2_classic_recovery_candidate:
  let ng = flip(oldg)
      m = <'S1','0',kdf(ck,<'id',r>,pid),x>
      th = h(<m,y>)
      prk = ext(ck,<x,y,'none'>)
      ki = kdf(prk,'skI',<pid,th>)
      kr = kdf(prk,'skR',<pid,th>)
      ck1 = kdf(prk,'ratchet',<pid,th>)
  in
  [ BusySlot(pid,r,%s)[no_precomp],
    IWait(pid,r,p,ck,(%e %+ %1),ng,(%e %+ %1),ng,x,'0','none','none','none','none',%s)[no_precomp],
    CandidateState(pid,r,old,ck)[no_precomp],
    In(<y,mac(kdf(ck,'authR',pid),<'S2',th>)>), !CKValue(pid,ck)[no_precomp],
    !Index(pid,r,%e,oldg)[no_precomp], !Party(pid,oldg,ng)[no_precomp],
    !PositionValue(pid,(%e %+ %1),ng)[no_precomp] ]
--[ TraceStep(pid,r,'I_S2_classic_recovery_candidate',%s), Cur(pid,r,ck),
    EUse(pid,r,(%e %+ %1)), ResumeFinish(pid,r,(%s %+ %1)), Retire(pid,r,ck),
    Advance(pid,r,%e,(%e %+ %1)),
    CandidateBefore(pid,r,old,ck), Retire(pid,r,old),
    ErasedBranch(pid,r,old), ErasedBranch(pid,r,ck),
    I_Commit(pid,r,p,x,'none',ki,kr),
    I_Advance(pid,r,ck,ck1,(%e %+ %1),(%e %+ %1)),
    DerivedCK(pid,ck,ck1), CK(pid,ck1), KeyDeclared(pid,r,ki,kr),
    EncryptedOutput('data',ki), Candidates(pid,r,ck1,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck1,'none'),
    !SKValue(pid,r,ki,kr), !CKValue(pid,ck1),
    !St(pid,r,ck1,(%e %+ %1),ng), !Index(pid,r,(%e %+ %1),ng),
    !Session(pid,r,ck1,(%e %+ %1),ng,ki,kr), Out(senc('data',ki)) ]

rule I_S2_mix:
  let pq = <ss,h(ek),h(ct)>
      ng = flip(g)
      m = <'S1','1',kdf(ck,<'id',r>,pid),x>
      th = h(<m,y>)
      prk = ext(ck,<x,y,pq>)
      ki = kdf(prk,'skI',<pid,th>)
      kr = kdf(prk,'skR',<pid,th>)
      ck1 = kdf(prk,'ratchet',<pid,th>)
  in
  [ BusySlot(pid,r,%s)[no_precomp], IWait(pid,r,p,ck,%e,g,(%e %+ %1),ng,x,'1',pq,ss,ek,ct,%s)[no_precomp], CandidateState(pid,r,a,b)[no_precomp],
    In(<y,mac(kdf(ck,'authR',pid),<'S2',th>)>), !CKValue(pid,ck)[no_precomp],
    !PositionValue(pid,%e,g)[no_precomp], !Party(pid,g,ng)[no_precomp] ]
--[ TraceStep(pid,r,'I_S2_mix',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeFinish(pid,r,(%s %+ %1)), Retire(pid,r,ck), Advance(pid,r,%e,(%e %+ %1)),
    CandidateBefore(pid,r,a,b), Retire(pid,r,a), Retire(pid,r,b), ErasedBranch(pid,r,a), ErasedBranch(pid,r,b),
    I_Commit(pid,r,p,x,pq,ki,kr), I_Advance(pid,r,ck,ck1,%e,(%e %+ %1)),
    DerivedCK(pid,ck,ck1), MixedKey(pid,%e,ss,ek,ct,ck1), CK(pid,ck1),
    KeyDeclared(pid,r,ki,kr), Position(pid,(%e %+ %1),ng), EncryptedOutput('data',ki),
    Candidates(pid,r,ck1,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck1,'none'), !PositionValue(pid,(%e %+ %1),ng), !SKValue(pid,r,ki,kr), !CKValue(pid,ck1), !St(pid,r,ck1,(%e %+ %1),ng), !Index(pid,r,(%e %+ %1),ng),     !Session(pid,r,ck1,(%e %+ %1),ng,ki,kr), Out(senc('data',ki)) ]

rule R_Data_same_epoch:
  [ BusySlot(pid,r,%s)[no_precomp], RPending(pid,r,p,ck,ck1,%e,g,pq,ki,kr,%s)[no_precomp], CandidateState(pid,r,a,b)[no_precomp],
    !Index(pid,r,%e,g)[no_precomp], In(senc('data',ki)), !CKValue(pid,ck)[no_precomp] ]
--[ TraceStep(pid,r,'R_Data_same_epoch',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeFinish(pid,r,(%s %+ %1)), Retire(pid,r,ck),
    CandidateBefore(pid,r,a,b), Retire(pid,r,a), Retire(pid,r,b), ErasedBranch(pid,r,a), ErasedBranch(pid,r,b),
    R_Confirm(pid,r,p,pq,ki,kr), ConfirmedCK(pid,r,ck1,%e), Candidates(pid,r,ck1,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck1,'none'), !St(pid,r,ck1,%e,g), !Session(pid,r,ck1,%e,g,kr,ki) ]

/* Covers both the first mixed DATA and a recovery Resume on its already-mixed candidate. */
rule R_Data_advance_epoch:
  let ng = flip(g)
  in
  [ BusySlot(pid,r,%s)[no_precomp], RPending(pid,r,p,ck,ck1,(%e %+ %1),ng,pq,ki,kr,%s)[no_precomp], CandidateState(pid,r,a,b)[no_precomp],
    !Index(pid,r,%e,g)[no_precomp],
    !Party(pid,g,ng)[no_precomp], In(senc('data',ki)), !CKValue(pid,ck)[no_precomp],
    !PositionValue(pid,%e,g)[no_precomp] ]
--[ TraceStep(pid,r,'R_Data_advance_epoch',%s),  Cur(pid,r,ck), EUse(pid,r,%e), ResumeFinish(pid,r,(%s %+ %1)), Retire(pid,r,ck), Advance(pid,r,%e,(%e %+ %1)),
    CandidateBefore(pid,r,a,b), Retire(pid,r,a), Retire(pid,r,b), ErasedBranch(pid,r,a), ErasedBranch(pid,r,b),
    R_Confirm(pid,r,p,pq,ki,kr), ConfirmedCK(pid,r,ck1,(%e %+ %1)),
    Position(pid,(%e %+ %1),ng), Candidates(pid,r,ck1,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck1,'none'), !PositionValue(pid,(%e %+ %1),ng), !St(pid,r,ck1,(%e %+ %1),ng), !Index(pid,r,(%e %+ %1),ng),
    !Session(pid,r,ck1,(%e %+ %1),ng,kr,ki) ]

/* Recovery from a candidate CK that already incorporated the pending epoch.
 * The peer's committed Index may lag that candidate position by one; a valid
 * DATA confirmation selects the new CK at its existing position, without
 * another candidate-epoch increment or MIX. Advance commits the lagging
 * local Index frontier. */
/* Non-recovery witness profiles omit this rule to avoid irrelevant branches. */
#ifdef EXECUTION_NONRECOVERY
#else
rule R_Data_recovery_candidate:
  let ng = flip(oldg)
  in
  [ BusySlot(pid,r,%s)[no_precomp], RPending(pid,r,p,ck,ck1,(%e %+ %1),ng,pq,ki,kr,%s)[no_precomp],
    CandidateState(pid,r,old,ck)[no_precomp], !Index(pid,r,%e,oldg)[no_precomp],
    !Party(pid,oldg,ng)[no_precomp], In(senc('data',ki)), !CKValue(pid,ck)[no_precomp],
    !PositionValue(pid,(%e %+ %1),ng)[no_precomp] ]
--[ TraceStep(pid,r,'R_Data_recovery_candidate',%s), Cur(pid,r,ck), EUse(pid,r,(%e %+ %1)),
    ResumeFinish(pid,r,(%s %+ %1)), Retire(pid,r,ck), CandidateBefore(pid,r,old,ck),
    Retire(pid,r,old), ErasedBranch(pid,r,ck), ErasedBranch(pid,r,old),
    Advance(pid,r,%e,(%e %+ %1)),
    R_Confirm(pid,r,p,pq,ki,kr), ConfirmedCK(pid,r,ck1,(%e %+ %1)),
    Position(pid,(%e %+ %1),ng),
    Candidates(pid,r,ck1,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck1,'none'),
    !St(pid,r,ck1,(%e %+ %1),ng), !Index(pid,r,(%e %+ %1),ng),
    !Session(pid,r,ck1,(%e %+ %1),ng,kr,ki) ]
#endif

 #ifdef EXECUTION_NONRECOVERY
 #else
rule R_Timeout:
  [ BusySlot(pid,r,%s)[no_precomp], RPending(pid,r,p,ck,ck1,%e,g,pq,ki,kr,%s)[no_precomp], CandidateState(pid,r,ck,other)[no_precomp],
    !CKValue(pid,ck)[no_precomp] ]
--[ TraceStep(pid,r,'R_Timeout',%s),  Cur(pid,r,ck), ResumeFinish(pid,r,(%s %+ %1)), Timeout(pid,r,ck1,%e),
    CandidateBefore(pid,r,ck,other), Retire(pid,r,other), ErasedBranch(pid,r,other), Candidates(pid,r,ck,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck,ck1), !St(pid,r,ck1,%e,g) ]
#endif

rule R_Timeout_recovery_candidate:
  [ BusySlot(pid,r,%s)[no_precomp], RPending(pid,r,p,ck,ck1,%e,g,pq,ki,kr,%s)[no_precomp], CandidateState(pid,r,other,ck)[no_precomp],
    !CKValue(pid,ck)[no_precomp] ]
--[ TraceStep(pid,r,'R_Timeout_recovery_candidate',%s),  Cur(pid,r,ck), ResumeFinish(pid,r,(%s %+ %1)), Timeout(pid,r,ck1,%e),
    CandidateBefore(pid,r,other,ck), Retire(pid,r,other), ErasedBranch(pid,r,other), Candidates(pid,r,ck,ck1) ]->
  [ FinishPermit(pid,r,(%s %+ %1)), CandidateState(pid,r,ck,ck1), !St(pid,r,ck1,%e,g) ]

/* Cancellation drops only the attempt; durable pending epoch material survives retries. */
rule I_Timeout:
  [ BusySlot(pid,r,%s)[no_precomp], IWait(pid,r,p,ck,%e,g,%n,ng,x,mode,pq,ss,ek,ct,%s)[no_precomp] ]
--[ TraceStep(pid,r,'I_Timeout',%s),  ResumeFinish(pid,r,(%s %+ %1)), I_Abort(pid,r,'timeout') ]-> [ FinishPermit(pid,r,(%s %+ %1)) ]

/* Role A ignores collisions; role B yields only after authenticating role A's S1. */
rule B_Collision_Yield:
  let m = <'S1',mode,kdf(ck,<'id',roleA>,pid),x>
  in
  [ BusySlot(pid,roleB,%s)[no_precomp], IWait(pid,roleB,roleA,own,%e,g,%n,ng,nonce,ownmode,pq,ss,ek,ct,%s)[no_precomp],
    !St(pid,roleB,ck,%f,h)[no_precomp], !CKValue(pid,ck)[no_precomp],
    In(<m,mac(kdf(ck,<'authI',roleA>,pid),m)>) ]
--[ TraceStep(pid,roleB,'B_Collision_Yield',%s),  Cur(pid,roleB,ck), EUse(pid,roleB,%f), CollisionMode(mode),
    ResumeFinish(pid,roleB,(%s %+ %1)), I_Abort(pid,roleB,'collision') ]-> [ FinishPermit(pid,roleB,(%s %+ %1)) ]
