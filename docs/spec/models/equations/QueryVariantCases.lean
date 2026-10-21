import QueryVariants

namespace Cairn.Equations

private def messageVariable (index : Nat) : NativeQueryTerm := .queryVariable .message index

example : nativeFreshBase (.unary .fst (messageVariable 4)) = 5 := by decide

example : (nativeVariantSchemes (.unary .fst (messageVariable 0)) 1).map (·.1) =
    [.unary .fst (messageVariable 0), messageVariable 1] := by decide

example : (nativeVariantSchemes (.unary .fst (messageVariable 0)) 1).map (·.2.1) =
    [[], [(messageVariable 0, .binary .pair (messageVariable 1) (messageVariable 2))]] := by decide

example : (nativeVariantSchemes (.unary .flip (messageVariable 0)) 1).map (·.1) =
    [.unary .flip (messageVariable 0), .roleB, .roleA] := by decide

example : (nativeVariantSchemes (.unary .hash (messageVariable 0)) 1).length = 1 := by decide

example : (nativeVariantSchemes
    (.binary .sdec (messageVariable 0) (messageVariable 1)) 2).map (·.2.1) =
    [[], [(messageVariable 0, .binary .senc (messageVariable 2) (messageVariable 3)),
      (messageVariable 1, messageVariable 3)]] := by decide

example : (nativeVariantSchemes (.unary .snd (.unary .fst (messageVariable 0))) 1).length = 4 := by
  decide

example (term : NativeQueryTerm) (assignment : QuerySort → Nat → NativeQueryTerm)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment) :
    ∃ value general factor, (value, general) ∈ nativeVariants term ∧
      NativeSortedAssignment factor ∧
      NativeAssignmentACOn (nativeQueryVariables term) assignment
        (composeNativeAssignments general factor) := by
  obtain ⟨value, general, factor, member, factorSorted, realizes, _⟩ :=
    native_finite_variants_complete (term := term) sorted normalized
  exact ⟨value, general, factor, member, factorSorted, realizes⟩

example (member : (value, general) ∈ nativeVariants term) : NativeSortedAssignment general :=
  (native_finite_variants_sound member).1

end Cairn.Equations
