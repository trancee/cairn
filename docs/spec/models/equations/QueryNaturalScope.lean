import QueryRawPlans

namespace Cairn.Equations

theorem native_natural_candidate_rigid_scope
    (included : bindings ∈ nativeNaturalSystemBindingFamily equations)
    (scope : (QuerySort.natural, index) ∈ nativeSystemVariables (encodeNativeNaturalSystem equations))
    (occurs : marker ∈ nativeNaturalRigidIndices (nativeBindingAssignment bindings .natural index)) :
    NaturalColumn.rigidAtom (2 * marker + 2) ∈ naturalSystemColumns equations := by
  obtain ⟨candidate, candidateMember, decoded⟩ := List.mem_filterMap.mp included
  obtain ⟨typed, realized, realization, _, agree, codes⟩ :=
    natural_system_candidate_realization equations candidateMember
  have same : realized = bindings := Option.some.inj (realization.symm.trans decoded)
  subst realized
  rw [agree .natural index scope] at occurs
  have code := (native_natural_rigid_codes (typed.naturals index) marker).mp occurs
  have columnMember := (natural_variable_indices_iff _ _).mp
    ((native_natural_system_scope equations .natural index).mp scope).2
  rw [← naturalColumnValues, codes (.queryVariable index) columnMember] at code
  obtain ⟨name, member, equal⟩ := List.mem_map.mp code
  have supported := integer_rigid_word_family_name_scope _ _ _ candidateMember
    (.queryVariable index) name member
  cases name with
  | inl ground =>
    change ground = 2 * marker + 2 at equal
    subst ground
    obtain ⟨binding, rigidMember, value⟩ := List.mem_map.mp supported
    obtain ⟨column, columnOccurs, chosen⟩ := List.mem_filterMap.mp rigidMember
    cases column with
    | queryVariable => simp at chosen
    | rigidAtom code =>
      have same := Option.some.inj chosen
      subst binding
      simpa using value ▸ columnOccurs
  | inr residual =>
    simp only [naturalSystemAtomCode] at equal
    omega

theorem native_raw_class_scope (bounded : index < (nativeSystemSubterms equations).length) :
    (QuerySort.natural, index) ∈ nativeSystemVariables
      (encodeNativeNaturalSystem (nativeRawNaturalSystem equations label)) := by
  have member : (NaturalTerm.variable (2 * index), NaturalTerm.variable (2 * index)) ∈
      nativeRawNaturalSystem equations label :=
    List.mem_append.mpr (.inr (List.mem_map.mpr ⟨index, List.mem_range.mpr bounded, rfl⟩))
  refine List.mem_flatMap.mpr ⟨
    (encodeNativeNatural (.variable (2 * index)), encodeNativeNatural (.variable (2 * index))),
    List.mem_map.mpr ⟨_, member, rfl⟩, ?_⟩
  simp [encodeNativeNatural, nativeQueryVariables]

theorem native_raw_node_rigid_scope
    (compiled : nativeRawNodeEquation label term = some equation)
    (occurs : NaturalColumn.rigidAtom code ∈
      naturalTemplateColumns equation.1 ++ naturalTemplateColumns equation.2) :
    nativeRawRigidNode term = true ∧ code = 2 * label term + 2 := by
  cases term <;> simp only [nativeRawNodeEquation] at compiled
  all_goals cases compiled
  all_goals simp [naturalTemplateColumns] at occurs
  all_goals exact ⟨rfl, by omega⟩

theorem native_raw_auxiliary_rigid_scope
    (occurs : NaturalColumn.rigidAtom code ∈ naturalSystemColumns
      (nativeRawNaturalSystem equations label)) :
    ∃ term ∈ nativeSystemSubterms equations,
      nativeRawRigidNode term = true ∧ code = 2 * label term + 2 := by
  obtain ⟨equation, member, columnMember⟩ := List.mem_flatMap.mp (List.mem_eraseDups.mp occurs)
  rcases List.mem_append.mp member with compiled | identity
  · obtain ⟨term, included, selected⟩ := List.mem_filterMap.mp compiled
    exact ⟨term, included, native_raw_node_rigid_scope selected columnMember⟩
  · obtain ⟨index, _, rfl⟩ := List.mem_map.mp identity
    simp [naturalTemplateColumns] at columnMember

theorem native_raw_candidate_marker_scope
    (included : bindings ∈ nativeNaturalSystemBindingFamily (nativeRawNaturalSystem equations label))
    (bounded : index < (nativeSystemSubterms equations).length)
    (occurs : marker ∈ nativeNaturalRigidIndices (nativeBindingAssignment bindings .natural index)) :
    marker ∈ nativeRawMarkers (nativeSystemSubterms equations) label := by
  have scope := native_raw_class_scope (label := label) bounded
  have rigid := native_natural_candidate_rigid_scope included scope occurs
  obtain ⟨term, member, fixed, equal⟩ := native_raw_auxiliary_rigid_scope rigid
  have same : label term = marker := by omega
  exact List.mem_eraseDups.mpr (List.mem_map.mpr
    ⟨term, List.mem_filter.mpr ⟨member, fixed⟩, same⟩)

#print axioms native_natural_candidate_rigid_scope
#print axioms native_raw_class_scope
#print axioms native_raw_node_rigid_scope
#print axioms native_raw_auxiliary_rigid_scope
#print axioms native_raw_candidate_marker_scope

end Cairn.Equations
