import QuerySortFingerprint

namespace Cairn.Equations

example (term : NativeQueryTerm) (expected : QuerySort) (index : Nat) :
    NativeSortedValue expected term ↔
      ∃ principal, nativePrincipalSort term = some principal ∧
        NativeSortedValue expected (.queryVariable principal index) :=
  native_principal_sort_iff term expected index

example : nativePrincipalSort (.atom .publicAtom 0) = some .publicAtom := by decide
example : nativePrincipalSort (.queryVariable .freshAtom 0) = some .freshAtom := by decide
example : nativePrincipalSort (.naturalAdd .naturalOne .naturalOne) = some .natural := by decide
example : nativePrincipalSort (.unary .hash (.atom .freshAtom 0)) = some .message := by decide
example : nativePrincipalSort (.nodeAtom 0) = some .node := by decide
example : nativePrincipalSort (.list (.atom .publicAtom 0)) = none := by decide
example : nativePrincipalSort (.naturalAdd (.atom .freshAtom 0) .naturalOne) = none := by decide
example : nativePrincipalSort (.unary .hash (.nodeAtom 0)) = none := by decide

example (firstSorted : NativeSortedAssignment first)
    (secondSorted : NativeSortedAssignment second)
    (samePrincipal : ∀ sort index,
      nativePrincipalSort (first sort index) = nativePrincipalSort (second sort index))
    (term : NativeQueryTerm) (expected : QuerySort) :
    NativeSortedValue expected (substituteNativeQuery first term) ↔
      NativeSortedValue expected (substituteNativeQuery second term) := by
  apply native_sort_fingerprint_substitution firstSorted secondSorted
  intro sort index required
  rw [native_principal_sort_iff _ _ 0, native_principal_sort_iff _ _ 0,
    samePrincipal sort index]

end Cairn.Equations
