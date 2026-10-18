import QuerySystemBindings

namespace Cairn.Equations

example (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn [] variables [NativeQueryTerm.queryVariable] :=
  native_system_empty_complete variables

example (term : NativeQueryTerm) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn [(term, term)] variables [NativeQueryTerm.queryVariable] :=
  native_system_reflexive_complete_iff.mpr (native_system_empty_complete variables)

example : nativeSystemVariables [
    (.queryVariable .publicAtom 0, .atom .publicAtom 0),
    (.queryVariable .freshAtom 0, .atom .freshAtom 0),
    (.queryVariable .message 0, .queryVariable .natural 0),
    (.queryVariable .node 0, .nodeAtom 0)] =
    [(.publicAtom, 0), (.freshAtom, 0), (.message, 0), (.natural, 0), (.node, 0)] := rfl

example : NativeCompleteACSystemOn [(.queryVariable .natural 0, .naturalOne)]
    [(.natural, 0)] [nativeBindingAssignment [((.natural, 0), .naturalOne)]] := by
  apply native_system_singleton_complete_iff.mpr
  exact native_single_binding_complete_family (.natural rfl) (by decide)

private def first := nativeBindingAssignment [((.message, 0), .roleA)]
private def invalid := nativeBindingAssignment [((.message, 0), .nodeAtom 0)]

private theorem invalid_unsorted : ¬ NativeSortedAssignment invalid := by
  intro sorted
  have value := native_single_binding_sorted_iff.mp sorted
  cases value with
  | message decoded => cases decoded

private theorem hidden_invalid : composeNativeAssignments first invalid = first := by
  funext sort index
  by_cases same : (.message, 0) = (sort, index)
  · obtain ⟨rfl, rfl⟩ := Prod.mk.inj same
    rfl
  · simp only [first, invalid, composeNativeAssignments, nativeBindingAssignment,
      same, ite_false, substituteNativeQuery]

-- Sorted composition cannot establish that its second assignment was sorted.
example : NativeACSystemUnifier [] (composeNativeAssignments first invalid) := by
  rw [hidden_invalid]
  exact ⟨native_single_binding_sorted_iff.mpr (.message rfl), by simp⟩

example : ¬ NativeACSystemUnifier (substituteNativeSystem first []) invalid :=
  fun solved => invalid_unsorted solved.1

private def inputVariable : NativeQueryTerm := .queryVariable .natural 0
private def residualVariable : NativeQueryTerm := .queryVariable .natural 7
private def variables : List (QuerySort × Nat) := [(.natural, 0), (.natural, 7)]
private def seed := nativeBindingAssignment [((.natural, 0), residualVariable)]
private def fixed := nativeBindingAssignment [((.natural, 7), .naturalOne)]
private def tooSpecific := composeNativeAssignments seed fixed
private def twice : NativeQueryTerm := .naturalAdd .naturalOne .naturalOne
private def specific := composeNativeAssignments
  (nativeBindingAssignment [((.natural, 0), twice)])
  (nativeBindingAssignment [((.natural, 7), twice)])

-- Empty residual equations do not make residual-variable coverage disposable.
example : NativeCompleteACSystemOn [] [] [fixed] := by
  constructor
  · intro candidate member
    have equal := List.mem_singleton.mp member
    subst candidate
    exact ⟨native_single_binding_sorted_iff.mpr (.natural rfl), by simp⟩
  · intro solution _
    refine ⟨fixed, by simp, NativeQueryTerm.queryVariable, native_identity_assignment_sorted, ?_⟩
    intro sort index member
    simp at member

example : NativeACSystemUnifier [(inputVariable, residualVariable)] tooSpecific := by
  apply native_system_cons_iff.mpr
  have solved := native_ac_unifier_composition
    (native_single_binding_unifier (sort := .natural) (index := 0)
      (value := residualVariable) (.natural rfl) (by decide))
    ((native_single_binding_sorted_iff (sort := .natural) (index := 7)
      (value := NativeQueryTerm.naturalOne)).mpr (.natural rfl))
  exact ⟨solved, solved.1, by simp⟩

example : ¬ NativeCompleteACSystemOn [(inputVariable, residualVariable)] variables [tooSpecific] := by
  intro complete
  have solved : NativeACSystemUnifier [(inputVariable, residualVariable)] specific := by
    refine ⟨native_sorted_composition
      (native_single_binding_sorted_iff.mpr (.natural rfl))
      (native_single_binding_sorted_iff.mpr (.natural rfl)), ?_⟩
    intro equation member
    have equal := List.mem_singleton.mp member
    subst equation
    exact .reflexive
  obtain ⟨candidate, member, factor, _, equivalent⟩ := complete.2 specific solved
  have equal := List.mem_singleton.mp member
  subst candidate
  have count := native_query_ac_preserves_count (equivalent .natural 0 (by simp [variables]))
  simp [specific, tooSpecific, seed, fixed, residualVariable, twice,
    nativeBindingAssignment, composeNativeAssignments, substituteNativeQuery,
    nativeQueryFunctionCount] at count

end Cairn.Equations
