import NaturalSystemFamily

namespace Cairn.Equations

theorem natural_variable_indices_iff (columns : List NaturalColumn) (index : Nat) :
    index ∈ naturalSystemVariableIndices columns ↔ .queryVariable index ∈ columns := by
  induction columns with
  | nil => simp [naturalSystemVariableIndices]
  | cons column rest induction =>
    cases column <;> simp_all [naturalSystemVariableIndices]

theorem natural_rigid_columns_iff (columns : List NaturalColumn) (code : Nat) :
    (.rigidAtom code, code) ∈ naturalSystemRigidColumns columns ↔ .rigidAtom code ∈ columns := by
  constructor
  · exact natural_system_rigid_scope columns
  · intro member
    exact List.mem_filterMap.mpr ⟨.rigidAtom code, member, rfl⟩

private theorem template_rigid_even (term : NaturalTerm)
    (member : NaturalColumn.rigidAtom code ∈ naturalTemplateColumns term) : code % 2 = 0 := by
  induction term with
  | one =>
    have same : code = 0 := by simpa [naturalTemplateColumns] using member
    omega
  | «variable» label =>
    by_cases even : label % 2 = 0
    · simp [naturalTemplateColumns, even] at member
    · have same : code = label + 1 := by simpa [naturalTemplateColumns, even] using member
      omega
  | add left right first second =>
    rcases List.mem_append.mp member with occurs | occurs
    · exact first occurs
    · exact second occurs

theorem natural_system_rigid_codes_even (equations : NaturalEquationSystem) (code : Nat)
    (member : code ∈ (naturalSystemRigidColumns (naturalSystemColumns equations)).map Prod.snd) :
    code % 2 = 0 := by
  obtain ⟨binding, marked, rfl⟩ := List.mem_map.mp member
  obtain ⟨column, occurs, selected⟩ := List.mem_filterMap.mp marked
  cases column with
  | queryVariable => simp at selected
  | rigidAtom code =>
    simp only [Option.some.injEq] at selected
    subst binding
    obtain ⟨equation, _, occurs⟩ := List.mem_flatMap.mp (List.mem_eraseDups.mp occurs)
    rcases List.mem_append.mp occurs with occurs | occurs
    · exact template_rigid_even equation.1 occurs
    · exact template_rigid_even equation.2 occurs

theorem native_natural_variables_iff (term : NaturalTerm) (sort : QuerySort) (index : Nat) :
    (sort, index) ∈ nativeQueryVariables (encodeNativeNatural term) ↔
      sort = .natural ∧ .queryVariable index ∈ naturalTemplateColumns term := by
  induction term with
  | one => simp [encodeNativeNatural, nativeQueryVariables, naturalTemplateColumns]
  | «variable» label =>
    by_cases even : label % 2 = 0 <;>
      simp [encodeNativeNatural, nativeQueryVariables, naturalTemplateColumns, even]
  | add left right first second =>
    simp [encodeNativeNatural, nativeQueryVariables, naturalTemplateColumns,
      first, second, and_or_left]

theorem native_natural_system_scope (equations : NaturalEquationSystem) (sort : QuerySort)
    (index : Nat) :
    (sort, index) ∈ nativeSystemVariables (encodeNativeNaturalSystem equations) ↔
      sort = .natural ∧ index ∈ naturalSystemVariableIndices (naturalSystemColumns equations) := by
  constructor
  · intro member
    obtain ⟨encoded, selected, occurs⟩ := List.mem_flatMap.mp member
    obtain ⟨equation, equationMember, rfl⟩ := List.mem_map.mp selected
    rcases List.mem_append.mp occurs with occurs | occurs
    · obtain ⟨same, occurrence⟩ := (native_natural_variables_iff equation.1 sort index).mp occurs
      exact ⟨same, (natural_variable_indices_iff _ _).mpr
        (natural_system_columns_scope equations equation equationMember _
          (List.mem_append.mpr (.inl occurrence)))⟩
    · obtain ⟨same, occurrence⟩ := (native_natural_variables_iff equation.2 sort index).mp occurs
      exact ⟨same, (natural_variable_indices_iff _ _).mpr
        (natural_system_columns_scope equations equation equationMember _
          (List.mem_append.mpr (.inr occurrence)))⟩
  · rintro ⟨rfl, member⟩
    have occurs := (natural_variable_indices_iff _ _).mp member
    obtain ⟨equation, equationMember, occurs⟩ :=
      List.mem_flatMap.mp (List.mem_eraseDups.mp occurs)
    refine List.mem_flatMap.mpr ⟨(encodeNativeNatural equation.1, encodeNativeNatural equation.2),
      List.mem_map.mpr ⟨equation, equationMember, rfl⟩, ?_⟩
    rcases List.mem_append.mp occurs with occurs | occurs
    · exact List.mem_append.mpr (.inl ((native_natural_variables_iff _ _ _).mpr ⟨rfl, occurs⟩))
    · exact List.mem_append.mpr (.inr ((native_natural_variables_iff _ _ _).mpr ⟨rfl, occurs⟩))

theorem natural_system_scope_keys (equations : NaturalEquationSystem) (sort : QuerySort)
    (index : Nat) :
    (sort, index) ∈ nativeSystemVariables (encodeNativeNaturalSystem equations) ↔
      (sort, index) ∈
        (naturalSystemVariableIndices (naturalSystemColumns equations)).map
          (fun entry => (QuerySort.natural, entry)) := by
  rw [native_natural_system_scope]
  constructor
  · rintro ⟨rfl, member⟩
    exact List.mem_map.mpr ⟨index, member, rfl⟩
  · intro member
    obtain ⟨entry, occurs, equal⟩ := List.mem_map.mp member
    have indices : entry = index := congrArg Prod.snd equal
    exact ⟨(congrArg Prod.fst equal).symm, indices ▸ occurs⟩

#print axioms natural_variable_indices_iff
#print axioms natural_rigid_columns_iff
#print axioms natural_system_rigid_codes_even
#print axioms native_natural_variables_iff
#print axioms native_natural_system_scope
#print axioms natural_system_scope_keys

end Cairn.Equations
