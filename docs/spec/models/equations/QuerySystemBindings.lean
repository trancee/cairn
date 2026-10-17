import QuerySystems

namespace Cairn.Equations

def composeNativeBindings (first second : List ((QuerySort × Nat) × NativeQueryTerm)) :
    List ((QuerySort × Nat) × NativeQueryTerm) :=
  first.map (fun binding =>
    (binding.1, substituteNativeQuery (nativeBindingAssignment second) binding.2)) ++ second

theorem native_bindings_composition (first second : List ((QuerySort × Nat) × NativeQueryTerm)) :
    nativeBindingAssignment (composeNativeBindings first second) =
      composeNativeAssignments (nativeBindingAssignment first) (nativeBindingAssignment second) := by
  induction first with
  | nil => rfl
  | cons binding rest induction =>
    obtain ⟨key, value⟩ := binding
    funext sort index
    by_cases same : key = (sort, index)
    · simp [composeNativeBindings, composeNativeAssignments, nativeBindingAssignment, same]
    · simpa [composeNativeBindings, composeNativeAssignments, nativeBindingAssignment, same] using
        congrFun (congrFun induction sort) index

theorem native_finite_assignment_composition
    (firstFinite : NativeFiniteAssignment first) (secondFinite : NativeFiniteAssignment second) :
    NativeFiniteAssignment (composeNativeAssignments first second) := by
  obtain ⟨firstBindings, rfl⟩ := firstFinite
  obtain ⟨secondBindings, rfl⟩ := secondFinite
  exact ⟨composeNativeBindings firstBindings secondBindings,
    native_bindings_composition firstBindings secondBindings⟩

theorem native_system_variable_elimination (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value)
    (complete : NativeCompleteACSystemOn
      (substituteNativeSystem (nativeBindingAssignment [((sort, index), value)]) equations)
      (nativeAssignmentVariables variables (nativeBindingAssignment [((sort, index), value)]))
      family) :
    NativeCompleteACSystemOn ((.queryVariable sort index, value) :: equations) variables
      (family.map (composeNativeAssignments (nativeBindingAssignment [((sort, index), value)]))) := by
  let binding := nativeBindingAssignment [((sort, index), value)]
  have bindingSorted : NativeSortedAssignment binding := native_single_binding_sorted_iff.mpr sorted
  constructor
  · intro candidate member
    obtain ⟨residual, residualMember, rfl⟩ := List.mem_map.mp member
    have solved := complete.1 residual residualMember
    exact native_system_cons_iff.mpr
      ⟨native_ac_unifier_composition (native_single_binding_unifier sorted absent) solved.1,
        (native_system_substitution_iff bindingSorted solved.1).mp solved⟩
  · intro solution solved
    obtain ⟨firstSolved, restSolved⟩ := native_system_cons_iff.mp solved
    have equivalent := native_single_binding_factorization firstSolved
    have composed := native_system_assignment_ac
      (native_sorted_composition bindingSorted solved.1) equivalent restSolved
    have reduced := (native_system_substitution_iff bindingSorted solved.1).mpr composed
    obtain ⟨candidate, member, factorization⟩ := complete.2 solution reduced
    obtain ⟨factor, factorSorted, agreement⟩ := native_ac_instance_prefix binding factorization
    refine ⟨_, List.mem_map.mpr ⟨candidate, member, rfl⟩, factor, factorSorted, ?_⟩
    intro otherSort otherIndex input
    exact .transitive (equivalent otherSort otherIndex) (agreement otherSort otherIndex input)

theorem native_system_reversed_variable_elimination (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value)
    (complete : NativeCompleteACSystemOn
      (substituteNativeSystem (nativeBindingAssignment [((sort, index), value)]) equations)
      (nativeAssignmentVariables variables (nativeBindingAssignment [((sort, index), value)]))
      family) :
    NativeCompleteACSystemOn ((value, .queryVariable sort index) :: equations) variables
      (family.map (composeNativeAssignments (nativeBindingAssignment [((sort, index), value)]))) :=
  native_system_swap_complete_iff.mp (native_system_variable_elimination sorted absent complete)

theorem native_system_single_binding_complete (sorted : NativeSortedValue sort value)
    (absent : (sort, index) ∉ nativeQueryVariables value)
    (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn [(.queryVariable sort index, value)] variables
      [nativeBindingAssignment [((sort, index), value)]] := by
  have complete := native_system_variable_elimination (equations := []) (variables := variables)
    sorted absent
    (native_system_empty_complete
      (nativeAssignmentVariables variables (nativeBindingAssignment [((sort, index), value)])))
  have identity : composeNativeAssignments (nativeBindingAssignment [((sort, index), value)])
      NativeQueryTerm.queryVariable = nativeBindingAssignment [((sort, index), value)] := by
    funext otherSort otherIndex
    exact native_substitution_identity _
  simpa only [List.map_cons, List.map_nil, identity] using complete

theorem native_system_occurs_complete_empty_family
    (member : (sort, index) ∈ nativeQueryVariables value)
    (proper : value ≠ .queryVariable sort index)
    (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn ((.queryVariable sort index, value) :: equations) variables [] := by
  refine ⟨by simp, ?_⟩
  intro solution solved
  exact (native_ac_unifier_occurs_check member proper (native_system_cons_iff.mp solved).1).elim

#print axioms native_bindings_composition
#print axioms native_finite_assignment_composition
#print axioms native_system_variable_elimination
#print axioms native_system_reversed_variable_elimination
#print axioms native_system_single_binding_complete
#print axioms native_system_occurs_complete_empty_family

end Cairn.Equations
