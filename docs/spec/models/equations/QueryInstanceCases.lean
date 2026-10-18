import QueryInstances

namespace Cairn.Equations

example : nativeQueryVariables
    (.kdf (.queryVariable .message 0)
      (.naturalAdd (.queryVariable .natural 0) .naturalOne)
      (.list (.cons (.queryVariable .node 0)
        (.cons (.queryVariable .freshAtom 0) (.queryVariable .publicAtom 0))))) =
      [(.message, 0), (.natural, 0), (.node, 0), (.freshAtom, 0), (.publicAtom, 0)] := rfl

example : nativeQueryVariables
    (.binary .pair (.atom .freshAtom 7) (.naturalAtom 7)) = [] := rfl

-- Equal query bindings suffice despite different assignments outside the query.
private def general : QuerySort → Nat → NativeQueryTerm := NativeQueryTerm.queryVariable

private def specific : QuerySort → Nat → NativeQueryTerm
  | .message, 9 => .roleB
  | sort, index => .queryVariable sort index

example : NativeAssignmentACOn [(.natural, 0)] general specific := by
  intro sort index member
  simp only [List.mem_singleton, Prod.mk.injEq] at member
  obtain ⟨rfl, rfl⟩ := member
  exact .reflexive

example : general .message 9 ≠ specific .message 9 := by
  intro equal
  cases equal

example : NativeACInstanceOn [(.natural, 0)] general general :=
  native_ac_instance_reflexive _ _

end Cairn.Equations
