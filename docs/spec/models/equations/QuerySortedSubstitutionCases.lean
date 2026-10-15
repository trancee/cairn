import QueryKindSubstitution

namespace Cairn.Equations

example : ¬ NativeSortedValue .publicAtom (.atom .freshAtom 0) := by
  intro value
  cases value

example : ¬ NativeSortedValue .freshAtom (.queryVariable .message 0) := by
  intro value
  cases value

example : ¬ NativeSortedValue .natural (.queryVariable .freshAtom 0) := by
  intro value
  cases value with
  | natural decoded => simp [decodeNativeNatural] at decoded

example : ¬ NativeSortedValue .message (.list .nil) := by
  intro value
  cases value with
  | message decoded => simp [decodeNativeMessage] at decoded

example : ¬ NativeSortedValue .node (.list .nil) := by
  intro value
  cases value

example : ¬ NativeSortedValue .natural
    (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne) := by
  intro value
  cases value with
  | natural decoded => simp [decodeNativeNatural] at decoded

private def typed : QuerySubstitution where
  publicAtoms index := 2 * index
  freshAtoms index := 2 * index + 1
  messages index := .unary .flip (.atom .freshAtom (2 * index + 1))
  naturals index := .add .one (.variable (2 * index + 1))
  nodes index := 2 * index + 1

private def assignment := nativeQueryAssignment typed

private theorem sorted_assignment : NativeSortedAssignment assignment :=
  native_typed_assignment_sorted typed

example : substituteNativeQuery assignment
      (.binary .pair (.queryVariable .natural 7) (.naturalAtom 7)) =
    .binary .pair (.naturalAdd .naturalOne (.naturalAtom 7)) (.naturalAtom 7) := rfl

example : substituteNativeQuery assignment (.queryVariable .message 0) =
    .unary .flip (.atom .freshAtom 0) := rfl

example : abstractKindAssignment assignment .natural 0 =
    .naturalAdd .naturalOne (.naturalAtom 0) := rfl

example : abstractKindAssignment assignment .natural 1 = .naturalAtom 1 := rfl

example : ∃ shadow : QuerySubstitution,
    abstractKindAssignment assignment = nativeQueryAssignment shadow :=
  native_kind_shadow_representation sorted_assignment

private def blocked : NativeQueryTerm :=
  .unary .fst (.binary .pair (.unary .flip .roleA)
    (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne))

private def framed : NativeQueryTerm :=
  .list (.cons (.queryVariable .node 0) (.cons blocked .nil))

example : NativeKindFramedImage (substituteNativeQuery assignment framed) := by
  have image : NativeKindFramedImage framed :=
    .list (.cons .nodeVariable (.cons (.message rfl) .nil))
  exact native_kind_sorted_framed_substitution sorted_assignment image

example : ¬ NativeSortedRewrite (substituteNativeQuery assignment blocked)
    (.unary .flip .roleA) := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | fst _ discarded =>
      obtain ⟨_, decoded⟩ := discarded
      simp [assignment, typed, substituteNativeQuery, nativeQueryAssignment, encodeNativeMessage,
        decodeNativeMessage, decodeNativeNatural] at decoded

example : NativeSortedSteps
    (substituteNativeQuery assignment
      (.unary .fst (.binary .pair (.unary .flip .roleA) (.queryVariable .message 0))))
    2 .roleB := by
  have steps : NativeSortedSteps
      (.unary .fst (.binary .pair (.unary .flip .roleA) (.queryVariable .message 0)))
      2 .roleB :=
    .step (.primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)) (.step (.primitive .flipA) .reflexive)
  exact native_sorted_steps_substitution sorted_assignment steps

example : NativeSortedModuloACSteps
    (substituteNativeQuery assignment
      (.binary .sdec
        (.binary .senc (.queryVariable .freshAtom 0)
          (.naturalAdd .naturalOne (.queryVariable .natural 0)))
        (.naturalAdd (.queryVariable .natural 0) .naturalOne)))
    1 (.atom .freshAtom 0) := by
  have steps : NativeSortedModuloACSteps
      (.binary .sdec
        (.binary .senc (.queryVariable .freshAtom 0)
          (.naturalAdd .naturalOne (.queryVariable .natural 0)))
        (.naturalAdd (.queryVariable .natural 0) .naturalOne))
      1 (.queryVariable .freshAtom 0) :=
    .step ⟨_, _, .reflexive, .primitive (.sdec ⟨_, rfl⟩ ⟨_, rfl⟩ .commutative),
      .reflexive⟩ .reflexive
  exact native_sorted_modulo_ac_steps_substitution sorted_assignment steps

private def enabling : QuerySubstitution where
  publicAtoms index := 2 * index
  freshAtoms index := 2 * index
  messages _ := .binary .pair .roleA .roleB
  naturals index := .variable (2 * index)
  nodes index := 2 * index

-- Even normal, well-sorted assignments can create a new root redex.
example : NativeSortedNormal (.unary .fst (.queryVariable .message 0)) := by
  intro result step
  cases step with
  | primitive root => cases root
  | unary child =>
    cases child with
    | primitive root => cases root

example : NativeSortedRewrite
    (substituteNativeQuery (nativeQueryAssignment enabling)
      (.unary .fst (.queryVariable .message 0))) .roleA :=
  .primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)

-- Without the sorted premise, a substitution can destroy a guarded match.
example : ¬ NativeSortedRewrite
    (substituteNativeQuery (fun _ _ => .nodeAtom 0)
      (.unary .fst (.binary .pair .roleA (.queryVariable .message 0)))) .roleA := by
  intro step
  cases step with
  | primitive root =>
    cases root with
    | fst _ discarded =>
      obtain ⟨_, decoded⟩ := discarded
      simp [substituteNativeQuery, decodeNativeMessage] at decoded

end Cairn.Equations
