import QueryFiniteUnification

namespace Cairn.Equations

def kindVariableKey : QuerySort × Nat → QuerySort × Nat
  | (.freshAtom, index) => (.natural, 2 * index + 1)
  | (.natural, index) => (.natural, 2 * index)
  | key => key

-- Expansion is total; admissibility separately forbids invalid original-sort values.
def expandKindAssignment (shadow : QuerySort → Nat → NativeQueryTerm)
    (sort : QuerySort) (index : Nat) : NativeQueryTerm :=
  let key := kindVariableKey (sort, index)
  relabelNative kindExpansion (shadow key.1 key.2)

theorem native_kind_assignment_lookup (assignment : QuerySort → Nat → NativeQueryTerm)
    (sort : QuerySort) (index : Nat) :
    abstractKindAssignment assignment (kindVariableKey (sort, index)).1
      (kindVariableKey (sort, index)).2 =
        relabelNative kindAbstraction (assignment sort index) := by
  have oddHalf : (2 * index + 1) / 2 = index := by omega
  cases sort <;> simp [kindVariableKey, abstractKindAssignment, oddHalf]

theorem native_kind_assignment_round_trip (assignment : QuerySort → Nat → NativeQueryTerm) :
    expandKindAssignment (abstractKindAssignment assignment) = assignment := by
  funext sort index
  change relabelNative kindExpansion
    (abstractKindAssignment assignment (kindVariableKey (sort, index)).1
      (kindVariableKey (sort, index)).2) = assignment sort index
  rw [native_kind_assignment_lookup assignment sort index, native_kind_round_trip]

theorem native_kind_assignment_injective : Function.Injective abstractKindAssignment := by
  intro first second equality
  have recovered := congrArg expandKindAssignment equality
  simpa only [native_kind_assignment_round_trip] using recovered

theorem native_kind_composition (first second : QuerySort → Nat → NativeQueryTerm) :
    abstractKindAssignment (composeNativeAssignments first second) =
      composeNativeAssignments (abstractKindAssignment first) (abstractKindAssignment second) := by
  funext sort index
  cases sort with
  | freshAtom => rfl
  | natural =>
    simp only [abstractKindAssignment, composeNativeAssignments]
    split <;> exact native_kind_substitution second _
  | publicAtom | message | node => exact native_kind_substitution second _

def NativeKindAdmissibleAssignment (shadow : QuerySort → Nat → NativeQueryTerm) : Prop :=
  NativeSortedAssignment (expandKindAssignment shadow) ∧
    abstractKindAssignment (expandKindAssignment shadow) = shadow

theorem native_kind_admissible_iff :
    NativeKindAdmissibleAssignment shadow ↔
      ∃ original, NativeSortedAssignment original ∧ abstractKindAssignment original = shadow := by
  constructor
  · intro admissible
    exact ⟨expandKindAssignment shadow, admissible⟩
  · rintro ⟨original, sorted, rfl⟩
    exact ⟨by simpa only [native_kind_assignment_round_trip] using sorted,
      by rw [native_kind_assignment_round_trip]⟩

theorem native_kind_admissible_sorted (admissible : NativeKindAdmissibleAssignment shadow) :
    NativeSortedAssignment shadow := by
  rw [← admissible.2]
  exact native_kind_assignment_sorted admissible.1

theorem native_kind_admissible_composition (first : NativeKindAdmissibleAssignment firstShadow)
    (second : NativeKindAdmissibleAssignment secondShadow) :
    NativeKindAdmissibleAssignment (composeNativeAssignments firstShadow secondShadow) := by
  obtain ⟨firstOriginal, firstSorted, rfl⟩ := native_kind_admissible_iff.mp first
  obtain ⟨secondOriginal, secondSorted, rfl⟩ := native_kind_admissible_iff.mp second
  rw [← native_kind_composition]
  exact native_kind_admissible_iff.mpr
    ⟨_, native_sorted_composition firstSorted secondSorted, rfl⟩

theorem native_kind_query_variables (term : NativeQueryTerm) :
    nativeQueryVariables (relabelNative kindAbstraction term) =
      (nativeQueryVariables term).map kindVariableKey := by
  induction term with
  | atom sort index => cases sort <;> rfl
  | queryVariable sort index => cases sort <;> rfl
  | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil => rfl
  | naturalAdd _ _ first second | binary _ _ _ first second | cons _ _ first second =>
    simp only [relabelNative, nativeQueryVariables, first, second, List.map_append]
  | unary _ _ child | list _ child => exact child
  | kdf _ _ _ first second third =>
    simp only [relabelNative, nativeQueryVariables, first, second, third, List.map_append]

theorem native_kind_assignment_ac_on_iff :
    NativeAssignmentACOn (variables.map kindVariableKey)
      (abstractKindAssignment first) (abstractKindAssignment second) ↔
        NativeAssignmentACOn variables first second := by
  constructor
  · intro equivalent sort index member
    have abstracted : NativeQueryAC
        (abstractKindAssignment first (kindVariableKey (sort, index)).1
          (kindVariableKey (sort, index)).2)
        (abstractKindAssignment second (kindVariableKey (sort, index)).1
          (kindVariableKey (sort, index)).2) :=
      equivalent _ _ (List.mem_map.mpr ⟨(sort, index), member, rfl⟩)
    rw [native_kind_assignment_lookup first sort index,
      native_kind_assignment_lookup second sort index] at abstracted
    exact native_kind_ac_reflection abstracted
  · intro equivalent sort index member
    obtain ⟨⟨originalSort, originalIndex⟩, originalMember, key⟩ := List.mem_map.mp member
    have abstracted := native_ac_relabeling kindAbstraction
      (equivalent originalSort originalIndex originalMember)
    rw [← native_kind_assignment_lookup first originalSort originalIndex,
      ← native_kind_assignment_lookup second originalSort originalIndex] at abstracted
    simpa only [key] using abstracted

-- Shadow factors must lift too; ordinary sorted natural factors are too permissive.
def NativeKindACInstanceOn (variables : List (QuerySort × Nat))
    (general specific : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∃ factor, NativeKindAdmissibleAssignment factor ∧
    NativeAssignmentACOn variables specific (composeNativeAssignments general factor)

theorem native_kind_ac_instance_iff :
    NativeKindACInstanceOn (variables.map kindVariableKey)
      (abstractKindAssignment general) (abstractKindAssignment specific) ↔
        NativeACInstanceOn variables general specific := by
  constructor
  · rintro ⟨factor, admissible, equivalent⟩
    refine ⟨expandKindAssignment factor, admissible.1, ?_⟩
    rw [← admissible.2, ← native_kind_composition] at equivalent
    exact native_kind_assignment_ac_on_iff.mp equivalent
  · rintro ⟨factor, sorted, equivalent⟩
    refine ⟨abstractKindAssignment factor,
      native_kind_admissible_iff.mpr ⟨factor, sorted, rfl⟩, ?_⟩
    rw [← native_kind_composition]
    exact native_kind_assignment_ac_on_iff.mpr equivalent

theorem native_kind_admissible_unifier_iff :
    (NativeKindAdmissibleAssignment (abstractKindAssignment assignment) ∧
      NativeACUnifier (relabelNative kindAbstraction left) (relabelNative kindAbstraction right)
        (abstractKindAssignment assignment)) ↔ NativeACUnifier left right assignment := by
  constructor
  · rintro ⟨admissible, solved⟩
    have sorted : NativeSortedAssignment assignment := by
      simpa only [native_kind_assignment_round_trip] using admissible.1
    exact (native_kind_ac_unifier_iff assignment left right).mpr ⟨sorted, solved.2⟩
  · intro solved
    exact ⟨native_kind_admissible_iff.mpr ⟨assignment, solved.1, rfl⟩,
      native_kind_assignment_sorted solved.1,
      ((native_kind_ac_unifier_iff assignment left right).mp solved).2⟩

#print axioms native_kind_assignment_lookup
#print axioms native_kind_assignment_round_trip
#print axioms native_kind_assignment_injective
#print axioms native_kind_composition
#print axioms native_kind_admissible_iff
#print axioms native_kind_admissible_sorted
#print axioms native_kind_admissible_composition
#print axioms native_kind_query_variables
#print axioms native_kind_assignment_ac_on_iff
#print axioms native_kind_ac_instance_iff
#print axioms native_kind_admissible_unifier_iff

end Cairn.Equations
