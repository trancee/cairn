import QueryOccurs

namespace Cairn.Equations

private def messageVariable : NativeQueryTerm := .queryVariable .message 0
private def naturalVariable : NativeQueryTerm := .queryVariable .natural 0

example : NativeACUnifier messageVariable messageVariable NativeQueryTerm.queryVariable :=
  ⟨native_identity_assignment_sorted, .reflexive⟩

example : (.message, 0) ∉ nativeQueryVariables naturalVariable := by decide

example : (.freshAtom, 0) ∉ nativeQueryVariables (.atom .freshAtom 0) := by decide

example : NativeCompleteACUnifiers messageVariable (.unary .hash messageVariable) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example (symbol : BinarySymbol) (other : NativeQueryTerm) :
    NativeCompleteACUnifiers messageVariable (.binary symbol messageVariable other) [] :=
  native_occurs_complete_empty_family (by simp [messageVariable, nativeQueryVariables])
    (by intro equal; cases equal)

example (symbol : BinarySymbol) (other : NativeQueryTerm) :
    NativeCompleteACUnifiers messageVariable (.binary symbol other messageVariable) [] :=
  native_occurs_complete_empty_family (by simp [messageVariable, nativeQueryVariables])
    (by intro equal; cases equal)

example : NativeCompleteACUnifiers naturalVariable
    (.naturalAdd naturalVariable .naturalOne) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers naturalVariable
    (.naturalAdd .naturalOne naturalVariable) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers naturalVariable
    (.naturalAdd naturalVariable naturalVariable) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers naturalVariable
    (.naturalAdd (.naturalAdd .naturalOne naturalVariable) .naturalOne) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers messageVariable
    (.kdf messageVariable .roleA .roleB) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers messageVariable
    (.kdf .roleA messageVariable .roleB) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers messageVariable
    (.kdf .roleA .roleB messageVariable) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers (.queryVariable .node 0)
    (.list (.cons .roleA (.cons (.queryVariable .node 0) .nil))) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeCompleteACUnifiers (.queryVariable .freshAtom 0)
    (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne) [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

private def projectionCycle : NativeQueryTerm :=
  .unary .fst (.binary .pair messageVariable .roleA)

-- AC rejection is not equational rejection: the source projection removes the cycle.
example : NativeCompleteACUnifiers messageVariable projectionCycle [] :=
  native_occurs_complete_empty_family (by decide) (by intro equal; cases equal)

example : NativeSortedRewrite projectionCycle messageVariable :=
  .primitive (.fst ⟨_, rfl⟩ ⟨_, rfl⟩)

end Cairn.Equations
