import QueryUnification

namespace Cairn.Equations

-- Multiplicity/order are immaterial; only membership in the source support is used.
def nativeQueryVariables : NativeQueryTerm → List (QuerySort × Nat)
  | .queryVariable sort index => [(sort, index)]
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .naturalOne | .roleA | .roleB | .nil => []
  | .naturalAdd left right | .binary _ left right | .cons left right =>
    nativeQueryVariables left ++ nativeQueryVariables right
  | .unary _ term | .list term => nativeQueryVariables term
  | .kdf first second third =>
    nativeQueryVariables first ++ nativeQueryVariables second ++ nativeQueryVariables third

def NativeAssignmentACOn (variables : List (QuerySort × Nat))
    (first second : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∀ sort index, (sort, index) ∈ variables → NativeQueryAC (first sort index) (second sort index)

theorem native_substitution_assignment_ac_on
    (equivalent : NativeAssignmentACOn (nativeQueryVariables term) first second) :
    NativeQueryAC (substituteNativeQuery first term) (substituteNativeQuery second term) := by
  induction term with
  | queryVariable sort index => exact equivalent sort index (by simp [nativeQueryVariables])
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil => exact .reflexive
  | naturalAdd _ _ left right =>
    exact .naturalAdd
      (left (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inl member)))
      (right (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inr member)))
  | unary _ _ child => exact .unary (child equivalent)
  | binary _ _ _ left right =>
    exact .binary
      (left (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inl member)))
      (right (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inr member)))
  | kdf _ _ _ first second third =>
    exact .kdf
      (first (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inl (.inl member))))
      (second (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inl (.inr member))))
      (third (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inr member)))
  | list _ child => exact .list (child equivalent)
  | cons _ _ first rest =>
    exact .cons
      (first (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inl member)))
      (rest (fun sort index member => equivalent sort index (by
        simp only [nativeQueryVariables, List.mem_append]; exact .inr member)))

-- General precedes specific. The factor is sorted; unrelated bindings need not agree.
def NativeACInstanceOn (variables : List (QuerySort × Nat))
    (general specific : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∃ factor, NativeSortedAssignment factor ∧
    NativeAssignmentACOn variables specific (composeNativeAssignments general factor)

theorem native_ac_instance_reflexive (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeACInstanceOn variables assignment assignment := by
  refine ⟨NativeQueryTerm.queryVariable, ?_, ?_⟩
  · intro sort index
    cases sort
    · exact .publicVariable
    · exact .freshVariable
    · exact .message rfl
    · exact .natural rfl
    · exact .nodeVariable
  · intro sort index _
    rw [composeNativeAssignments, native_substitution_identity]
    exact .reflexive

theorem native_ac_instance_transitive
    (first : NativeACInstanceOn variables general middle)
    (second : NativeACInstanceOn variables middle specific) :
    NativeACInstanceOn variables general specific := by
  obtain ⟨firstFactor, firstSorted, firstEquivalent⟩ := first
  obtain ⟨secondFactor, secondSorted, secondEquivalent⟩ := second
  refine ⟨composeNativeAssignments firstFactor secondFactor,
    native_sorted_composition firstSorted secondSorted, ?_⟩
  intro sort index member
  have transported := native_ac_substitution secondFactor (firstEquivalent sort index member)
  rw [composeNativeAssignments, ← native_substitution_composition]
  exact .transitive (secondEquivalent sort index member) transported

theorem native_ac_unifier_instance (solution : NativeACUnifier left right general)
    (sorted : NativeSortedAssignment specific)
    (factorization : NativeACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
      general specific) : NativeACUnifier left right specific := by
  obtain ⟨factor, factorSorted, equivalent⟩ := factorization
  have composed := native_ac_unifier_composition solution factorSorted
  have first := native_substitution_assignment_ac_on (term := left)
    (fun sort index member => equivalent sort index (List.mem_append_left _ member))
  have second := native_substitution_assignment_ac_on (term := right)
    (fun sort index member => equivalent sort index (List.mem_append_right _ member))
  exact ⟨sorted, .transitive first (.transitive composed.2 (.symmetric second))⟩

#print axioms native_substitution_assignment_ac_on
#print axioms native_ac_instance_reflexive
#print axioms native_ac_instance_transitive
#print axioms native_ac_unifier_instance

end Cairn.Equations
