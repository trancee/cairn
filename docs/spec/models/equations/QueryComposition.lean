import QuerySortedSubstitution

namespace Cairn.Equations

-- Apply first, then second; inserted values are not recursively resubstituted.
def composeNativeAssignments (first second : QuerySort → Nat → NativeQueryTerm) :
    QuerySort → Nat → NativeQueryTerm :=
  fun sort index => substituteNativeQuery second (first sort index)

theorem native_substitution_identity (term : NativeQueryTerm) :
    substituteNativeQuery NativeQueryTerm.queryVariable term = term := by
  induction term <;> simp_all [substituteNativeQuery]

theorem native_substitution_composition (first second : QuerySort → Nat → NativeQueryTerm)
    (term : NativeQueryTerm) :
    substituteNativeQuery second (substituteNativeQuery first term) =
      substituteNativeQuery (composeNativeAssignments first second) term := by
  induction term <;> simp_all [substituteNativeQuery, composeNativeAssignments]

theorem native_sorted_value_substitution (sorted : NativeSortedAssignment assignment)
    (value : NativeSortedValue sort term) :
    NativeSortedValue sort (substituteNativeQuery assignment term) := by
  cases value with
  | publicAtom => exact .publicAtom
  | publicVariable => exact sorted _ _
  | freshAtom => exact .freshAtom
  | freshVariable => exact sorted _ _
  | message decoded =>
    obtain ⟨_, image⟩ := native_sorted_proper_substitution sorted ⟨_, decoded⟩
    exact .message image
  | natural decoded =>
    obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation sorted
    rw [← compatible, ← native_natural_recognition _ decoded]
    exact .natural (native_natural_substitution_image typed _)
  | nodeAtom => exact .nodeAtom
  | nodeVariable => exact sorted _ _

theorem native_sorted_composition (firstSorted : NativeSortedAssignment first)
    (secondSorted : NativeSortedAssignment second) :
    NativeSortedAssignment (composeNativeAssignments first second) := by
  intro sort index
  exact native_sorted_value_substitution secondSorted (firstSorted sort index)

theorem native_composition_associative (first second third : QuerySort → Nat → NativeQueryTerm) :
    composeNativeAssignments (composeNativeAssignments first second) third =
      composeNativeAssignments first (composeNativeAssignments second third) := by
  funext sort index
  exact native_substitution_composition second third (first sort index)

def NativeAssignmentAC (first second : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∀ sort index, NativeQueryAC (first sort index) (second sort index)

theorem native_substitution_assignment_ac (equivalent : NativeAssignmentAC first second)
    (term : NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery first term) (substituteNativeQuery second term) := by
  induction term with
  | queryVariable sort index => exact equivalent sort index
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil => exact .reflexive
  | naturalAdd _ _ left right => exact .naturalAdd left right
  | unary _ _ child => exact .unary child
  | binary _ _ _ left right => exact .binary left right
  | kdf _ _ _ first second third => exact .kdf first second third
  | list _ child => exact .list child
  | cons _ _ first rest => exact .cons first rest

#print axioms native_substitution_identity
#print axioms native_substitution_composition
#print axioms native_sorted_value_substitution
#print axioms native_sorted_composition
#print axioms native_composition_associative
#print axioms native_substitution_assignment_ac

end Cairn.Equations
