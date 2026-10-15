import QuerySortedQuotient

namespace Cairn.Equations

private def badSum : NativeQueryTerm :=
  .naturalAdd (.queryVariable .freshAtom 0) .naturalOne

private def errorSource : NativeQueryTerm :=
  .binary .pair (.unary .flip .roleA) badSum

private def errorNormal : NativeQueryTerm := .binary .pair .roleB badSum

private def otherNormal : NativeQueryTerm :=
  .binary .pair .roleB (.naturalAdd .naturalOne (.queryVariable .freshAtom 0))

private theorem error_normal : NativeSortedNormal errorNormal := by
  intro result step
  cases step with
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

private theorem error_path : NativeSortedModuloACSteps errorSource 1 errorNormal :=
  .step ⟨_, _, .reflexive, .binaryLeft (.primitive .flipA), .reflexive⟩ .reflexive

private theorem other_path : NativeSortedModuloACSteps errorSource 1 otherNormal :=
  .step ⟨_, _, .reflexive, .binaryLeft (.primitive .flipA),
    .binary .reflexive .commutative⟩ .reflexive

example : decodeNativeMessage errorSource = none := rfl

example : NativeQueryAC errorNormal otherNormal :=
  native_sorted_modulo_ac_normal_forms_unique error_path other_path error_normal
    (native_sorted_query_normal_ac_invariant (.binary .reflexive .commutative) error_normal)

example : errorNormal ≠ otherNormal := by
  intro equality
  cases equality

example : ∀ result, ¬ NativeSortedModuloACRewrite otherNormal result :=
  (native_sorted_modulo_ac_normal_iff otherNormal).2
    (native_sorted_query_normal_ac_invariant (.binary .reflexive .commutative) error_normal)

example : ∃ result, NativeSortedSteps errorSource 1 result ∧ NativeQueryAC result otherNormal :=
  native_sorted_modulo_ac_steps_matching other_path

example : MatchingRewrite (.unary .fst (.binary .pair .roleA .roleB)) .roleA := by
  have step : NativeSortedRewrite (.unary .fst (.binary .pair .roleA .roleB)) .roleA :=
    .primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)
  obtain ⟨result, matching, decoded⟩ := native_sorted_rewrite_matching_decode step rfl
  simp only [decodeNativeMessage, Option.some.injEq] at decoded
  subst result
  exact matching

private def frame (term : NativeQueryTerm) : NativeQueryTerm :=
  .list (.cons (.nodeAtom 0) (.cons term .nil))

private theorem frame_rewrite (step : NativeSortedRewrite left right) :
    NativeSortedRewrite (frame left) (frame right) :=
  .list (.consRight (.consLeft step))

private def firstKey : NativeQueryTerm :=
  .binary .pair (.unary .flip .roleA) (.naturalAdd .naturalOne (.naturalAtom 0))

private def secondKey : NativeQueryTerm :=
  .binary .pair (.unary .flip .roleA) (.naturalAdd (.naturalAtom 0) .naturalOne)

private def keyPeak : NativeQueryTerm :=
  .binary .sdec (.binary .senc .roleA firstKey) secondKey

private def partialPeak : NativeQueryTerm :=
  .binary .sdec
    (.binary .senc .roleA (.binary .pair .roleB (.naturalAdd .naturalOne (.naturalAtom 0))))
    secondKey

example : NativeSortedJoinable (frame .roleA) (frame partialPeak) := by
  have root : NativeSortedRewrite keyPeak .roleA :=
    .primitive (.sdec ⟨_, rfl⟩ ⟨_, rfl⟩ (.binary .reflexive .commutative))
  have inside : NativeSortedRewrite keyPeak partialPeak :=
    .binaryLeft (.binaryRight (.binaryLeft (.primitive .flipA)))
  exact native_sorted_matching_confluence
    (.step (frame_rewrite root) .reflexive) (.step (frame_rewrite inside) .reflexive)

example : ∃ result, NativeSortedRewrite
      (.kdf otherNormal (.nodeAtom 0) (.unary .flip .roleA)) result ∧
    NativeQueryAC (.kdf errorNormal (.nodeAtom 0) .roleB) result :=
  native_sorted_query_ac_coherent (.kdfThird (.primitive .flipA))
    (.kdf (.binary .reflexive .commutative) .reflexive .reflexive)

-- Functions inside natural sums are outside the stream grammar, but in the theorem's raw AST.
example (step : NativeSortedRewrite first result) :
    ∃ target, NativeSortedRewrite (.naturalAdd first (.naturalAdd second third)) target ∧
      NativeQueryAC (.naturalAdd (.naturalAdd result second) third) target :=
  native_sorted_query_ac_coherent (.naturalLeft (.naturalLeft step)) .associative

example (step : NativeSortedRewrite third result) :
    ∃ target, NativeSortedRewrite (.naturalAdd (.naturalAdd first second) third) target ∧
      NativeQueryAC (.naturalAdd first (.naturalAdd second result)) target :=
  native_sorted_query_ac_coherent (.naturalRight (.naturalRight step)) (.symmetric .associative)

example : NativeSortedSteps
    (.unary .fst (.binary .pair .roleA
      (.naturalAdd (.unary .fst (.binary .pair .naturalOne .roleA)) .naturalOne))) 2 .roleA :=
  .step (.unary (.binaryRight (.naturalLeft (.primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)))))
    (.step (.primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)) .reflexive)

end Cairn.Equations
