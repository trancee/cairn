import QueryOccurs

namespace Cairn.Equations

theorem native_single_binding_sorted_iff :
    NativeSortedAssignment (nativeBindingAssignment [((sort, index), value)]) ↔
      NativeSortedValue sort value := by
  constructor
  · intro sorted
    simpa [nativeBindingAssignment] using sorted sort index
  · intro sorted otherSort otherIndex
    by_cases same : (sort, index) = (otherSort, otherIndex)
    · obtain ⟨rfl, rfl⟩ := Prod.mk.inj same
      simpa [nativeBindingAssignment] using sorted
    · simpa [nativeBindingAssignment, same] using
        native_identity_assignment_sorted otherSort otherIndex

theorem native_single_binding_finite (sort : QuerySort) (index : Nat)
    (value : NativeQueryTerm) :
    NativeFiniteAssignment (nativeBindingAssignment [((sort, index), value)]) :=
  ⟨[((sort, index), value)], rfl⟩

theorem native_single_binding_supported (sort : QuerySort) (index : Nat)
    (value : NativeQueryTerm) :
    NativeAssignmentSupportedOn [(sort, index)]
      (nativeBindingAssignment [((sort, index), value)]) :=
  native_bindings_supported [((sort, index), value)]

theorem native_single_binding_fixes_value
    (absent : (sort, index) ∉ nativeQueryVariables value) :
    substituteNativeQuery (nativeBindingAssignment [((sort, index), value)]) value = value := by
  calc
    _ = substituteNativeQuery NativeQueryTerm.queryVariable value := by
      apply native_substitution_eq_on
      intro otherSort otherIndex member
      have different : (sort, index) ≠ (otherSort, otherIndex) := by
        intro same
        exact absent (same ▸ member)
      simp [nativeBindingAssignment, different]
    _ = value := native_substitution_identity value

theorem native_single_binding_idempotent
    (absent : (sort, index) ∉ nativeQueryVariables value) :
    composeNativeAssignments (nativeBindingAssignment [((sort, index), value)])
      (nativeBindingAssignment [((sort, index), value)]) =
        nativeBindingAssignment [((sort, index), value)] := by
  funext otherSort otherIndex
  by_cases same : (sort, index) = (otherSort, otherIndex)
  · obtain ⟨rfl, rfl⟩ := Prod.mk.inj same
    simpa [composeNativeAssignments, nativeBindingAssignment] using
      native_single_binding_fixes_value absent
  · simp only [composeNativeAssignments, nativeBindingAssignment, same, ite_false,
      substituteNativeQuery]

theorem native_single_binding_unifier (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value) :
    NativeACUnifier (.queryVariable sort index) value
      (nativeBindingAssignment [((sort, index), value)]) := by
  refine ⟨native_single_binding_sorted_iff.mpr sorted, ?_⟩
  simp only [substituteNativeQuery]
  rw [show nativeBindingAssignment [((sort, index), value)] sort index = value by
    simp [nativeBindingAssignment], native_single_binding_fixes_value absent]
  exact .reflexive

theorem native_single_binding_factorization
    (solved : NativeACUnifier (.queryVariable sort index) value assignment) :
    NativeAssignmentAC assignment
      (composeNativeAssignments (nativeBindingAssignment [((sort, index), value)]) assignment) := by
  intro otherSort otherIndex
  by_cases same : (sort, index) = (otherSort, otherIndex)
  · obtain ⟨rfl, rfl⟩ := Prod.mk.inj same
    simpa [composeNativeAssignments, nativeBindingAssignment, substituteNativeQuery] using solved.2
  · simp only [composeNativeAssignments, nativeBindingAssignment, same, ite_false,
      substituteNativeQuery]
    exact .reflexive

theorem native_single_binding_most_general (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value) :
    NativeMostGeneralACUnifier (.queryVariable sort index) value
      (nativeBindingAssignment [((sort, index), value)]) := by
  refine ⟨native_single_binding_unifier sorted absent, ?_⟩
  intro solution solved
  refine ⟨solution, solved.1, ?_⟩
  intro otherSort otherIndex _
  exact native_single_binding_factorization solved otherSort otherIndex

theorem native_single_binding_complete_family (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value) :
    NativeCompleteACUnifiers (.queryVariable sort index) value
      [nativeBindingAssignment [((sort, index), value)]] :=
  native_singleton_complete_iff.mpr (native_single_binding_most_general sorted absent)

theorem native_single_binding_reversed_complete_family (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value) :
    NativeCompleteACUnifiers value (.queryVariable sort index)
      [nativeBindingAssignment [((sort, index), value)]] := by
  apply native_singleton_complete_iff.mpr
  have forward := native_single_binding_unifier sorted absent
  refine ⟨⟨forward.1, .symmetric forward.2⟩, ?_⟩
  intro solution solved
  refine ⟨solution, solved.1, ?_⟩
  intro otherSort otherIndex _
  exact native_single_binding_factorization ⟨solved.1, .symmetric solved.2⟩ otherSort otherIndex

#print axioms native_single_binding_sorted_iff
#print axioms native_single_binding_finite
#print axioms native_single_binding_supported
#print axioms native_single_binding_fixes_value
#print axioms native_single_binding_idempotent
#print axioms native_single_binding_unifier
#print axioms native_single_binding_factorization
#print axioms native_single_binding_most_general
#print axioms native_single_binding_complete_family
#print axioms native_single_binding_reversed_complete_family

end Cairn.Equations
