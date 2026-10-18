import QuerySupport

namespace Cairn.Equations

theorem native_occurrence_substitution_count
    (member : (sort, index) ∈ nativeQueryVariables term)
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    nativeQueryFunctionCount (assignment sort index) ≤
      nativeQueryFunctionCount (substituteNativeQuery assignment term) := by
  induction term with
  | queryVariable otherSort otherIndex =>
    simp only [nativeQueryVariables, List.mem_singleton, Prod.mk.injEq] at member
    obtain ⟨rfl, rfl⟩ := member
    exact Nat.le_refl _
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    simp [nativeQueryVariables] at member
  | unary _ _ child | list _ child =>
    exact Nat.le_trans (child member) (by simp [substituteNativeQuery, nativeQueryFunctionCount])
  | naturalAdd _ _ left right | binary _ _ _ left right | cons _ _ left right =>
    simp only [nativeQueryVariables, List.mem_append] at member
    rcases member with first | second
    · have bound := left first
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
    · have bound := right second
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
  | kdf _ _ _ first second third =>
    simp only [nativeQueryVariables, List.mem_append] at member
    rcases member with (member | member) | member
    · have bound := first member
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
    · have bound := second member
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
    · have bound := third member
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega

theorem native_proper_occurrence_substitution_count
    (member : (sort, index) ∈ nativeQueryVariables term)
    (proper : term ≠ .queryVariable sort index)
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    nativeQueryFunctionCount (assignment sort index) <
      nativeQueryFunctionCount (substituteNativeQuery assignment term) := by
  cases term with
  | queryVariable otherSort otherIndex =>
    simp only [nativeQueryVariables, List.mem_singleton, Prod.mk.injEq] at member
    obtain ⟨rfl, rfl⟩ := member
    exact (proper rfl).elim
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    simp [nativeQueryVariables] at member
  | unary _ child | list child =>
    have bound := native_occurrence_substitution_count (term := child) member assignment
    simp only [substituteNativeQuery, nativeQueryFunctionCount]
    omega
  | naturalAdd left right | binary _ left right | cons left right =>
    simp only [nativeQueryVariables, List.mem_append] at member
    rcases member with first | second
    · have bound := native_occurrence_substitution_count first assignment
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
    · have bound := native_occurrence_substitution_count second assignment
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
  | kdf first second third =>
    simp only [nativeQueryVariables, List.mem_append] at member
    rcases member with (member | member) | member
    · have bound := native_occurrence_substitution_count member assignment
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
    · have bound := native_occurrence_substitution_count member assignment
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega
    · have bound := native_occurrence_substitution_count member assignment
      simp only [substituteNativeQuery, nativeQueryFunctionCount]
      omega

theorem native_ac_unifier_occurs_check
    (member : (sort, index) ∈ nativeQueryVariables term)
    (proper : term ≠ .queryVariable sort index) :
    ¬ NativeACUnifier (.queryVariable sort index) term assignment := by
  intro solved
  have bound := native_proper_occurrence_substitution_count member proper assignment
  have equal := native_query_ac_preserves_count solved.2
  simp only [substituteNativeQuery] at equal
  omega

theorem native_occurs_complete_empty_family
    (member : (sort, index) ∈ nativeQueryVariables term)
    (proper : term ≠ .queryVariable sort index) :
    NativeCompleteACUnifiers (.queryVariable sort index) term [] := by
  refine ⟨by simp, ?_⟩
  intro solution solved
  exact (native_ac_unifier_occurs_check member proper solved).elim

#print axioms native_occurrence_substitution_count
#print axioms native_proper_occurrence_substitution_count
#print axioms native_ac_unifier_occurs_check
#print axioms native_occurs_complete_empty_family

end Cairn.Equations
