import QueryAC

open Cairn.Equations

example : NativeQueryAC
    (.naturalAdd (.naturalAtom 0) (.queryVariable .natural 7))
    (.naturalAdd (.queryVariable .natural 7) (.naturalAtom 0)) := by
  exact .commutative

example : NativeQueryAC
    (.unary .hash (.naturalAdd (.naturalAtom 0) (.queryVariable .natural 7)))
    (.unary .hash (.naturalAdd (.queryVariable .natural 7) (.naturalAtom 0))) :=
  .unary .commutative

example (equivalent : NativeQueryAC
    (.naturalAdd (.queryVariable .node 0) (.naturalAtom 1)) right) :
    decodeNativeMessage right = none := by
  cases decoded : decodeNativeMessage right with
  | none => rfl
  | some term =>
    obtain ⟨result, resultDecoded, _⟩ :=
      native_ac_message_image (.symmetric equivalent) decoded
    simp [decodeNativeMessage, decodeNativeNatural] at resultDecoded
