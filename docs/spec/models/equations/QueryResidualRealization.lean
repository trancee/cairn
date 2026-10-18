import QueryResidualRetyping

namespace Cairn.Equations

theorem native_residual_retyping_realization (scope : List NativeVariableKey)
    (raw : NativeBindingList) (factor : QuerySort → Nat → NativeQueryTerm)
    (proper : ∀ sort index, (sort, index) ∈ scope →
      NativeSortedValue sort
        (substituteNativeQuery factor (nativeBindingAssignment raw sort index))) :
    ∃ bindings ∈ nativeRetypedBindingFamily scope raw, ∃ postfactor,
      NativeSortedAssignment postfactor ∧
      ∀ sort index, (sort, index) ∈ scope →
        substituteNativeQuery postfactor (nativeBindingAssignment bindings sort index) =
          substituteNativeQuery factor (nativeBindingAssignment raw sort index) := by
  classical
  let assignment := nativeBindingAssignment raw
  let keys := nativeResidualKeys scope assignment
  let forbidden := scope.map Prod.snd
  have principalExists (key : NativeVariableKey) :
      ∃ chosen, key ∈ keys → nativePrincipalSort (factor key.1 key.2) = some chosen := by
    by_cases member : key ∈ keys
    · obtain ⟨source, sourceMember, occurs⟩ :=
        List.mem_flatMap.mp (List.mem_eraseDups.mp member)
      obtain ⟨required, value⟩ :=
        native_sorted_substitution_variable_proper (proper _ _ sourceMember) occurs
      obtain ⟨chosen, found, _⟩ := (native_principal_sort_iff _ required 0).mp value
      exact ⟨chosen, fun _ => found⟩
    · exact ⟨key.1, fun included => (member included).elim⟩
  let chosen := fun key => Classical.choose (principalExists key)
  have principal (key : NativeVariableKey) (member : key ∈ keys) :
      nativePrincipalSort (factor key.1 key.2) = some (chosen key) :=
    Classical.choose_spec (principalExists key) member
  let choices := keys.map chosen
  let retag := nativeResidualRetag forbidden keys choices
  have fingerprint (sort index expected) :
      NativeSortedValue expected (restrictNativeAssignment keys factor sort index) ↔
        NativeSortedValue expected (retag sort index) := by
    dsimp only [retag, choices]
    rw [native_residual_retag_functional]
    by_cases member : (sort, index) ∈ keys
    · simp only [restrictNativeAssignment, ite_eq_left member]
      constructor
      · intro value
        obtain ⟨actual, found, accepted⟩ :=
          (native_principal_sort_iff _ expected (naturalResidualIndex forbidden keys (sort, index))).mp value
        rw [principal (sort, index) member] at found
        cases found
        exact accepted
      · intro value
        exact (native_principal_sort_iff _ expected _).mpr
          ⟨chosen (sort, index), principal _ member, value⟩
    · simp only [restrictNativeAssignment, ite_eq_right member]
  have retypedProper (sort index) (member : (sort, index) ∈ scope) :
      NativeSortedValue sort (substituteNativeQuery retag (assignment sort index)) := by
    have contains : ∀ childSort childIndex,
        (childSort, childIndex) ∈ nativeQueryVariables (assignment sort index) →
          (childSort, childIndex) ∈ keys :=
      fun _ _ occurs => native_residual_keys_cover (assignment := assignment) member occurs
    have restricted : NativeSortedValue sort
        (substituteNativeQuery (restrictNativeAssignment keys factor) (assignment sort index)) := by
      rw [native_restriction_substitution contains]
      exact proper sort index member
    exact (native_unrestricted_sort_fingerprint_substitution fingerprint _ _).mp restricted
  have checked : nativeBindingsSortedCheck (nativeRetagCandidate scope raw choices) = true := by
    apply List.all_eq_true.mpr
    intro binding member
    obtain ⟨key, included, rfl⟩ := List.mem_map.mp member
    exact (native_sorted_value_check_iff _ _).mp (retypedProper key.1 key.2 included)
  have choicesMember :
      choices ∈ (integerBoundedWords nativeAllQuerySorts keys.length).filter
        (fun entries => entries.length == keys.length) := by
    apply List.mem_filter.mpr
    refine ⟨(integer_bounded_words_iff _ _ _).mpr ⟨by simp [choices], ?_⟩,
      by simp [choices]⟩
    intro sort _
    cases sort <;> simp [nativeAllQuerySorts]
  have familyMember :
      nativeRetagCandidate scope raw choices ∈ nativeRetypedBindingFamily scope raw :=
    List.mem_filter.mpr ⟨List.mem_map.mpr ⟨choices, choicesMember, rfl⟩, checked⟩
  let domain := fun key => (chosen key, naturalResidualIndex forbidden keys key)
  let postfactor := nativeBindingAssignment
    (keys.map (fun key => (domain key, factor key.1 key.2)))
  have factorSorted : NativeSortedAssignment postfactor := by
    apply native_bindings_sorted_of_values
    intro binding member
    obtain ⟨key, included, rfl⟩ := List.mem_map.mp member
    exact (native_principal_sort_iff _ (chosen key) 0).mpr
      ⟨chosen key, principal key included, native_identity_assignment_sorted _ _⟩
  have realizes (key : NativeVariableKey) (member : key ∈ keys) :
      postfactor (chosen key) (naturalResidualIndex forbidden keys key) = factor key.1 key.2 := by
    apply native_binding_lookup_map keys domain (fun key => factor key.1 key.2) (domain key)
    · exact ⟨key, member, rfl⟩
    · intro entry included equal
      have same := natural_residual_index_injective forbidden keys included member
        (congrArg Prod.snd equal)
      exact congrArg (fun key : NativeVariableKey => factor key.1 key.2) same
  refine ⟨nativeRetagCandidate scope raw choices, familyMember, postfactor, factorSorted, ?_⟩
  intro sort index member
  rw [native_retag_candidate_assignment]
  simp only [restrictNativeAssignment, ite_eq_left member]
  change substituteNativeQuery postfactor (substituteNativeQuery retag (assignment sort index)) = _
  rw [native_substitution_composition]
  apply native_substitution_eq_on
  intro childSort childIndex occurs
  have included := native_residual_keys_cover (assignment := assignment) member occurs
  change substituteNativeQuery postfactor (retag childSort childIndex) = _
  dsimp only [retag, choices]
  rw [native_residual_retag_functional]
  dsimp only [restrictNativeAssignment]
  rw [ite_eq_left included]
  exact realizes (childSort, childIndex) included

#print axioms native_residual_retyping_realization

end Cairn.Equations
