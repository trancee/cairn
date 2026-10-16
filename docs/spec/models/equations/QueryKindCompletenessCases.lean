import QueryKindCompleteness

namespace Cairn.Equations

private theorem identity_sorted : NativeSortedAssignment NativeQueryTerm.queryVariable := by
  intro sort index
  cases sort
  · exact .publicVariable
  · exact .freshVariable
  · exact .message rfl
  · exact .natural rfl
  · exact .nodeVariable

private def first : NativeQueryTerm :=
  .naturalAdd (.queryVariable .freshAtom 0) (.queryVariable .natural 0)

private def second : NativeQueryTerm :=
  .naturalAdd (.queryVariable .natural 0) (.queryVariable .freshAtom 0)

private theorem kind_identity_mgu :
    NativeMostGeneralACUnifier first second NativeQueryTerm.queryVariable := by
  refine ⟨⟨identity_sorted, .commutative⟩, ?_⟩
  intro solution solved
  refine ⟨solution, solved.1, ?_⟩
  intro sort index _
  exact .reflexive

example : NativeKindMostGeneralACUnifier (relabelNative kindAbstraction first)
    (relabelNative kindAbstraction second)
    (abstractKindAssignment NativeQueryTerm.queryVariable) :=
  (native_kind_most_general_iff first second _).mp kind_identity_mgu

example : NativeKindCompleteACUnifiers (relabelNative kindAbstraction first)
    (relabelNative kindAbstraction second)
    ([NativeQueryTerm.queryVariable].map abstractKindAssignment) := by
  apply (native_kind_complete_unifiers_iff first second _).mp
  exact native_singleton_complete_iff.mpr kind_identity_mgu

private theorem no_mixed_solution :
    ¬ NativeACUnifier (.queryVariable .freshAtom 0) (.queryVariable .natural 0) assignment := by
  rintro ⟨sorted, equivalent⟩
  have natural := sorted .natural 0
  cases natural with
  | natural decoded =>
    obtain ⟨_, image, _⟩ := native_ac_natural_image (.symmetric equivalent) decoded
    simp only [substituteNativeQuery] at image
    have fresh := sorted .freshAtom 0
    generalize binding : assignment .freshAtom 0 = term at fresh image
    cases fresh <;> simp [decodeNativeNatural] at image

private theorem empty_complete :
    NativeCompleteACUnifiers (.queryVariable .freshAtom 0) (.queryVariable .natural 0) [] := by
  refine ⟨by simp, ?_⟩
  intro solution solved
  exact (no_mixed_solution solved).elim

example : NativeKindCompleteACUnifiers
    (relabelNative kindAbstraction (.queryVariable .freshAtom 0))
    (relabelNative kindAbstraction (.queryVariable .natural 0)) [] :=
  (native_kind_complete_unifiers_iff _ _ []).mp empty_complete

private def unrestricted : QuerySort → Nat → NativeQueryTerm
  | .natural, _ => .naturalOne
  | sort, index => .queryVariable sort index

private theorem unrestricted_sorted : NativeSortedAssignment unrestricted := by
  intro sort index
  cases sort
  · exact .publicVariable
  · exact .freshVariable
  · exact .message rfl
  · exact .natural rfl
  · exact .nodeVariable

-- Empty coverage is correct with the original sorts, false for unrestricted shadows.
example : ¬ NativeCompleteACUnifiers
    (relabelNative kindAbstraction (.queryVariable .freshAtom 0))
    (relabelNative kindAbstraction (.queryVariable .natural 0)) [] := by
  intro complete
  have solved : NativeACUnifier
      (relabelNative kindAbstraction (.queryVariable .freshAtom 0))
      (relabelNative kindAbstraction (.queryVariable .natural 0)) unrestricted :=
    ⟨unrestricted_sorted, .reflexive⟩
  obtain ⟨_, member, _⟩ := complete.2 unrestricted solved
  simp at member

end Cairn.Equations
