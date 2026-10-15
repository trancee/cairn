import QueryUnification

namespace Cairn.Equations

private def first : QuerySubstitution where
  publicAtoms index := 2 * (index + 1)
  freshAtoms index := 2 * (index + 1)
  messages index := .atom .messageAtom (2 * (index + 1))
  naturals index := .variable (2 * (index + 1))
  nodes index := 2 * (index + 1)

private def second : QuerySubstitution where
  publicAtoms index := 2 * index + 1
  freshAtoms index := 2 * index + 1
  messages _ := .unary .flip .roleA
  naturals index := .add .one (.variable (2 * index + 1))
  nodes index := 2 * index + 1

example : NativeSortedAssignment
    (composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)) :=
  native_sorted_composition (native_typed_assignment_sorted first)
    (native_typed_assignment_sorted second)

example : composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)
    .publicAtom 0 = .atom .publicAtom 1 := rfl

example : composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)
    .freshAtom 0 = .atom .freshAtom 1 := rfl

example : composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)
    .message 0 = .unary .flip .roleA := rfl

example : composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)
    .natural 0 = .naturalAdd .naturalOne (.naturalAtom 1) := rfl

example : composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)
    .node 0 = .nodeAtom 1 := rfl

example : composeNativeAssignments (nativeQueryAssignment second) (nativeQueryAssignment first)
    .freshAtom 0 = .atom .freshAtom 0 := rfl

example : substituteNativeQuery
    (composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second))
    (.binary .pair (.queryVariable .natural 0) (.naturalAtom 0)) =
      .binary .pair (.naturalAdd .naturalOne (.naturalAtom 1)) (.naturalAtom 0) := rfl

private def leftAC : QuerySubstitution :=
  { first with naturals := fun _ => .add .one (.variable 1) }

private def rightAC : QuerySubstitution :=
  { first with naturals := fun _ => .add (.variable 1) .one }

private theorem pointwise_ac :
    NativeAssignmentAC (nativeQueryAssignment leftAC) (nativeQueryAssignment rightAC) := by
  intro sort index
  cases sort
  all_goals first | exact .reflexive | exact .commutative

example : NativeQueryAC
    (substituteNativeQuery (nativeQueryAssignment leftAC)
      (.list (.cons (.queryVariable .node 0)
        (.kdf (.queryVariable .message 0) (.queryVariable .natural 0) (.queryVariable .freshAtom 0)))))
    (substituteNativeQuery (nativeQueryAssignment rightAC)
      (.list (.cons (.queryVariable .node 0)
        (.kdf (.queryVariable .message 0) (.queryVariable .natural 0) (.queryVariable .freshAtom 0))))) :=
  native_substitution_assignment_ac pointwise_ac _

example : NativeACUnifier
    (.naturalAdd .naturalOne (.queryVariable .natural 0))
    (.naturalAdd (.queryVariable .natural 0) .naturalOne)
    (nativeQueryAssignment second) :=
  ⟨native_typed_assignment_sorted second, .commutative⟩

example : ∃ typed : QuerySubstitution,
    nativeQueryAssignment typed = nativeQueryAssignment second ∧
      MessageAC
        (substituteQueryMessage typed (.binary .pair (.atom .messageAtom 0) (.natural (.variable 0))))
        (substituteQueryMessage typed
          (.binary .pair (.unary .flip .roleA) (.natural (.add .one (.variable 1))))) := by
  apply native_message_ac_unifier_representation
  exact ⟨native_typed_assignment_sorted second, .reflexive⟩

example : NativeACUnifier
    (.naturalAdd .naturalOne (.queryVariable .natural 0))
    (.naturalAdd (.queryVariable .natural 0) .naturalOne)
    (composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second)) :=
  native_ac_unifier_composition ⟨native_typed_assignment_sorted first, .commutative⟩
    (native_typed_assignment_sorted second)

-- AC equality does not include the ordinary flip equation.
example : ¬ NativeACUnifier (.unary .flip .roleA) .roleB assignment := by
  intro solution
  have count := native_query_ac_preserves_count solution.2
  simp [substituteNativeQuery, nativeQueryFunctionCount] at count

private theorem fresh_not_natural (value : NativeSortedValue .freshAtom term) :
    decodeNativeNatural term = none := by
  cases value <;> rfl

example : ¬ ∃ assignment, NativeACUnifier
    (.queryVariable .freshAtom 0) (.queryVariable .natural 0) assignment := by
  rintro ⟨assignment, sorted, equivalent⟩
  have natural := sorted .natural 0
  cases natural with
  | natural decoded =>
    obtain ⟨_, image, _⟩ := native_ac_natural_image (.symmetric equivalent) decoded
    simp only [substituteNativeQuery] at image
    rw [fresh_not_natural (sorted .freshAtom 0)] at image
    cases image

-- An unrestricted natural shadow has a solution forbidden by the original sorts.
private def unrestrictedShadow : QuerySubstitution :=
  { first with naturals := fun _ => .one }

example : NativeACUnifier
    (relabelNative kindAbstraction (.queryVariable .freshAtom 0))
    (relabelNative kindAbstraction (.queryVariable .natural 0))
    (nativeQueryAssignment unrestrictedShadow) :=
  ⟨native_typed_assignment_sorted unrestrictedShadow, .reflexive⟩

private theorem abstract_fresh_ne_one (value : NativeSortedValue .freshAtom term) :
    relabelNative kindAbstraction term ≠ .naturalOne := by
  cases value <;> simp [relabelNative, kindAbstraction]

example : ¬ ∃ assignment, NativeSortedAssignment assignment ∧
    abstractKindAssignment assignment = nativeQueryAssignment unrestrictedShadow := by
  rintro ⟨assignment, sorted, compatible⟩
  have odd := congrArg (fun replacement => replacement .natural 1) compatible
  change relabelNative kindAbstraction (assignment .freshAtom 0) = .naturalOne at odd
  exact abstract_fresh_ne_one (sorted .freshAtom 0) odd

example : ∃ shadow : QuerySubstitution,
    abstractKindAssignment (nativeQueryAssignment second) = nativeQueryAssignment shadow ∧
      MessageAC
        (substituteQueryMessage shadow (.natural (.add (.variable 2) (.variable 0))))
        (substituteQueryMessage shadow (.natural (.add (.variable 0) (.variable 2)))) := by
  apply native_kind_ac_unifier_representation
    (left := .naturalAdd (.queryVariable .freshAtom 0) (.queryVariable .natural 0))
    (right := .naturalAdd (.queryVariable .natural 0) (.queryVariable .freshAtom 0))
  · exact ⟨native_typed_assignment_sorted second, .commutative⟩
  · rfl
  · rfl

end Cairn.Equations
