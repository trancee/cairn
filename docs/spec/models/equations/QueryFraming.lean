import QuerySubstitution

namespace Cairn.Equations

inductive NativeFramedImage : NativeQueryTerm → Prop where
  | message : decodeNativeMessage term = some message → NativeFramedImage term
  | nodeAtom : NativeFramedImage (.nodeAtom index)
  | nodeVariable : NativeFramedImage (.queryVariable .node index)
  | nil : NativeFramedImage .nil
  | list : NativeFramedImage argument → NativeFramedImage (.list argument)
  | cons : NativeFramedImage first → NativeFramedImage rest → NativeFramedImage (.cons first rest)

private theorem framed_message_ac (equivalent : NativeQueryAC left right)
    (decoded : decodeNativeMessage left = some message) : NativeFramedImage right := by
  obtain ⟨_, recognized, _⟩ := native_ac_message_image equivalent decoded
  exact .message recognized

theorem native_framed_ac (equivalent : NativeQueryAC left right) :
    (NativeFramedImage left → NativeFramedImage right) ∧
    (NativeFramedImage right → NativeFramedImage left) := by
  induction equivalent with
  | reflexive => exact ⟨id, id⟩
  | symmetric _ induction => exact ⟨induction.2, induction.1⟩
  | transitive _ _ first second =>
    exact ⟨fun image => second.1 (first.1 image), fun image => first.2 (second.2 image)⟩
  | associative =>
    constructor
    · intro image; cases image with
      | message decoded => exact framed_message_ac .associative decoded
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.symmetric .associative) decoded
  | commutative =>
    constructor
    · intro image; cases image with
      | message decoded => exact framed_message_ac .commutative decoded
    · intro image; cases image with
      | message decoded => exact framed_message_ac .commutative decoded
  | naturalAdd first second =>
    constructor
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.naturalAdd first second) decoded
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.symmetric (.naturalAdd first second)) decoded
  | unary step =>
    constructor
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.unary step) decoded
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.symmetric (.unary step)) decoded
  | binary first second =>
    constructor
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.binary first second) decoded
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.symmetric (.binary first second)) decoded
  | kdf first second third =>
    constructor
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.kdf first second third) decoded
    · intro image; cases image with
      | message decoded => exact framed_message_ac (.symmetric (.kdf first second third)) decoded
  | list step induction =>
    constructor
    · intro image; cases image with
      | message decoded => simp [decodeNativeMessage] at decoded
      | list child => exact .list (induction.1 child)
    · intro image; cases image with
      | message decoded => simp [decodeNativeMessage] at decoded
      | list child => exact .list (induction.2 child)
  | cons firstStep secondStep first second =>
    constructor
    · intro image; cases image with
      | message decoded => simp [decodeNativeMessage] at decoded
      | cons left right => exact .cons (first.1 left) (second.1 right)
    · intro image; cases image with
      | message decoded => simp [decodeNativeMessage] at decoded
      | cons left right => exact .cons (first.2 left) (second.2 right)

private theorem framed_message_rewrite (rewrite : NativeRewrite left right)
    (decoded : decodeNativeMessage left = some message) : NativeFramedImage right := by
  obtain ⟨_, _, recognized⟩ := native_rewrite_decode rewrite decoded
  exact .message recognized

theorem native_framed_rewrite (rewrite : NativeRewrite left right)
    (image : NativeFramedImage left) : NativeFramedImage right := by
  induction rewrite with
  | primitive step =>
    have rewrite := NativeRewrite.primitive step
    cases step <;> cases image with
      | message decoded => exact framed_message_rewrite rewrite decoded
  | unary step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.unary step) decoded
  | binaryLeft step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.binaryLeft step) decoded
  | binaryRight step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.binaryRight step) decoded
  | kdfFirst step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.kdfFirst step) decoded
  | kdfSecond step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.kdfSecond step) decoded
  | kdfThird step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.kdfThird step) decoded
  | naturalLeft step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.naturalLeft step) decoded
  | naturalRight step =>
    cases image with
    | message decoded => exact framed_message_rewrite (.naturalRight step) decoded
  | list step induction =>
    cases image with
    | message decoded => simp [decodeNativeMessage] at decoded
    | list child => exact .list (induction child)
  | consLeft step induction =>
    cases image with
    | message decoded => simp [decodeNativeMessage] at decoded
    | cons left right => exact .cons (induction left) right
  | consRight step induction =>
    cases image with
    | message decoded => simp [decodeNativeMessage] at decoded
    | cons left right => exact .cons left (induction right)

theorem native_framed_substitution (assignment : QuerySubstitution)
    (image : NativeFramedImage term) :
    NativeFramedImage (substituteNativeQuery (nativeQueryAssignment assignment) term) := by
  induction image with
  | @message term message decoded =>
    rw [← native_message_recognition term decoded]
    exact .message (native_message_substitution_image assignment message)
  | nodeAtom => exact .nodeAtom
  | nodeVariable =>
    simp only [substituteNativeQuery, nativeQueryAssignment]
    split
    · exact .nodeVariable
    · exact .nodeAtom
  | nil => exact .nil
  | list _ induction => exact .list induction
  | cons _ _ first second => exact .cons first second

#print axioms native_framed_ac
#print axioms native_framed_rewrite
#print axioms native_framed_substitution

end Cairn.Equations
