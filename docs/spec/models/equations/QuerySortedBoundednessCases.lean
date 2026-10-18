import QuerySortedBoundedness

namespace Cairn.Equations

private def badSum : NativeQueryTerm :=
  .naturalAdd (.queryVariable .freshAtom 0) .naturalOne

private def blockedTemplate : NativeQueryTerm :=
  .unary .fst (.binary .pair (.unary .flip .roleA) badSum)

private def blockedNormal : NativeQueryTerm :=
  .unary .fst (.binary .pair .roleB badSum)

example : NativeSortedSteps blockedTemplate 1 blockedNormal ∧
    NativeSortedNormal blockedNormal := by
  refine ⟨.step (.unary (.binaryLeft (.primitive .flipA))) .reflexive, ?_⟩
  intro result step
  cases step with
  | primitive root =>
    cases root with
    | fst _ discarded =>
      obtain ⟨_, decoded⟩ := discarded
      simp [badSum, decodeNativeMessage, decodeNativeNatural] at decoded
  | unary child =>
    cases child with
    | primitive impossible => cases impossible
    | binaryLeft child =>
      cases child with
      | primitive impossible => cases impossible
    | binaryRight child =>
      cases child with
      | primitive impossible => cases impossible
      | naturalLeft child =>
        cases child with
        | primitive impossible => cases impossible
      | naturalRight child =>
        cases child with
        | primitive impossible => cases impossible

example (assignment : QuerySort → Nat → NativeQueryTerm)
    (normalized : ∀ sort identifier, NativeSortedNormal (assignment sort identifier)) :
    ∃ count result, count ≤ 4 ∧
      NativeSortedSteps (substituteNativeQuery assignment blockedTemplate) count result ∧
      NativeSortedNormal result := by
  simpa [nativeQueryFunctionCount, blockedTemplate, badSum] using
    native_sorted_query_substitution_bound blockedTemplate assignment normalized

example (replacement : NativeQueryTerm) (normal : NativeSortedNormal replacement) :
    ∃ count result, count ≤ 0 ∧ NativeSortedSteps replacement count result ∧
      NativeSortedNormal result := by
  simpa [nativeQueryFunctionCount, substituteNativeQuery] using
    native_sorted_query_substitution_bound (.queryVariable .message 0)
      (fun _ _ => replacement) (fun _ _ => normal)

private def framedTemplate : NativeQueryTerm :=
  .list (.cons (.queryVariable .node 0) (.cons blockedTemplate .nil))

example (assignment : QuerySort → Nat → NativeQueryTerm)
    (normalized : ∀ sort identifier, NativeSortedNormal (assignment sort identifier)) :
    ∃ count result, count ≤ 7 ∧
      NativeSortedSteps (substituteNativeQuery assignment framedTemplate) count result ∧
      NativeSortedNormal result := by
  simpa [nativeQueryFunctionCount, framedTemplate, blockedTemplate, badSum] using
    native_sorted_query_substitution_bound framedTemplate assignment normalized

example (assignment : QuerySort → Nat → NativeQueryTerm)
    (normalized : ∀ sort identifier, NativeSortedNormal (assignment sort identifier)) :
    ∃ count result, count ≤ 6 ∧
      NativeSortedSteps
        (substituteNativeQuery assignment (.kdf blockedTemplate (.unary .flip .roleB) .naturalOne))
        count result ∧ NativeSortedNormal result := by
  simpa [nativeQueryFunctionCount, blockedTemplate, badSum] using
    native_sorted_query_substitution_bound
      (.kdf blockedTemplate (.unary .flip .roleB) .naturalOne) assignment normalized

example (assignment : QuerySort → Nat → NativeQueryTerm)
    (normalized : ∀ sort identifier, NativeSortedNormal (assignment sort identifier)) :
    ∃ count result, count ≤ 4 ∧
      NativeSortedSteps
        (substituteNativeQuery assignment (.binary .sdec (.binary .senc .roleA badSum) badSum))
        count result ∧ NativeSortedNormal result := by
  simpa [nativeQueryFunctionCount, badSum] using native_sorted_query_substitution_bound
    (.binary .sdec (.binary .senc .roleA badSum) badSum) assignment normalized

-- This raw-AST case is outside the native stream guard's controlled kind image.
example : NativeSortedSteps
    (.naturalAdd (.unary .fst (.binary .pair .naturalOne .roleA)) .naturalOne)
    1 (.naturalAdd .naturalOne .naturalOne) :=
  .step (.naturalLeft (.primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩))) .reflexive

end Cairn.Equations
