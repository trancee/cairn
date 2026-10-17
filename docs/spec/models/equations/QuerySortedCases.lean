import QuerySortedConvergence

namespace Cairn.Equations

example : ¬ NativeSortedRewrite
    (.unary .fst (.binary .pair .roleA
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne))) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | fst _ discarded =>
      obtain ⟨_, decoded⟩ := discarded
      simp [decodeNativeMessage, decodeNativeNatural] at decoded

example : ¬ NativeSortedRewrite
    (.unary .fst (.binary .pair .roleA (.nodeAtom 0))) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | fst _ discarded =>
      obtain ⟨_, decoded⟩ := discarded
      simp [decodeNativeMessage] at decoded

example : ¬ NativeSortedRewrite
    (.unary .fst (.binary .pair .roleA (.list .nil))) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | fst _ discarded =>
      obtain ⟨_, decoded⟩ := discarded
      simp [decodeNativeMessage] at decoded

example : NativeSortedRewrite
    (.unary .fst (.binary .pair .roleA (.queryVariable .freshAtom 0))) .roleA :=
  .primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)

example : NativeSortedRewrite
    (.unary .fst (.binary .pair (.unary .flip .roleA)
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne)))
    (.unary .fst (.binary .pair .roleB
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne))) :=
  .unary (.binaryLeft (.primitive .flipA))

example : NativeSortedRewrite
    (.binary .sdec (.binary .senc .roleA (.naturalAdd .naturalOne (.naturalAtom 0)))
      (.naturalAdd (.naturalAtom 0) .naturalOne)) .roleA :=
  .primitive (.sdec ⟨_, rfl⟩ ⟨_, rfl⟩ .commutative)

example : ¬ NativeSortedRewrite
    (.unary .snd (.binary .pair
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne) .roleA)) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | snd discarded _ =>
      obtain ⟨_, decoded⟩ := discarded
      simp [decodeNativeMessage, decodeNativeNatural] at decoded

example : ¬ NativeSortedRewrite
    (.binary .sdec
      (.binary .senc .roleA (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne))
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne)) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | sdec _ key _ =>
      obtain ⟨_, decoded⟩ := key
      simp [decodeNativeMessage, decodeNativeNatural] at decoded

example : ¬ NativeSortedRewrite
    (.binary .kdec
      (.binary .kem .roleA (.unary .pk
        (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne)))
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne)) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | kdec _ key _ =>
      obtain ⟨_, decoded⟩ := key
      simp [decodeNativeMessage, decodeNativeNatural] at decoded

example : NativeSortedRewrite (.unary .flip .roleB) .roleA := .primitive .flipB

example : NativeSortedRewrite (.unary .snd (.binary .pair .roleA .naturalOne)) .naturalOne :=
  .primitive (.snd ⟨_, rfl⟩ ⟨_, rfl⟩)

example : NativeSortedRewrite
    (.binary .kdec (.binary .kem (.queryVariable .freshAtom 0)
      (.unary .pk (.naturalAdd .naturalOne (.naturalAtom 0))))
      (.naturalAdd (.naturalAtom 0) .naturalOne)) (.queryVariable .freshAtom 0) :=
  .primitive (.kdec ⟨_, rfl⟩ ⟨_, rfl⟩ .commutative)

example : ∃ count result, count ≤ 3 ∧
    NativeSortedSteps
      (.unary .flip (.unary .fst (.binary .pair .roleA (.queryVariable .message 0))))
      count result ∧ NativeSortedNormal result := by
  simpa [encodeNativeMessage, atomQuerySort, instantiateTemplate, templateFunctionCount] using
    native_sorted_normalized_substitution_bound
      (.unary .flip (.unary .fst (.binary .pair .roleA (.messageVariable 0))))
      (fun _ => .atom .messageAtom 0) (fun index => .variable index)
      (by
        intro identifier
        apply (native_sorted_normal_iff _).2
        intro result step
        cases step with
        | primitive root => cases root)

example : ∃ leftResult rightResult leftCount rightCount,
    NativeSortedSteps .roleA leftCount leftResult ∧
    NativeSortedSteps
      (.binary .sdec (.binary .senc .roleA .roleB) (.unary .flip .roleA))
      rightCount rightResult ∧ NativeQueryAC leftResult rightResult := by
  have first : NativeSortedSteps
      (.binary .sdec (.binary .senc .roleA (.unary .flip .roleA)) (.unary .flip .roleA))
      1 .roleA :=
    .step (.primitive (.sdec ⟨_, rfl⟩ ⟨_, rfl⟩ .reflexive)) .reflexive
  have second : NativeSortedSteps
      (.binary .sdec (.binary .senc .roleA (.unary .flip .roleA)) (.unary .flip .roleA))
      1 (.binary .sdec (.binary .senc .roleA .roleB) (.unary .flip .roleA)) :=
    .step (.binaryLeft (.binaryRight (.primitive .flipA))) .reflexive
  exact native_sorted_confluence first second rfl

end Cairn.Equations
