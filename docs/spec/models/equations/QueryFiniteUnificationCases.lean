import QueryFiniteUnification

namespace Cairn.Equations

private def residual : QuerySubstitution where
  publicAtoms index := 2 * index
  freshAtoms index := 2 * index
  messages index := .atom .messageAtom (2 * index)
  naturals index := if index = 0 ∨ index = 1 then .variable 14 else .variable (2 * index)
  nodes index := 2 * index

private def ground : QuerySubstitution :=
  { residual with naturals := fun _ => .one }

example : nativeAssignmentVariables [(.natural, 0), (.natural, 1)]
    (nativeQueryAssignment residual) = [(.natural, 7), (.natural, 7)] := rfl

private theorem residual_most_general :
    NativeMostGeneralACUnifier (.queryVariable .natural 0) (.queryVariable .natural 1)
      (nativeQueryAssignment residual) := by
  constructor
  · exact ⟨native_typed_assignment_sorted residual, .reflexive⟩
  · intro solution solved
    obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation solved.1
    rw [← compatible] at solved ⊢
    let factor := { typed with naturals := fun index =>
      if index = 7 then typed.naturals 0 else typed.naturals index }
    refine ⟨nativeQueryAssignment factor, native_typed_assignment_sorted factor, ?_⟩
    intro sort index member
    simp only [nativeQueryVariables, List.mem_append, List.mem_singleton, Prod.mk.injEq] at member
    rcases member with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · exact .reflexive
    · exact .symmetric solved.2

-- A residual variable outside both original supports is essential to this factor.
example : NativeACInstanceOn [(.natural, 0), (.natural, 1)]
    (nativeQueryAssignment residual) (nativeQueryAssignment ground) :=
  residual_most_general.2 _ ⟨native_typed_assignment_sorted ground, .reflexive⟩

example : ¬ ∃ factor,
    NativeAssignmentSupportedOn [(.natural, 0), (.natural, 1)] factor ∧
      NativeAssignmentACOn [(.natural, 0), (.natural, 1)]
        (nativeQueryAssignment ground)
        (composeNativeAssignments (nativeQueryAssignment residual) factor) := by
  rintro ⟨factor, supported, equivalent⟩
  have outside := supported .natural 7 (by simp)
  have leaf := native_query_ac_leaf (equivalent .natural 0 (by simp))
  change some NativeQueryTerm.naturalOne = nativeQueryLeaf (factor .natural 7) at leaf
  rw [outside] at leaf
  cases leaf

example : NativeAssignmentSupportedOn [(.natural, 7)]
    (nativeBindingAssignment [((.natural, 7), .naturalOne)]) :=
  native_bindings_supported [((.natural, 7), .naturalOne)]

example : NativeAssignmentACOn [(.natural, 0), (.natural, 1)]
    (nativeQueryAssignment ground)
    (composeNativeAssignments (nativeQueryAssignment residual)
      (nativeBindingAssignment [((.natural, 7), .naturalOne)])) := by
  intro sort index member
  simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at member
  rcases member with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;> exact .reflexive

example : nativeBindingAssignment
    [((.natural, 0), .naturalOne), ((.natural, 1), .naturalOne)] .natural 7 =
      .queryVariable .natural 7 := rfl

example : NativeCompleteACUnifiers (.queryVariable .natural 0) (.queryVariable .natural 1)
    [restrictNativeAssignment [(.natural, 0), (.natural, 1)] (nativeQueryAssignment residual)] := by
  apply (native_complete_unifiers_restriction_iff
    (family := [nativeQueryAssignment residual]) ?_).mpr
  · exact native_singleton_complete_iff.mpr residual_most_general
  · intro candidate member
    simp only [List.mem_singleton] at member
    rw [member]
    exact native_typed_assignment_sorted residual

-- Restriction cannot justify accepting an original assignment with an invalid binding.
example : ¬ NativeSortedAssignment (fun _ _ => NativeQueryTerm.naturalOne) := by
  intro sorted
  have invalid := sorted .freshAtom 9
  cases invalid

example : NativeACUnifier (.queryVariable .natural 0) (.queryVariable .natural 0)
    (restrictNativeAssignment [(.natural, 0)] (fun _ _ => .naturalOne)) := by
  constructor
  · intro sort index
    cases sort with
    | publicAtom => exact .publicVariable
    | freshAtom => exact .freshVariable
    | message => exact .message rfl
    | natural =>
      unfold restrictNativeAssignment
      split <;> exact .natural rfl
    | node => exact .nodeVariable
  · exact .reflexive

end Cairn.Equations
