import QueryResidualRealization

namespace Cairn.Equations

theorem native_raw_system_assignment_eq_on
    (equal : ∀ sort index, (sort, index) ∈ nativeSystemVariables equations →
      first sort index = second sort index)
    (solved : NativeRawACSystemUnifier equations first) :
    NativeRawACSystemUnifier equations second := by
  intro equation member
  have left := native_substitution_eq_on (term := equation.1)
    (fun sort index occurs => equal sort index
      (List.mem_flatMap.mpr ⟨equation, member, List.mem_append.mpr (.inl occurs)⟩))
  have right := native_substitution_eq_on (term := equation.2)
    (fun sort index occurs => equal sort index
      (List.mem_flatMap.mpr ⟨equation, member, List.mem_append.mpr (.inr occurs)⟩))
  rw [← left, ← right]
  exact solved equation member

theorem native_sorted_binding_family_sound (equations : NativeEquationSystem)
    (scope : List NativeVariableKey)
    (covers : ∀ key ∈ nativeSystemVariables equations, key ∈ scope)
    (sound : ∀ bindings ∈ raw, NativeRawACSystemUnifier equations (nativeBindingAssignment bindings))
    (member : bindings ∈ nativeSortedBindingFamily scope raw) :
    NativeACSystemUnifier equations (nativeBindingAssignment bindings) := by
  obtain ⟨original, originalMember, included⟩ := List.mem_flatMap.mp member
  obtain ⟨mapped, checked⟩ := List.mem_filter.mp included
  obtain ⟨choices, _, same⟩ := List.mem_map.mp mapped
  subst bindings
  let assignment := nativeBindingAssignment original
  let retag := nativeResidualRetag (scope.map Prod.snd) (nativeResidualKeys scope assignment) choices
  refine ⟨native_bindings_sorted_check checked, ?_⟩
  apply native_raw_system_assignment_eq_on
    (first := composeNativeAssignments assignment retag)
  · intro sort index occurs
    rw [native_retag_candidate_assignment]
    exact (ite_eq_left (covers (sort, index) occurs)).symm
  · intro equation included
    rw [← native_substitution_composition, ← native_substitution_composition]
    exact native_ac_substitution retag (sound original originalMember equation included)

theorem native_sorted_binding_family_complete (equations : NativeEquationSystem)
    (scope : List NativeVariableKey)
    (covers : ∀ key ∈ nativeSystemVariables equations, key ∈ scope)
    (complete : NativeRawCompleteACSystemOn equations scope raw) :
    NativeCompleteACSystemOn equations scope
      ((nativeSortedBindingFamily scope raw).map nativeBindingAssignment) := by
  constructor
  · intro candidate member
    obtain ⟨bindings, included, rfl⟩ := List.mem_map.mp member
    exact native_sorted_binding_family_sound equations scope covers complete.1 included
  · intro solution solved
    obtain ⟨original, originalMember, factor, factored⟩ := complete.2 solution solved.2
    have proper (sort index) (member : (sort, index) ∈ scope) :
        NativeSortedValue sort
          (substituteNativeQuery factor (nativeBindingAssignment original sort index)) :=
      (native_sorted_value_ac_iff (factored sort index member) sort).mp (solved.1 sort index)
    obtain ⟨bindings, included, postfactor, sorted, realizes⟩ :=
      native_residual_retyping_realization scope original factor proper
    refine ⟨nativeBindingAssignment bindings,
      List.mem_map.mpr ⟨bindings,
        List.mem_flatMap.mpr ⟨original, originalMember, included⟩, rfl⟩,
      postfactor, sorted, ?_⟩
    intro sort index member
    change NativeQueryAC (solution sort index)
      (substituteNativeQuery postfactor (nativeBindingAssignment bindings sort index))
    rw [realizes sort index member]
    exact factored sort index member

#print axioms native_raw_system_assignment_eq_on
#print axioms native_sorted_binding_family_sound
#print axioms native_sorted_binding_family_complete

end Cairn.Equations
