import QueryKindInstances

namespace Cairn.Equations

-- Both solutions and postfactors must lift; unrestricted shadow coverage is different.
def NativeKindCompleteACUnifiers (left right : NativeQueryTerm)
    (family : List (QuerySort → Nat → NativeQueryTerm)) : Prop :=
  (∀ candidate ∈ family,
    NativeKindAdmissibleAssignment candidate ∧ NativeACUnifier left right candidate) ∧
    ∀ solution, NativeKindAdmissibleAssignment solution → NativeACUnifier left right solution →
      ∃ candidate ∈ family,
        NativeKindACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
          candidate solution

def NativeKindMostGeneralACUnifier (left right : NativeQueryTerm)
    (candidate : QuerySort → Nat → NativeQueryTerm) : Prop :=
  NativeKindAdmissibleAssignment candidate ∧ NativeACUnifier left right candidate ∧
    ∀ solution, NativeKindAdmissibleAssignment solution → NativeACUnifier left right solution →
      NativeKindACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
        candidate solution

theorem native_kind_singleton_complete_iff :
    NativeKindCompleteACUnifiers left right [candidate] ↔
      NativeKindMostGeneralACUnifier left right candidate := by
  simp [NativeKindCompleteACUnifiers, NativeKindMostGeneralACUnifier, and_assoc]

theorem native_kind_complete_unifiers_iff (left right : NativeQueryTerm)
    (family : List (QuerySort → Nat → NativeQueryTerm)) :
    NativeCompleteACUnifiers left right family ↔
      NativeKindCompleteACUnifiers (relabelNative kindAbstraction left)
        (relabelNative kindAbstraction right) (family.map abstractKindAssignment) := by
  constructor
  · intro complete
    constructor
    · intro candidate shadowMember
      obtain ⟨original, member, rfl⟩ := List.mem_map.mp shadowMember
      exact native_kind_admissible_unifier_iff.mpr (complete.1 original member)
    · intro solution admissible solved
      obtain ⟨original, sorted, rfl⟩ := native_kind_admissible_iff.mp admissible
      have originalSolved := (native_kind_ac_unifier_iff original left right).mpr
        ⟨sorted, solved.2⟩
      obtain ⟨candidate, member, factorization⟩ := complete.2 original originalSolved
      refine ⟨_, List.mem_map.mpr ⟨candidate, member, rfl⟩, ?_⟩
      have transported := native_kind_ac_instance_iff.mpr factorization
      simpa only [List.map_append, native_kind_query_variables] using transported
  · intro complete
    constructor
    · intro candidate member
      exact native_kind_admissible_unifier_iff.mp
        (complete.1 _ (List.mem_map.mpr ⟨candidate, member, rfl⟩))
    · intro solution solved
      have shadowSolved := native_kind_admissible_unifier_iff.mpr solved
      obtain ⟨candidate, shadowMember, factorization⟩ :=
        complete.2 _ shadowSolved.1 shadowSolved.2
      obtain ⟨original, member, rfl⟩ := List.mem_map.mp shadowMember
      refine ⟨original, member, ?_⟩
      apply native_kind_ac_instance_iff.mp
      simpa only [List.map_append, native_kind_query_variables] using factorization

theorem native_kind_most_general_iff (left right : NativeQueryTerm)
    (candidate : QuerySort → Nat → NativeQueryTerm) :
    NativeMostGeneralACUnifier left right candidate ↔
      NativeKindMostGeneralACUnifier (relabelNative kindAbstraction left)
        (relabelNative kindAbstraction right) (abstractKindAssignment candidate) := by
  rw [← native_singleton_complete_iff, ← native_kind_singleton_complete_iff]
  exact native_kind_complete_unifiers_iff left right [candidate]

#print axioms native_kind_singleton_complete_iff
#print axioms native_kind_complete_unifiers_iff
#print axioms native_kind_most_general_iff

end Cairn.Equations
