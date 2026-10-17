import QueryVariableGeneration
import QueryFiniteUnification

namespace Cairn.Equations

abbrev NativeEquationSystem : Type := List (NativeQueryTerm × NativeQueryTerm)

def nativeSystemVariables (equations : NativeEquationSystem) : List (QuerySort × Nat) :=
  equations.flatMap (fun equation =>
    nativeQueryVariables equation.1 ++ nativeQueryVariables equation.2)

def substituteNativeSystem (assignment : QuerySort → Nat → NativeQueryTerm)
    (equations : NativeEquationSystem) : NativeEquationSystem :=
  equations.map (fun equation =>
    (substituteNativeQuery assignment equation.1, substituteNativeQuery assignment equation.2))

def NativeACSystemUnifier (equations : NativeEquationSystem)
    (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  NativeSortedAssignment assignment ∧ ∀ equation ∈ equations,
    NativeQueryAC (substituteNativeQuery assignment equation.1)
      (substituteNativeQuery assignment equation.2)

-- The explicit scope can retain variables no longer mentioned by residual equations.
def NativeCompleteACSystemOn (equations : NativeEquationSystem)
    (variables : List (QuerySort × Nat))
    (family : List (QuerySort → Nat → NativeQueryTerm)) : Prop :=
  (∀ candidate ∈ family, NativeACSystemUnifier equations candidate) ∧
    ∀ solution, NativeACSystemUnifier equations solution →
      ∃ candidate ∈ family, NativeACInstanceOn variables candidate solution

theorem native_system_cons_iff :
    NativeACSystemUnifier ((left, right) :: equations) assignment ↔
      NativeACUnifier left right assignment ∧ NativeACSystemUnifier equations assignment := by
  constructor
  · intro solved
    refine ⟨⟨solved.1, solved.2 (left, right) (by simp)⟩, solved.1, ?_⟩
    intro equation member
    exact solved.2 equation (List.mem_cons_of_mem _ member)
  · rintro ⟨first, rest⟩
    refine ⟨first.1, ?_⟩
    intro equation member
    rcases List.mem_cons.mp member with rfl | member
    · exact first.2
    · exact rest.2 equation member

theorem native_system_singleton_complete_iff :
    NativeCompleteACSystemOn [(left, right)]
      (nativeQueryVariables left ++ nativeQueryVariables right) family ↔
      NativeCompleteACUnifiers left right family := by
  have solves (assignment) :
      NativeACSystemUnifier [(left, right)] assignment ↔ NativeACUnifier left right assignment := by
    simp [NativeACSystemUnifier, NativeACUnifier]
  unfold NativeCompleteACSystemOn NativeCompleteACUnifiers
  simp only [solves]

theorem native_system_substitution_iff (firstSorted : NativeSortedAssignment first)
    (secondSorted : NativeSortedAssignment second) :
    NativeACSystemUnifier (substituteNativeSystem first equations) second ↔
      NativeACSystemUnifier equations (composeNativeAssignments first second) := by
  constructor
  · intro solved
    refine ⟨native_sorted_composition firstSorted secondSorted, ?_⟩
    intro equation member
    have transported := solved.2 _ (List.mem_map.mpr ⟨equation, member, rfl⟩)
    simpa only [native_substitution_composition] using transported
  · intro solved
    refine ⟨secondSorted, ?_⟩
    intro equation member
    obtain ⟨original, originalMember, rfl⟩ := List.mem_map.mp member
    simpa only [native_substitution_composition] using solved.2 original originalMember

theorem native_system_assignment_ac (sorted : NativeSortedAssignment second)
    (equivalent : NativeAssignmentAC first second)
    (solved : NativeACSystemUnifier equations first) :
    NativeACSystemUnifier equations second := by
  refine ⟨sorted, ?_⟩
  intro equation member
  exact .transitive (.symmetric (native_substitution_assignment_ac equivalent equation.1))
    (.transitive (solved.2 equation member)
      (native_substitution_assignment_ac equivalent equation.2))

theorem native_system_empty_complete (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn [] variables [NativeQueryTerm.queryVariable] := by
  constructor
  · intro candidate member
    have equal := List.mem_singleton.mp member
    subst candidate
    exact ⟨native_identity_assignment_sorted, by simp⟩
  · intro solution solved
    refine ⟨NativeQueryTerm.queryVariable, by simp, solution, solved.1, ?_⟩
    intro sort index _
    exact .reflexive

theorem native_system_reflexive_complete_iff :
    NativeCompleteACSystemOn ((term, term) :: equations) variables family ↔
      NativeCompleteACSystemOn equations variables family := by
  have solves (assignment) :
      NativeACSystemUnifier ((term, term) :: equations) assignment ↔
        NativeACSystemUnifier equations assignment := by
    rw [native_system_cons_iff]
    exact ⟨And.right, fun solved => ⟨⟨solved.1, .reflexive⟩, solved⟩⟩
  unfold NativeCompleteACSystemOn
  simp only [solves]

theorem native_ac_instance_prefix (first : QuerySort → Nat → NativeQueryTerm)
    (factorization : NativeACInstanceOn (nativeAssignmentVariables variables first)
      general specific) :
    NativeACInstanceOn variables (composeNativeAssignments first general)
      (composeNativeAssignments first specific) := by
  obtain ⟨factor, sorted, equivalent⟩ := factorization
  refine ⟨factor, sorted, ?_⟩
  intro sort index member
  change NativeQueryAC (substituteNativeQuery specific (first sort index))
    (substituteNativeQuery factor (substituteNativeQuery general (first sort index)))
  rw [native_substitution_composition]
  apply native_substitution_assignment_ac_on
  intro childSort childIndex occurs
  exact equivalent childSort childIndex (List.mem_flatMap.mpr ⟨(sort, index), member, occurs⟩)

theorem native_system_swap_complete_iff :
    NativeCompleteACSystemOn ((left, right) :: equations) variables family ↔
      NativeCompleteACSystemOn ((right, left) :: equations) variables family := by
  have solves (assignment) :
      NativeACSystemUnifier ((left, right) :: equations) assignment ↔
        NativeACSystemUnifier ((right, left) :: equations) assignment := by
    rw [native_system_cons_iff, native_system_cons_iff]
    constructor <;> rintro ⟨first, rest⟩ <;> exact ⟨⟨first.1, .symmetric first.2⟩, rest⟩
  unfold NativeCompleteACSystemOn
  simp only [solves]

#print axioms native_system_cons_iff
#print axioms native_system_singleton_complete_iff
#print axioms native_system_substitution_iff
#print axioms native_system_assignment_ac
#print axioms native_system_empty_complete
#print axioms native_system_reflexive_complete_iff
#print axioms native_ac_instance_prefix
#print axioms native_system_swap_complete_iff

end Cairn.Equations
