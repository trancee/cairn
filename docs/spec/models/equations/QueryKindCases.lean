import QueryKind

namespace Cairn.Equations

example : relabelNative kindExpansion
    (relabelNative kindAbstraction (.atom .freshAtom 0)) = .atom .freshAtom 0 := by
  rfl

example : relabelNative kindExpansion
    (relabelNative kindAbstraction (.queryVariable .freshAtom 0)) =
      .queryVariable .freshAtom 0 := by
  rfl

example : NativeKindFramedImage
    (.naturalAdd (.queryVariable .freshAtom 0) (.naturalAtom 0)) := by
  exact .message rfl

example : ¬ NativeKindFramedImage (.naturalAdd .roleA .naturalOne) := by
  intro image
  cases image with
  | message decoded =>
    simp [relabelNative, decodeNativeMessage, decodeNativeNatural] at decoded

example : NativeQueryAC
    (.naturalAdd (.queryVariable .freshAtom 0) (.naturalAtom 0))
    (.naturalAdd (.naturalAtom 0) (.queryVariable .freshAtom 0)) :=
  .commutative

example : NativeKindFramedImage
    (.binary .pair .roleB (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne)) := by
  apply native_kind_framed_rewrite
    (NativeRewrite.binaryLeft (NativeRewrite.primitive NativePrimitiveRewrite.flipA))
  exact .message rfl

example : decodeNativeMessage
    (.unary .fst (.binary .pair .roleA
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne))) = none := by
  rfl

example : NativeRewrite
    (.unary .fst (.binary .pair .roleA
      (.naturalAdd (.queryVariable .freshAtom 0) .naturalOne))) .roleA :=
  .primitive .fst

end Cairn.Equations
