import QueryFraming

open Cairn.Equations

example : ¬ NativeFramedImage (.unary .hash (.list .nil)) := by
  intro image
  cases image with
  | message decoded => simp [decodeNativeMessage] at decoded

example : ¬ NativeFramedImage (.naturalAdd (.queryVariable .node 0) .naturalOne) := by
  intro image
  cases image with
  | message decoded => simp [decodeNativeMessage, decodeNativeNatural] at decoded

example : NativeFramedImage
    (.list (.cons (.nodeAtom 0) (.cons (.unary .flip .roleA) .nil))) :=
  .list (.cons .nodeAtom (.cons (.message rfl) .nil))

example : NativeRewrite
    (.list (.cons (.nodeAtom 0) (.cons (.unary .flip .roleA) .nil)))
    (.list (.cons (.nodeAtom 0) (.cons .roleB .nil))) :=
  .list (.consRight (.consLeft (.primitive .flipA)))

example (rewrite : NativeModuloACRewrite left right) (image : NativeFramedImage left) :
    NativeFramedImage right := by
  obtain ⟨_, _, first, step, second⟩ := rewrite
  exact (native_framed_ac second).1
    (native_framed_rewrite step ((native_framed_ac first).1 image))
