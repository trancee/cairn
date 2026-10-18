import QuerySubstitution

open Cairn.Equations

private def assignment : QuerySubstitution where
  publicAtoms := fun _ => 3
  freshAtoms := fun _ => 7
  messages := fun _ => .roleB
  naturals := fun _ => .add .one .one
  nodes := fun _ => 5

example : encodeNativeNatural (substituteQueryNatural assignment (.variable 1)) =
    substituteNativeQuery (nativeQueryAssignment assignment) (.naturalAtom 0) := by
  rfl

example : substituteNativeQuery (nativeQueryAssignment assignment)
    (.kdf (.queryVariable .publicAtom 0) (.queryVariable .freshAtom 0)
      (.binary .pair (.queryVariable .message 0) (.queryVariable .natural 0))) =
    .kdf (.atom .publicAtom 1) (.atom .freshAtom 3)
      (.binary .pair .roleB (.naturalAdd .naturalOne .naturalOne)) := by
  rfl

example (substitution : QuerySort → Nat → NativeQueryTerm) (index : Nat) :
    substituteNativeQuery substitution
      (.list (.cons (.naturalAtom index) (.cons (.nodeAtom index) .nil))) =
      .list (.cons (.naturalAtom index) (.cons (.nodeAtom index) .nil)) := by
  rfl

example (assignment : QuerySubstitution) (term : MessageTerm) :
    decodeNativeMessage
      (substituteNativeQuery (nativeQueryAssignment assignment) (encodeNativeMessage term)) =
      some (substituteQueryMessage assignment term) :=
  native_message_substitution_image assignment term

example : substituteNativeQuery (nativeQueryAssignment assignment) (.queryVariable .node 0) =
    .nodeAtom 2 := by
  rfl
