import QueryVariableBindings

namespace Cairn.Equations

-- The proof-carrying input excludes incompatible orientations, not their solutions.
def nativeVariableBindingFamily (sort : QuerySort) (index : Nat)
    (value : {term : NativeQueryTerm // NativeSortedValue sort term}) :
    List (List ((QuerySort × Nat) × NativeQueryTerm)) :=
  if (sort, index) ∈ nativeQueryVariables value.val then
    match value.val with
    | .queryVariable _ _ => [[]]
    | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .naturalOne | .roleA | .roleB | .nil
    | .naturalAdd _ _ | .unary _ _ | .binary _ _ _ | .kdf _ _ _ | .list _ | .cons _ _ => []
  else [[((sort, index), value.val)]]

theorem native_reflexive_complete_family (term : NativeQueryTerm) :
    NativeCompleteACUnifiers term term [NativeQueryTerm.queryVariable] := by
  apply native_singleton_complete_iff.mpr
  refine ⟨⟨native_identity_assignment_sorted, .reflexive⟩, ?_⟩
  intro solution solved
  refine ⟨solution, solved.1, ?_⟩
  intro sort index _
  exact .reflexive

theorem native_variable_binding_family_complete (sort : QuerySort) (index : Nat)
    (value : {term : NativeQueryTerm // NativeSortedValue sort term}) :
    NativeCompleteACUnifiers (.queryVariable sort index) value.val
      ((nativeVariableBindingFamily sort index value).map nativeBindingAssignment) := by
  obtain ⟨term, sorted⟩ := value
  by_cases occurs : (sort, index) ∈ nativeQueryVariables term
  · cases term with
    | queryVariable otherSort otherIndex =>
      simp only [nativeQueryVariables, List.mem_singleton, Prod.mk.injEq] at occurs
      obtain ⟨rfl, rfl⟩ := occurs
      simpa [nativeVariableBindingFamily, nativeQueryVariables, nativeBindingAssignment] using
        native_reflexive_complete_family (.queryVariable sort index)
    | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
      simp [nativeQueryVariables] at occurs
    | naturalAdd | unary | binary | kdf | list | cons =>
      simpa only [nativeVariableBindingFamily, occurs, ite_true, List.map_nil] using
        native_occurs_complete_empty_family occurs (by intro equal; cases equal)
  · simpa [nativeVariableBindingFamily, occurs] using
      native_single_binding_complete_family sorted occurs

theorem native_variable_binding_family_finite (sort : QuerySort) (index : Nat)
    (value : {term : NativeQueryTerm // NativeSortedValue sort term})
    (member : candidate ∈
      (nativeVariableBindingFamily sort index value).map nativeBindingAssignment) :
    NativeFiniteAssignment candidate := by
  obtain ⟨bindings, _, rfl⟩ := List.mem_map.mp member
  exact ⟨bindings, rfl⟩

#print axioms native_reflexive_complete_family
#print axioms native_variable_binding_family_complete
#print axioms native_variable_binding_family_finite

end Cairn.Equations
