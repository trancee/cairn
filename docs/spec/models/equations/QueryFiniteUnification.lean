import QuerySupport

namespace Cairn.Equations

-- Postfactors act on candidate values, including residual variables absent from the input.
def nativeAssignmentVariables (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) : List (QuerySort × Nat) :=
  variables.flatMap (fun key => nativeQueryVariables (assignment key.1 key.2))

theorem native_ac_instance_finite_factor_iff :
    NativeACInstanceOn variables general specific ↔
      ∃ bindings,
        NativeSortedAssignment (nativeBindingAssignment bindings) ∧
        NativeAssignmentSupportedOn (nativeAssignmentVariables variables general)
          (nativeBindingAssignment bindings) ∧
        NativeAssignmentACOn variables specific
          (composeNativeAssignments general (nativeBindingAssignment bindings)) := by
  constructor
  · rintro ⟨factor, sorted, equivalent⟩
    let support := nativeAssignmentVariables variables general
    refine ⟨support.map (fun key => (key, factor key.1 key.2)), ?_⟩
    rw [native_bindings_restriction]
    refine ⟨native_restriction_sorted support sorted,
      native_restriction_supported support factor, ?_⟩
    intro sort index member
    have contains : ∀ childSort childIndex,
        (childSort, childIndex) ∈ nativeQueryVariables (general sort index) →
          (childSort, childIndex) ∈ support := by
      intro childSort childIndex occurs
      exact List.mem_flatMap.mpr ⟨(sort, index), member, occurs⟩
    unfold composeNativeAssignments
    rw [native_restriction_substitution contains]
    exact equivalent sort index member
  · rintro ⟨bindings, sorted, _, equivalent⟩
    exact ⟨nativeBindingAssignment bindings, sorted, equivalent⟩

theorem native_ac_instance_restriction_iff :
    NativeACInstanceOn variables (restrictNativeAssignment variables general) specific ↔
      NativeACInstanceOn variables general specific := by
  constructor <;> rintro ⟨factor, sorted, equivalent⟩ <;>
    refine ⟨factor, sorted, ?_⟩ <;> intro sort index member <;>
    simpa only [composeNativeAssignments, restrictNativeAssignment, ite_eq_left member] using
      equivalent sort index member

theorem native_ac_unifier_restriction_iff (sorted : NativeSortedAssignment assignment) :
    NativeACUnifier left right
      (restrictNativeAssignment (nativeQueryVariables left ++ nativeQueryVariables right)
        assignment) ↔ NativeACUnifier left right assignment := by
  unfold NativeACUnifier
  rw [native_restriction_substitution (fun _ _ member => List.mem_append_left _ member),
    native_restriction_substitution (fun _ _ member => List.mem_append_right _ member)]
  exact ⟨fun solved => ⟨sorted, solved.2⟩,
    fun solved => ⟨native_restriction_sorted _ sorted, solved.2⟩⟩

theorem native_ac_unifier_finite_representation
    (solved : NativeACUnifier left right assignment) :
    ∃ bindings,
      NativeACUnifier left right (nativeBindingAssignment bindings) ∧
      NativeAssignmentSupportedOn (nativeQueryVariables left ++ nativeQueryVariables right)
        (nativeBindingAssignment bindings) ∧
      ∀ sort index, (sort, index) ∈ nativeQueryVariables left ++ nativeQueryVariables right →
        nativeBindingAssignment bindings sort index = assignment sort index := by
  let variables := nativeQueryVariables left ++ nativeQueryVariables right
  refine ⟨variables.map (fun key => (key, assignment key.1 key.2)), ?_⟩
  rw [native_bindings_restriction]
  refine ⟨(native_ac_unifier_restriction_iff solved.1).mpr solved,
    native_restriction_supported variables assignment, ?_⟩
  intro sort index member
  simp only [restrictNativeAssignment, variables, ite_eq_left member]

theorem native_complete_unifiers_restriction_iff
    (sorted : ∀ candidate ∈ family, NativeSortedAssignment candidate) :
    NativeCompleteACUnifiers left right
      (family.map (restrictNativeAssignment
        (nativeQueryVariables left ++ nativeQueryVariables right))) ↔
      NativeCompleteACUnifiers left right family := by
  constructor
  · intro complete
    constructor
    · intro candidate member
      exact (native_ac_unifier_restriction_iff (sorted candidate member)).mp
        (complete.1 _ (List.mem_map.mpr ⟨candidate, member, rfl⟩))
    · intro solution solved
      obtain ⟨candidate, nativeMember, factorization⟩ := complete.2 solution solved
      obtain ⟨original, member, rfl⟩ := List.mem_map.mp nativeMember
      exact ⟨original, member, native_ac_instance_restriction_iff.mp factorization⟩
  · intro complete
    constructor
    · intro candidate nativeMember
      obtain ⟨original, member, rfl⟩ := List.mem_map.mp nativeMember
      exact (native_ac_unifier_restriction_iff (sorted original member)).mpr
        (complete.1 original member)
    · intro solution solved
      obtain ⟨candidate, member, factorization⟩ := complete.2 solution solved
      exact ⟨_, List.mem_map.mpr ⟨candidate, member, rfl⟩,
        native_ac_instance_restriction_iff.mpr factorization⟩

theorem native_complete_unifiers_finite_solutions_iff :
    NativeCompleteACUnifiers left right family ↔
      (∀ candidate ∈ family, NativeACUnifier left right candidate) ∧
      ∀ bindings, NativeACUnifier left right (nativeBindingAssignment bindings) →
        NativeAssignmentSupportedOn (nativeQueryVariables left ++ nativeQueryVariables right)
          (nativeBindingAssignment bindings) →
        ∃ candidate ∈ family,
          NativeACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
            candidate (nativeBindingAssignment bindings) := by
  constructor
  · intro complete
    exact ⟨complete.1, fun bindings solved _ => complete.2 _ solved⟩
  · rintro ⟨sound, finiteCoverage⟩
    refine ⟨sound, ?_⟩
    intro solution solved
    obtain ⟨bindings, finiteSolved, supported, equal⟩ :=
      native_ac_unifier_finite_representation solved
    obtain ⟨candidate, member, factor, sorted, equivalent⟩ :=
      finiteCoverage bindings finiteSolved supported
    refine ⟨candidate, member, factor, sorted, ?_⟩
    intro sort index input
    rw [← equal sort index input]
    exact equivalent sort index input

theorem native_most_general_finite_solutions_iff :
    NativeMostGeneralACUnifier left right candidate ↔
      NativeACUnifier left right candidate ∧
      ∀ bindings, NativeACUnifier left right (nativeBindingAssignment bindings) →
        NativeAssignmentSupportedOn (nativeQueryVariables left ++ nativeQueryVariables right)
          (nativeBindingAssignment bindings) →
        NativeACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
          candidate (nativeBindingAssignment bindings) := by
  rw [← native_singleton_complete_iff, native_complete_unifiers_finite_solutions_iff]
  simp

#print axioms native_ac_instance_finite_factor_iff
#print axioms native_ac_instance_restriction_iff
#print axioms native_ac_unifier_restriction_iff
#print axioms native_ac_unifier_finite_representation
#print axioms native_complete_unifiers_restriction_iff
#print axioms native_complete_unifiers_finite_solutions_iff
#print axioms native_most_general_finite_solutions_iff

end Cairn.Equations
