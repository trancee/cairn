import QueryTypedInstances

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

example : (composeQuerySubstitutions first second).publicAtoms 0 = 3 := rfl

example : (composeQuerySubstitutions first second).freshAtoms 0 = 3 := rfl

example : (composeQuerySubstitutions first second).messages 0 = .unary .flip .roleA := rfl

example : (composeQuerySubstitutions first second).naturals 0 =
    .add .one (.variable 3) := rfl

example : (composeQuerySubstitutions first second).nodes 0 = 3 := rfl

example : (composeQuerySubstitutions second first).freshAtoms 0 = 1 := rfl

example : substituteQueryMessage (composeQuerySubstitutions first second)
    (.binary .pair (.atom .freshAtom 0) (.atom .freshAtom 1)) =
      .binary .pair (.atom .freshAtom 3) (.atom .freshAtom 1) := rfl

-- Natural AC must be reflected, rather than replaced by syntactic equality.
private def commuted : QuerySubstitution :=
  { second with naturals := fun index => .add (.variable (2 * index + 1)) .one }

example : NativeAssignmentACOn [(.natural, 0), (.message, 0), (.freshAtom, 0),
      (.publicAtom, 0), (.node, 0)]
    (nativeQueryAssignment second) (nativeQueryAssignment commuted) := by
  apply (native_query_assignment_ac_on_iff _ _ _).mpr
  intro sort index _
  cases sort
  all_goals first | exact rfl | exact MessageAC.reflexive | exact NaturalAC.commutative

private theorem fresh_leaf_not_one (value : NativeSortedValue .freshAtom term) :
    nativeQueryLeaf term ≠ some .naturalOne := by
  cases value <;> simp [nativeQueryLeaf]

example : ¬ NativeACInstanceOn [(.freshAtom, 0)] NativeQueryTerm.queryVariable
    (fun _ _ => .naturalOne) := by
  rintro ⟨factor, sorted, equivalent⟩
  have leaf := native_query_ac_leaf (equivalent .freshAtom 0 (by simp))
  change nativeQueryLeaf .naturalOne = nativeQueryLeaf (factor .freshAtom 0) at leaf
  exact fresh_leaf_not_one (sorted .freshAtom 0) leaf.symm

end Cairn.Equations
