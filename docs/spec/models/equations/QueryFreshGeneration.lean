import QuerySortedGeneration

namespace Cairn.Equations

private theorem native_zip_retag_fresh (forbidden : List Nat) (basis keys : List NativeVariableKey)
    (choices : List QuerySort) (length : choices.length = keys.length) (member : target ∈ keys) :
    ∀ residual ∈ nativeQueryVariables (nativeBindingAssignment
      ((keys.zip choices).map (fun (key, chosen) =>
        (key, .queryVariable chosen (naturalResidualIndex forbidden basis key)))) target.1 target.2),
      residual.2 ∉ forbidden := by
  induction keys generalizing choices with
  | nil => simp at member
  | cons first rest induction =>
    cases choices with
    | nil => simp at length
    | cons chosen choices =>
      change ∀ residual ∈ nativeQueryVariables (if first = target then
        .queryVariable chosen (naturalResidualIndex forbidden basis first)
        else nativeBindingAssignment ((rest.zip choices).map (fun (key, tag) =>
          (key, .queryVariable tag (naturalResidualIndex forbidden basis key)))) target.1 target.2),
        residual.2 ∉ forbidden
      split
      · intro residual occurs collision
        have same : residual = (chosen, naturalResidualIndex forbidden basis first) := by
          simpa only [nativeQueryVariables, List.mem_singleton] using occurs
        subst residual
        exact (natural_residual_index_fresh forbidden basis first collision) rfl
      · rename_i different
        have included : target ∈ rest := by
          rcases List.mem_cons.mp member with same | included
          · exact (different same.symm).elim
          · exact included
        exact induction choices (by simpa using length) included

theorem native_residual_retag_fresh (length : choices.length = keys.length) (member : target ∈ keys)
    (occurs : residual ∈ nativeQueryVariables (nativeResidualRetag forbidden keys choices
      target.1 target.2)) : residual.2 ∉ forbidden :=
  native_zip_retag_fresh forbidden keys keys choices length member residual occurs

theorem native_substitution_residual_fresh {forbidden : List Nat}
    {assignment : QuerySort → Nat → NativeQueryTerm} (term : NativeQueryTerm)
    (fresh : ∀ source ∈ nativeQueryVariables term,
      ∀ residual ∈ nativeQueryVariables (assignment source.1 source.2), residual.2 ∉ forbidden) :
    ∀ residual ∈ nativeQueryVariables (substituteNativeQuery assignment term),
      residual.2 ∉ forbidden := by
  induction term with
  | queryVariable sort index => exact fresh (sort, index) (by simp [nativeQueryVariables])
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    simp [substituteNativeQuery, nativeQueryVariables]
  | naturalAdd _ _ left right | binary _ _ _ left right | cons _ _ left right =>
    intro residual occurs
    simp only [substituteNativeQuery, nativeQueryVariables, List.mem_append] at occurs
    rcases occurs with occurs | occurs
    · exact left (fun source included => fresh source (List.mem_append_left _ included)) residual occurs
    · exact right (fun source included => fresh source (List.mem_append_right _ included)) residual occurs
  | unary _ _ child | list _ child => exact child fresh
  | kdf _ _ _ first second third =>
    intro residual occurs
    simp only [substituteNativeQuery, nativeQueryVariables, List.mem_append] at occurs
    rcases occurs with (occurs | occurs) | occurs
    · exact first (fun source included =>
        fresh source (List.mem_append_left _ (List.mem_append_left _ included))) residual occurs
    · exact second (fun source included =>
        fresh source (List.mem_append_left _ (List.mem_append_right _ included))) residual occurs
    · exact third (fun source included =>
        fresh source (List.mem_append_right _ included)) residual occurs

theorem native_retag_candidate_fresh
    (length : choices.length = (nativeResidualKeys scope (nativeBindingAssignment raw)).length)
    (member : binding ∈ nativeRetagCandidate scope raw choices)
    (occurs : residual ∈ nativeQueryVariables binding.2) : residual.2 ∉ scope.map Prod.snd := by
  obtain ⟨key, included, rfl⟩ := List.mem_map.mp member
  apply native_substitution_residual_fresh _ _ residual occurs
  intro source present
  exact fun child appears => native_residual_retag_fresh length
    (native_residual_keys_cover (assignment := nativeBindingAssignment raw) included present) appears

theorem native_sorted_binding_family_fresh
    (member : bindings ∈ nativeSortedBindingFamily scope raw) (included : binding ∈ bindings)
    (occurs : residual ∈ nativeQueryVariables binding.2) : residual.2 ∉ scope.map Prod.snd := by
  obtain ⟨original, _, retyped⟩ := List.mem_flatMap.mp member
  obtain ⟨mapped, _⟩ := List.mem_filter.mp retyped
  obtain ⟨choices, choicesMember, rfl⟩ := List.mem_map.mp mapped
  have length : choices.length =
      (nativeResidualKeys scope (nativeBindingAssignment original)).length := by
    simpa only [beq_iff_eq] using (List.mem_filter.mp choicesMember).2
  exact native_retag_candidate_fresh length included occurs

#print axioms native_residual_retag_fresh
#print axioms native_substitution_residual_fresh
#print axioms native_retag_candidate_fresh
#print axioms native_sorted_binding_family_fresh

end Cairn.Equations
