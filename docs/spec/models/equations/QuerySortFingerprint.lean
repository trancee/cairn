import QueryPrincipalSort

namespace Cairn.Equations

theorem native_sort_fingerprint_substitution
    (firstSorted : NativeSortedAssignment first)
    (secondSorted : NativeSortedAssignment second)
    (fingerprint : ∀ sort index expected,
      NativeSortedValue expected (first sort index) ↔
        NativeSortedValue expected (second sort index))
    (term : NativeQueryTerm) (expected : QuerySort) :
    NativeSortedValue expected (substituteNativeQuery first term) ↔
      NativeSortedValue expected (substituteNativeQuery second term) := by
  rw [native_sort_requirements_iff first firstSorted,
    native_sort_requirements_iff second secondSorted]
  cases nativeSortRequirements expected term with
  | none => rfl
  | some constraints =>
    constructor
    · intro holds constraint member
      exact (fingerprint _ _ _).mp (holds constraint member)
    · intro holds constraint member
      exact (fingerprint _ _ _).mpr (holds constraint member)

#print axioms native_sort_fingerprint_substitution

end Cairn.Equations
