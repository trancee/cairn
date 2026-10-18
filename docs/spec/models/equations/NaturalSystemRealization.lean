import NaturalBindings
import NaturalSystemScope
import NaturalAtomSubstitution
import IntegerRigidScope

namespace Cairn.Equations

theorem natural_system_candidate_realization (equations : NaturalEquationSystem)
    (member : candidate ∈ integerRigidWordFamily (naturalSystemColumns equations)
      (naturalSystemRows equations) (naturalSystemRigidColumns (naturalSystemColumns equations))) :
    ∃ typed : QuerySubstitution, ∃ bindings,
      naturalSystemCandidateBindings (naturalSystemVariableIndices (naturalSystemColumns equations))
        (integerMatrixWordBasis (naturalSystemColumns equations)
          (naturalSystemRows equations)).eraseDups candidate = some bindings ∧
      NativeSortedAssignment (nativeBindingAssignment bindings) ∧
      (∀ sort index, (sort, index) ∈ nativeSystemVariables (encodeNativeNaturalSystem equations) →
        nativeBindingAssignment bindings sort index = nativeQueryAssignment typed sort index) ∧
      ∀ column ∈ naturalSystemColumns equations, naturalColumnValues typed column =
        (candidate column).map
          (naturalSystemAtomCode (naturalSystemVariableIndices (naturalSystemColumns equations))
            (integerMatrixWordBasis (naturalSystemColumns equations)
              (naturalSystemRows equations)).eraseDups) := by
  have nonempty (index : Nat)
      (occurs : index ∈ naturalSystemVariableIndices (naturalSystemColumns equations)) :=
    integer_rigid_word_family_nonempty _ _ _ member (.queryVariable index)
      ((natural_variable_indices_iff _ _).mp occurs)
  obtain ⟨typed, bindings, decoded, represented, variables⟩ :=
    natural_bindings_realization _ _ _ nonempty
  refine ⟨typed, bindings, decoded, ?_, ?_, ?_⟩
  · rw [represented]
    exact native_restriction_sorted _ (native_typed_assignment_sorted typed)
  · intro sort index occurs
    rw [represented]
    exact ite_eq_left ((natural_system_scope_keys equations sort index).mp occurs)
  · intro column occurs
    cases column with
    | queryVariable index => exact variables index ((natural_variable_indices_iff _ _).mpr occurs)
    | rigidAtom code =>
      have fixed := integer_rigid_word_family_constants _ _ _ member (.rigidAtom code, code)
        ((natural_rigid_columns_iff _ _).mpr occurs)
      rw [fixed]
      rfl

theorem natural_system_factor_realization (equations : NaturalEquationSystem)
    (member : candidate ∈ integerRigidWordFamily (naturalSystemColumns equations)
      (naturalSystemRows equations) (naturalSystemRigidColumns (naturalSystemColumns equations)))
    (factor : Sum Nat (List NaturalColumn) → List Nat)
    (nonempty : ∀ name, factor name ≠ []) (fixed : ∀ code, factor (.inl code) = [code]) :
    ∃ typed : QuerySubstitution, ∀ column term,
      naturalAtomCodes term = (candidate column).map
        (naturalSystemAtomCode (naturalSystemVariableIndices (naturalSystemColumns equations))
          (integerMatrixWordBasis (naturalSystemColumns equations)
            (naturalSystemRows equations)).eraseDups) →
      naturalAtomCodes (substituteQueryNatural typed term) = (candidate column).flatMap factor := by
  obtain ⟨typed, realizes⟩ := natural_residual_factor_realization
    (naturalSystemVariableIndices (naturalSystemColumns equations))
    (integerMatrixWordBasis (naturalSystemColumns equations)
      (naturalSystemRows equations)).eraseDups factor nonempty
  refine ⟨typed, ?_⟩
  intro column term codes
  rw [natural_substitution_atom_codes, codes, List.flatMap_map, List.flatMap_def, List.flatMap_def]
  apply congrArg List.flatten
  apply List.map_congr_left
  intro name occurs
  have support := integer_rigid_word_family_name_scope _ _ _ member column name occurs
  cases name with
  | inl code =>
    rw [naturalSystemAtomCode, natural_atom_image_rigid typed code
      (natural_system_rigid_codes_even equations code support), fixed]
  | inr generator =>
    rw [naturalSystemAtomCode, natural_atom_image_variable, realizes generator support]

#print axioms natural_system_candidate_realization
#print axioms natural_system_factor_realization

end Cairn.Equations
