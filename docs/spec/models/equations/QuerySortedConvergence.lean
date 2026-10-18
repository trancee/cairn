import Convergence
import QuerySorted

namespace Cairn.Equations

inductive NativeSortedSteps : NativeQueryTerm → Nat → NativeQueryTerm → Prop where
  | reflexive : NativeSortedSteps term 0 term
  | step : NativeSortedRewrite first second → NativeSortedSteps second count third →
      NativeSortedSteps first (count + 1) third

def NativeSortedNormal (term : NativeQueryTerm) : Prop :=
  ∀ result, ¬ NativeSortedRewrite term result

theorem native_sorted_ac_coherent (step : NativeSortedRewrite first second)
    (decoded : decodeNativeMessage first = some message)
    (equivalent : NativeQueryAC first third) :
    ∃ result, NativeSortedRewrite third result ∧ NativeQueryAC second result := by
  obtain ⟨target, rewrite, targetDecoded⟩ := native_sorted_rewrite_decode step decoded
  obtain ⟨other, otherDecoded, otherAC⟩ := native_ac_message_image equivalent decoded
  obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := rewrite
  obtain ⟨result, matching, resultAC⟩ := modulo_ac_matching_coherence
    ⟨before, after, .transitive (.symmetric otherAC) beforeAC, rewrite, afterAC⟩
  refine ⟨encodeNativeMessage result, ?_, ?_⟩
  · rw [← native_message_recognition third otherDecoded]
    exact native_sorted_matching_preservation matching
  · rw [← native_message_recognition second targetDecoded]
    exact native_message_ac_preservation (.symmetric resultAC)

theorem native_sorted_steps_preservation (steps : MatchingSteps first count second) :
    NativeSortedSteps (encodeNativeMessage first) count (encodeNativeMessage second) := by
  induction steps with
  | reflexive => exact .reflexive
  | step rewrite _ induction =>
    exact .step (native_sorted_matching_preservation rewrite) induction

theorem native_sorted_steps_decode (steps : NativeSortedSteps first count second)
    (decoded : decodeNativeMessage first = some message) :
    ∃ result, ModuloACSteps message count result ∧ decodeNativeMessage second = some result := by
  induction steps generalizing message with
  | reflexive => exact ⟨_, .reflexive, decoded⟩
  | step rewrite _ induction =>
    obtain ⟨middle, sourceStep, middleDecoded⟩ := native_sorted_rewrite_decode rewrite decoded
    obtain ⟨result, sourceSteps, resultDecoded⟩ := induction middleDecoded
    exact ⟨result, .step sourceStep sourceSteps, resultDecoded⟩

theorem native_sorted_normal_iff (message : MessageTerm) :
    NativeSortedNormal (encodeNativeMessage message) ↔ Normal message := by
  constructor
  · intro normal result step
    exact normal _ (native_sorted_matching_preservation step)
  · intro normal result step
    obtain ⟨target, rewrite, _⟩ :=
      native_sorted_rewrite_decode step (native_message_round_trip message)
    obtain ⟨_, matching, _⟩ := modulo_ac_matching_coherence rewrite
    exact normal _ matching

theorem native_sorted_normal_ac_invariant (equivalent : NativeQueryAC left right)
    (decoded : decodeNativeMessage left = some message) (normal : NativeSortedNormal left) :
    NativeSortedNormal right := by
  obtain ⟨_, rightDecoded, _⟩ := native_ac_message_image equivalent decoded
  intro target step
  obtain ⟨_, copied, _⟩ := native_sorted_ac_coherent step rightDecoded (.symmetric equivalent)
  exact normal _ copied

theorem native_sorted_confluence (first : NativeSortedSteps term firstCount left)
    (second : NativeSortedSteps term secondCount right)
    (decoded : decodeNativeMessage term = some message) :
    ∃ leftResult rightResult leftCount rightCount,
      NativeSortedSteps left leftCount leftResult ∧
      NativeSortedSteps right rightCount rightResult ∧ NativeQueryAC leftResult rightResult := by
  obtain ⟨leftSource, firstSteps, leftDecoded⟩ := native_sorted_steps_decode first decoded
  obtain ⟨rightSource, secondSteps, rightDecoded⟩ := native_sorted_steps_decode second decoded
  obtain ⟨leftResult, rightResult, leftCount, rightCount, leftJoin, rightJoin, equivalent⟩ :=
    modulo_ac_confluence firstSteps secondSteps
  refine ⟨encodeNativeMessage leftResult, encodeNativeMessage rightResult, leftCount, rightCount,
    ?_, ?_, native_message_ac_preservation equivalent⟩
  · rw [← native_message_recognition left leftDecoded]
    exact native_sorted_steps_preservation leftJoin
  · rw [← native_message_recognition right rightDecoded]
    exact native_sorted_steps_preservation rightJoin

private theorem native_sorted_normal_steps_identity (normal : NativeSortedNormal left)
    (steps : NativeSortedSteps left count right) : left = right := by
  cases steps with
  | reflexive => rfl
  | step rewrite _ => exact False.elim (normal _ rewrite)

theorem native_sorted_normal_forms_unique (first : NativeSortedSteps term firstCount left)
    (second : NativeSortedSteps term secondCount right)
    (decoded : decodeNativeMessage term = some message)
    (leftNormal : NativeSortedNormal left) (rightNormal : NativeSortedNormal right) :
    NativeQueryAC left right := by
  obtain ⟨_, _, _, _, leftJoin, rightJoin, equivalent⟩ :=
    native_sorted_confluence first second decoded
  rwa [← native_sorted_normal_steps_identity leftNormal leftJoin,
    ← native_sorted_normal_steps_identity rightNormal rightJoin] at equivalent

theorem native_sorted_normalized_substitution_bound (template : MessageTemplate)
    (messageAssignment : Nat → MessageTerm) (naturalAssignment : Nat → NaturalTerm)
    (normalized : ∀ identifier, NativeSortedNormal (encodeNativeMessage (messageAssignment identifier))) :
    ∃ count result, count ≤ templateFunctionCount template ∧
      NativeSortedSteps
        (encodeNativeMessage (instantiateTemplate messageAssignment naturalAssignment template))
        count result ∧ NativeSortedNormal result := by
  obtain ⟨count, result, bound, steps, normal⟩ :=
    normalized_substitution_bound template messageAssignment naturalAssignment
      (fun identifier => (native_sorted_normal_iff _).1 (normalized identifier))
  exact ⟨count, encodeNativeMessage result, bound, native_sorted_steps_preservation steps,
    (native_sorted_normal_iff _).2 normal⟩

#print axioms native_sorted_ac_coherent
#print axioms native_sorted_steps_preservation
#print axioms native_sorted_steps_decode
#print axioms native_sorted_normal_iff
#print axioms native_sorted_normal_ac_invariant
#print axioms native_sorted_confluence
#print axioms native_sorted_normal_forms_unique
#print axioms native_sorted_normalized_substitution_bound

end Cairn.Equations
