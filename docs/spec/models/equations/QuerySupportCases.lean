import QuerySupport

namespace Cairn.Equations

private def replacements : QuerySort → Nat → NativeQueryTerm
  | .publicAtom, _ => .atom .publicAtom 7
  | .freshAtom, _ => .queryVariable .freshAtom 1
  | .message, 0 => .queryVariable .message 1
  | .message, _ => .roleA
  | .natural, _ => .naturalAdd .naturalOne .naturalOne
  | .node, _ => .nodeAtom 9

example : substituteNativeQuery
    (restrictNativeAssignment
      [(.publicAtom, 0), (.freshAtom, 0), (.message, 0), (.natural, 0), (.node, 0)] replacements)
    (.list (.cons (.queryVariable .publicAtom 0)
      (.cons (.queryVariable .freshAtom 0)
        (.cons (.kdf (.queryVariable .message 0) (.queryVariable .natural 0) .roleB)
          (.cons (.queryVariable .node 0) .nil))))) =
      .list (.cons (.atom .publicAtom 7) (.cons (.queryVariable .freshAtom 1)
        (.cons (.kdf (.queryVariable .message 1) (.naturalAdd .naturalOne .naturalOne) .roleB)
          (.cons (.nodeAtom 9) .nil)))) := rfl

example : substituteNativeQuery (restrictNativeAssignment [(.message, 0)] replacements)
    (.cons (.queryVariable .message 0) (.cons (.queryVariable .natural 0) .nil)) =
      .cons (.queryVariable .message 1) (.cons (.queryVariable .natural 0) .nil) := rfl

example : substituteNativeQuery (restrictNativeAssignment [(.publicAtom, 0), (.natural, 0),
    (.node, 0)] replacements)
    (.cons (.atom .publicAtom 0) (.cons (.naturalAtom 0) (.cons (.nodeAtom 0) .nil))) =
      .cons (.atom .publicAtom 0) (.cons (.naturalAtom 0) (.cons (.nodeAtom 0) .nil)) := rfl

example : nativeBindingAssignment
    [((.message, 0), .roleA), ((.message, 0), .roleB)] .message 0 = .roleA := rfl

example : nativeBindingAssignment [((.message, 0), .queryVariable .message 1),
    ((.message, 1), .roleA)] .message 0 = .queryVariable .message 1 := rfl

example : nativeBindingAssignment [] .node 8 = .queryVariable .node 8 := rfl

example : NativeAssignmentSupportedOn [(.message, 0), (.message, 0)]
    (restrictNativeAssignment [(.message, 0), (.message, 0)] replacements) :=
  native_restriction_supported _ _

example : NativeFiniteAssignment (restrictNativeAssignment [(.message, 0)] replacements) :=
  native_restriction_finite _ _

example : ¬ NativeSortedAssignment (restrictNativeAssignment [(.freshAtom, 0)]
    (fun _ _ => .naturalOne)) := by
  intro sorted
  have value := sorted .freshAtom 0
  change NativeSortedValue .freshAtom .naturalOne at value
  cases value

end Cairn.Equations
