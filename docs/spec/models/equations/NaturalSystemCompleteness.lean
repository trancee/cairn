import NaturalSystemRealization

namespace Cairn.Equations

theorem native_natural_system_rows_iff (equations : NaturalEquationSystem)
    (typed : QuerySubstitution) :
    NativeACSystemUnifier (encodeNativeNaturalSystem equations) (nativeQueryAssignment typed) ↔
      ∀ row ∈ naturalSystemRows equations, ∀ atom,
        integerWordSum row (integerWordTranspose (naturalSystemColumns equations)
          (naturalColumnValues typed) atom) = 0 := by
  rw [natural_system_rows_iff]
  constructor
  · intro solved equation member
    have native := solved.2 _ (List.mem_map.mpr ⟨equation, member, rfl⟩)
    rw [← native_natural_substitution, ← native_natural_substitution] at native
    exact native_natural_ac_reflection native
  · intro solved
    refine ⟨native_typed_assignment_sorted typed, ?_⟩
    intro encoded member
    obtain ⟨equation, original, rfl⟩ := List.mem_map.mp member
    rw [← native_natural_substitution, ← native_natural_substitution]
    exact native_natural_ac_preservation (solved equation original)

theorem native_natural_system_family_sound (equations : NaturalEquationSystem)
    (member : bindings ∈ nativeNaturalSystemBindingFamily equations) :
    NativeACSystemUnifier (encodeNativeNaturalSystem equations)
      (nativeBindingAssignment bindings) := by
  obtain ⟨candidate, included, decoded⟩ := List.mem_filterMap.mp member
  obtain ⟨typed, realized, realization, sorted, agree, codes⟩ :=
    natural_system_candidate_realization equations included
  have same : realized = bindings := Option.some.inj (realization.symm.trans decoded)
  subst realized
  have balanced := integer_rigid_word_family_map_sound _ _ _
    (natural_system_columns_unique equations) included
    (naturalSystemAtomCode (naturalSystemVariableIndices (naturalSystemColumns equations))
      (integerMatrixWordBasis (naturalSystemColumns equations) (naturalSystemRows equations)).eraseDups)
  have counts (atom : Nat) :
      integerWordTranspose (naturalSystemColumns equations) (naturalColumnValues typed) atom =
        integerWordTranspose (naturalSystemColumns equations)
          (fun column => (candidate column).map
            (naturalSystemAtomCode (naturalSystemVariableIndices (naturalSystemColumns equations))
              (integerMatrixWordBasis (naturalSystemColumns equations)
                (naturalSystemRows equations)).eraseDups)) atom := by
    apply congrArg List.flatten
    apply List.map_congr_left
    intro column occurs
    dsimp only
    rw [codes column occurs]
  have solved := (native_natural_system_rows_iff equations typed).mpr
    (fun row rowMember atom => by rw [counts atom]; exact balanced atom row rowMember)
  exact native_system_assignment_eq_on sorted
    (fun sort index occurs => (agree sort index occurs).symm) solved

theorem native_natural_system_family_complete (equations : NaturalEquationSystem) :
    NativeCompleteACSystemOn (encodeNativeNaturalSystem equations)
      (nativeSystemVariables (encodeNativeNaturalSystem equations))
      ((nativeNaturalSystemBindingFamily equations).map nativeBindingAssignment) := by
  constructor
  · intro candidate member
    obtain ⟨bindings, included, rfl⟩ := List.mem_map.mp member
    exact native_natural_system_family_sound equations included
  · intro solution solved
    obtain ⟨typedSolution, represented⟩ := native_sorted_assignment_representation solved.1
    have typedSolved : NativeACSystemUnifier (encodeNativeNaturalSystem equations)
        (nativeQueryAssignment typedSolution) := represented ▸ solved
    have balanced := (native_natural_system_rows_iff equations typedSolution).mp typedSolved
    obtain ⟨candidate, member, factor, nonempty, fixed, reconstruct⟩ :=
      integer_rigid_word_family_complete (naturalSystemColumns equations)
        (naturalSystemRows equations) (naturalSystemRigidColumns (naturalSystemColumns equations))
        (naturalColumnValues typedSolution) (natural_system_columns_unique equations) 0
        (fun column _ => natural_column_values_nonempty typedSolution column)
        (fun _ occurs => natural_system_rigid_scope _ occurs)
        (fun _ occurs => natural_system_rigid_values typedSolution _ occurs)
        (fun atom row rowMember => balanced row rowMember atom)
    obtain ⟨typedCandidate, bindings, decoded, _, agree, codes⟩ :=
      natural_system_candidate_realization equations member
    obtain ⟨typedFactor, realizes⟩ :=
      natural_system_factor_realization equations member factor nonempty fixed
    refine ⟨nativeBindingAssignment bindings,
      List.mem_map.mpr ⟨bindings, List.mem_filterMap.mpr ⟨candidate, member, decoded⟩, rfl⟩,
      nativeQueryAssignment typedFactor, native_typed_assignment_sorted typedFactor, ?_⟩
    intro sort index occurs
    have originalScope := occurs
    obtain ⟨rfl, indexMember⟩ := (native_natural_system_scope equations sort index).mp occurs
    have columnMember := (natural_variable_indices_iff _ _).mp indexMember
    unfold composeNativeAssignments
    rw [← represented, agree _ _ originalScope]
    change NativeQueryAC (encodeNativeNatural (typedSolution.naturals index))
      (substituteNativeQuery (nativeQueryAssignment typedFactor)
        (encodeNativeNatural (typedCandidate.naturals index)))
    rw [← native_natural_substitution]
    apply native_natural_ac_preservation
    apply natural_ac_atoms_iff.mpr
    rw [realizes (.queryVariable index) (typedCandidate.naturals index)
      (codes (.queryVariable index) columnMember)]
    exact reconstruct (.queryVariable index) columnMember

#print axioms native_natural_system_rows_iff
#print axioms native_natural_system_family_sound
#print axioms native_natural_system_family_complete

end Cairn.Equations
