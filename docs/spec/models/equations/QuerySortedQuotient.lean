import QuerySortedAC

namespace Cairn.Equations

theorem native_sorted_query_normal_ac_invariant (equivalent : NativeQueryAC left right)
    (normal : NativeSortedNormal left) : NativeSortedNormal right := by
  intro result step
  obtain ⟨_, copied, _⟩ := native_sorted_query_ac_coherent step (.symmetric equivalent)
  exact normal _ copied

theorem native_sorted_query_steps_ac_coherent (steps : NativeSortedSteps first count second)
    (equivalent : NativeQueryAC first third) :
    ∃ result, NativeSortedSteps third count result ∧ NativeQueryAC second result := by
  induction steps generalizing third with
  | reflexive => exact ⟨_, .reflexive, equivalent⟩
  | step rewrite _ induction =>
    obtain ⟨_, copied, middleAC⟩ := native_sorted_query_ac_coherent rewrite equivalent
    obtain ⟨_, rest, resultAC⟩ := induction middleAC
    exact ⟨_, .step copied rest, resultAC⟩

-- Keep guarded quotient paths separate from the unguarded shadow relation.
def NativeSortedModuloACRewrite (left right : NativeQueryTerm) : Prop :=
  ∃ before after, NativeQueryAC left before ∧ NativeSortedRewrite before after ∧
    NativeQueryAC after right

inductive NativeSortedModuloACSteps : NativeQueryTerm → Nat → NativeQueryTerm → Prop where
  | reflexive : NativeSortedModuloACSteps term 0 term
  | step : NativeSortedModuloACRewrite first second →
      NativeSortedModuloACSteps second count third →
      NativeSortedModuloACSteps first (count + 1) third

theorem native_sorted_modulo_ac_termination :
    WellFounded (fun right left : NativeQueryTerm => NativeSortedModuloACRewrite left right) := by
  apply Subrelation.wf (r := (measure nativeQueryFunctionCount).rel) _
    (measure nativeQueryFunctionCount).wf
  intro right left step
  obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := step
  have beforeCount := native_query_ac_preserves_count beforeAC
  have afterCount := native_query_ac_preserves_count afterAC
  have decreasing := native_sorted_rewrite_decreases_count rewrite
  change nativeQueryFunctionCount right < nativeQueryFunctionCount left
  omega

theorem native_sorted_modulo_ac_normal_iff (term : NativeQueryTerm) :
    (∀ result, ¬ NativeSortedModuloACRewrite term result) ↔ NativeSortedNormal term := by
  constructor
  · intro normal result step
    exact normal result ⟨_, _, .reflexive, step, .reflexive⟩
  · intro normal result step
    obtain ⟨_, _, beforeAC, rewrite, _⟩ := step
    obtain ⟨_, copied, _⟩ := native_sorted_query_ac_coherent rewrite (.symmetric beforeAC)
    exact normal _ copied

theorem native_sorted_modulo_ac_steps_matching
    (steps : NativeSortedModuloACSteps first count second) :
    ∃ result, NativeSortedSteps first count result ∧ NativeQueryAC result second := by
  induction steps with
  | reflexive => exact ⟨_, .reflexive, .reflexive⟩
  | step rewrite _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := rewrite
    obtain ⟨_, matching, middleAC⟩ :=
      native_sorted_query_ac_coherent rewrite (.symmetric beforeAC)
    obtain ⟨_, rest, targetAC⟩ := induction
    obtain ⟨_, copied, resultAC⟩ :=
      native_sorted_query_steps_ac_coherent rest
        (.transitive (.symmetric afterAC) middleAC)
    exact ⟨_, .step matching copied, .transitive (.symmetric resultAC) targetAC⟩

theorem native_sorted_modulo_ac_confluence
    (first : NativeSortedModuloACSteps term firstCount left)
    (second : NativeSortedModuloACSteps term secondCount right) :
    ∃ leftResult rightResult leftCount rightCount,
      NativeSortedSteps left leftCount leftResult ∧
      NativeSortedSteps right rightCount rightResult ∧ NativeQueryAC leftResult rightResult := by
  obtain ⟨_, firstSteps, firstAC⟩ := native_sorted_modulo_ac_steps_matching first
  obtain ⟨_, secondSteps, secondAC⟩ := native_sorted_modulo_ac_steps_matching second
  obtain ⟨_, leftCount, rightCount, firstJoin, secondJoin⟩ :=
    native_sorted_matching_confluence firstSteps secondSteps
  obtain ⟨_, leftJoin, leftAC⟩ := native_sorted_query_steps_ac_coherent firstJoin firstAC
  obtain ⟨_, rightJoin, rightAC⟩ := native_sorted_query_steps_ac_coherent secondJoin secondAC
  exact ⟨_, _, leftCount, rightCount, leftJoin, rightJoin,
    .transitive (.symmetric leftAC) rightAC⟩

private theorem normal_steps_identity (normal : NativeSortedNormal left)
    (steps : NativeSortedSteps left count right) : left = right := by
  cases steps with
  | reflexive => rfl
  | step rewrite _ => exact False.elim (normal _ rewrite)

theorem native_sorted_modulo_ac_normal_forms_unique
    (first : NativeSortedModuloACSteps term firstCount left)
    (second : NativeSortedModuloACSteps term secondCount right)
    (leftNormal : NativeSortedNormal left) (rightNormal : NativeSortedNormal right) :
    NativeQueryAC left right := by
  obtain ⟨_, _, _, _, leftJoin, rightJoin, equivalent⟩ :=
    native_sorted_modulo_ac_confluence first second
  rwa [← normal_steps_identity leftNormal leftJoin,
    ← normal_steps_identity rightNormal rightJoin] at equivalent

#print axioms native_sorted_query_normal_ac_invariant
#print axioms native_sorted_query_steps_ac_coherent
#print axioms native_sorted_modulo_ac_termination
#print axioms native_sorted_modulo_ac_normal_iff
#print axioms native_sorted_modulo_ac_steps_matching
#print axioms native_sorted_modulo_ac_confluence
#print axioms native_sorted_modulo_ac_normal_forms_unique

end Cairn.Equations
