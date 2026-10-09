tactic: key_birth
presort: C
prio:
  regex "splitEqs|DerivedCK[(]|Init[(]"
prio:
  regex "~~>"
prio:
  regex "CKValue[(]"
prio:
  regex "last"

tactic: key_origin
presort: I
prio:
  regex "last|splitEqs|DerivedCK[(]|Init[(]|KeyDeclared[(]|CK[(]"
prio:
  regex "KU[(]|RevCK"
prio:
  regex "CKValue[(]"

tactic: authenticated_transfer
presort: I
prio:
  regex "splitEqs|RevCK[(]"
prio:
  regex "SKValue[(]"
prio:
  regex "EncryptedOutput|KeyDeclared[(]"
prio:
  regex "Party[(]"
prio:
  regex "GenKey[(]|EncWait[(]|CompleteEK[(]|CompleteCT[(]|EK0[(]|CT0[(]"

tactic: durable_ack
presort: I
prio:
  regex "^Ack[(]|^KeyDeclared[(]"
prio:
  regex "^EncryptedOutput[(]|^[(].*(RevCK[(]|EncryptedOutput[(])"
prio:
  regex "^!KU[(].*senc|~~>"
prio:
  regex "^!SKValue[(]"

tactic: storage_origin
presort: I
prio:
  regex "^EncryptedOutput[(]"
prio:
  regex "^!EK0[(]|^!CT0[(]|^!CompleteEK[(]|^!CompleteCT[(]"
prio:
  regex "^SessionUse[(]|^!SKValue[(]|^KeyDeclared[(]"

tactic: committed_position
presort: I
prio:
  regex "^!Index[(]"
prio:
  regex "^!Party[(]|^!PositionValue[(]"

tactic: serialization
presort: I
prio:
  regex "splitEqs|^[(][[:space:]]*last"
prio:
  regex "^ResumeStart[(]|^I_Start[(]|^Cur[(]"
prio:
  regex "^StartPermit[(]|^ResumeSlot[(]|^FinishPermit[(]|^BusySlot[(]"
prio:
  regex "^ResumeFinish[(]|^LockStage[(]"

tactic: initial_lock
presort: I
prio: {smallest}
  regex "last|splitEqs|[(]#|[(]%"
prio:
  regex "Init[(]"
prio:
  regex "I_Start[(]|Party[(]"
prio:
  regex "Cur[(]"
prio:
  regex "ResumeSlot[(]|BusySlot[(]|StartPermit[(]|FinishPermit[(]|ActiveAttempt[(]"

tactic: lifecycle
presort: I
prio: {smallest}
  regex "last|splitEqs|[(]#|[(]%"
prio:
  regex "LockStage[(]|ResumeStart[(]|I_Start[(]"
prio:
  regex "ResumeSlot[(]|BusySlot[(]|StartPermit[(]|FinishPermit[(]"
prio:
  regex "ActiveAttempt[(]|ResumeStart[(]|I_Start[(]"
prio:
  regex "IWait[(]|RPending[(]"
prio:
  regex "Init[(]|Candidates[(]"
prio:
  regex "~~>"

tactic: positions
presort: I
prio:
  regex "splitEqs|^[(][[:space:]]*last"
prio:
  regex "^Position[(]"
prio:
  regex "^!Party[(]"
prio:
  regex "^!PositionValue[(]"
tactic: authentication
presort: I
prio:
  regex "~~>"
prio:
  regex "DKOwner[(]|SSValue[(]|EncMaterial[(]|DKMaterial[(]"
prio:
  regex "Party[(]"
prio:
  regex "SKValue[(]"
prio:
  regex "EncryptedOutput[(]|last|splitEqs|RevCK[(]"
prio:
  regex "CT0[(]|EK0[(]|CompleteEK[(]|CompleteCT[(]"
prio:
  regex "EncWait[(]"
prio:
  regex "GenKey[(]"

tactic: agreement
presort: I
prio:
  regex "last|splitEqs|RevCK[(]"
prio:
  regex "EpochHave[(]|EpGen[(]|EpEnc[(]"
prio:
  regex "DKMaterial[(]|EncMaterial[(]"
prio:
  regex "Party[(]"
prio:
  regex "GenKey[(]|CompleteEK[(]|EK0[(]|CT0[(]"

tactic: honest_trace
presort: I
prio:
  regex "^Init[(]|splitEqs"
prio:
  regex "^I_Advance[(]|^I_Commit[(]|^ConfirmedCK[(]|^EpGen[(]|^EpEnc[(]|^EpDec[(]|^MixedKey[(]|^Timeout[(]"
prio:
  regex "^!Party[(]|^!Index[(]|^!PositionValue[(]"
prio:
  regex "^IWait[(]|^RPending[(]|^CandidateState[(]|^!Session[(]|^!St[(]|^!SKValue[(]"
prio:
  regex "^StartPermit[(]|^ResumeSlot[(]|^FinishPermit[(]|^BusySlot[(]"
prio:
  regex "^!Have[(]|^!ReadyEpoch[(]|^!CompleteEK[(]|^!CompleteCT[(]|^!EK0[(]|^!CT0[(]|^!GenKey[(]|^!Progress[(]|^!EncWait[(]|^!SentTail[(]"
prio:
  regex "^DKMaterial[(]|^EncMaterial[(]|^!CKValue[(]|~~>"

tactic: witness
presort: I
prio:
  regex "~~>"
prio:
  regex "last|splitEqs|RevCK[(]"
prio:
  regex "Init[(]"
prio:
  regex "I_Commit[(]|MixedKey[(]"
prio:
  regex "IWait[(]|RPending[(]"
prio:
  regex "DKMaterial[(]|EncMaterial[(]|DKOwner[(]|SSValue[(]"
prio:
  regex "I_Advance[(]|ConfirmedCK[(]|EpGen[(]|EpEnc[(]|EpDec[(]|Timeout[(]|Cur[(]|EKPrefix[(]|CTPrefix[(]|Ack[(]|Sent[(]|ReceivedFull[(]|ResumeFinish[(]|CandidateBefore[(]|SessionUse[(]"
prio:
  regex "EncryptedOutput[(]"
prio:
  regex "Party[(]"
prio:
  regex "BusySlot[(]|ResumeSlot[(]|StartPermit[(]|FinishPermit[(]|ActiveAttempt[(]|CandidateState[(]|IWait[(]|RPending[(]"
prio:
  regex "Session[(].*'ratchet'"
prio:
  regex "Index[(]"
prio:
  regex "KU[(].*(senc|mac|kdf)"
prio:
  regex "GenKey[(]|EncWait[(]|CompleteEK[(]|CompleteCT[(]|EK0[(]|CT0[(]|Progress[(]|ReadyEpoch[(]|Have[(]|SentTail[(]"
prio:
  regex "St[(]|Session[(]"
prio:
  regex "SKValue[(]|CKValue[(]"
