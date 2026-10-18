import Coherence
import QueryKind

namespace Cairn.Equations

def NativeProperMessage (term : NativeQueryTerm) : Prop :=
  ∃ message, decodeNativeMessage term = some message

-- These are native Msg-pattern guards, not the unguarded shadow rules.
inductive NativeSortedPrimitiveRewrite : NativeQueryTerm → NativeQueryTerm → Prop where
  | flipA : NativeSortedPrimitiveRewrite (.unary .flip .roleA) .roleB
  | flipB : NativeSortedPrimitiveRewrite (.unary .flip .roleB) .roleA
  | fst : NativeProperMessage left → NativeProperMessage right →
      NativeSortedPrimitiveRewrite (.unary .fst (.binary .pair left right)) left
  | snd : NativeProperMessage left → NativeProperMessage right →
      NativeSortedPrimitiveRewrite (.unary .snd (.binary .pair left right)) right
  | sdec : NativeProperMessage payload → NativeProperMessage firstKey →
      NativeQueryAC firstKey secondKey →
      NativeSortedPrimitiveRewrite
        (.binary .sdec (.binary .senc payload firstKey) secondKey) payload
  | kdec : NativeProperMessage payload → NativeProperMessage firstKey →
      NativeQueryAC firstKey secondKey →
      NativeSortedPrimitiveRewrite
        (.binary .kdec (.binary .kem payload (.unary .pk firstKey)) secondKey) payload

inductive NativeSortedRewrite : NativeQueryTerm → NativeQueryTerm → Prop where
  | primitive : NativeSortedPrimitiveRewrite left right → NativeSortedRewrite left right
  | unary : NativeSortedRewrite left right →
      NativeSortedRewrite (.unary symbol left) (.unary symbol right)
  | binaryLeft : NativeSortedRewrite left right →
      NativeSortedRewrite (.binary symbol left other) (.binary symbol right other)
  | binaryRight : NativeSortedRewrite left right →
      NativeSortedRewrite (.binary symbol other left) (.binary symbol other right)
  | kdfFirst : NativeSortedRewrite left right →
      NativeSortedRewrite (.kdf left second third) (.kdf right second third)
  | kdfSecond : NativeSortedRewrite left right →
      NativeSortedRewrite (.kdf first left third) (.kdf first right third)
  | kdfThird : NativeSortedRewrite left right →
      NativeSortedRewrite (.kdf first second left) (.kdf first second right)
  | naturalLeft : NativeSortedRewrite left right →
      NativeSortedRewrite (.naturalAdd left other) (.naturalAdd right other)
  | naturalRight : NativeSortedRewrite left right →
      NativeSortedRewrite (.naturalAdd other left) (.naturalAdd other right)
  | list : NativeSortedRewrite left right → NativeSortedRewrite (.list left) (.list right)
  | consLeft : NativeSortedRewrite left right →
      NativeSortedRewrite (.cons left other) (.cons right other)
  | consRight : NativeSortedRewrite left right →
      NativeSortedRewrite (.cons other left) (.cons other right)

private theorem native_sorted_primitive_preservation (step : MatchingPrimitiveRewrite left right) :
    NativeSortedPrimitiveRewrite (encodeNativeMessage left) (encodeNativeMessage right) := by
  cases step with
  | flipA => exact .flipA
  | flipB => exact .flipB
  | fst => exact .fst ⟨_, native_message_round_trip _⟩ ⟨_, native_message_round_trip _⟩
  | snd => exact .snd ⟨_, native_message_round_trip _⟩ ⟨_, native_message_round_trip _⟩
  | sdec equivalent =>
    exact .sdec ⟨_, native_message_round_trip _⟩ ⟨_, native_message_round_trip _⟩
      (native_message_ac_preservation equivalent)
  | kdec equivalent =>
    exact .kdec ⟨_, native_message_round_trip _⟩ ⟨_, native_message_round_trip _⟩
      (native_message_ac_preservation equivalent)

theorem native_sorted_matching_preservation (step : MatchingRewrite left right) :
    NativeSortedRewrite (encodeNativeMessage left) (encodeNativeMessage right) := by
  induction step with
  | primitive step => exact .primitive (native_sorted_primitive_preservation step)
  | unary _ induction => exact .unary induction
  | binaryLeft _ induction => exact .binaryLeft induction
  | binaryRight _ induction => exact .binaryRight induction
  | kdfFirst _ induction => exact .kdfFirst induction
  | kdfSecond _ induction => exact .kdfSecond induction
  | kdfThird _ induction => exact .kdfThird induction

private theorem native_sorted_primitive_modulo_ac
    (step : NativeSortedPrimitiveRewrite left right) : NativeModuloACRewrite left right := by
  cases step with
  | flipA => exact ⟨_, _, .reflexive, .primitive .flipA, .reflexive⟩
  | flipB => exact ⟨_, _, .reflexive, .primitive .flipB, .reflexive⟩
  | fst => exact ⟨_, _, .reflexive, .primitive .fst, .reflexive⟩
  | snd => exact ⟨_, _, .reflexive, .primitive .snd, .reflexive⟩
  | sdec _ _ equivalent =>
    exact ⟨_, _, .binary .reflexive (.symmetric equivalent), .primitive .sdec, .reflexive⟩
  | kdec _ _ equivalent =>
    exact ⟨_, _, .binary .reflexive (.symmetric equivalent), .primitive .kdec, .reflexive⟩

theorem native_sorted_rewrite_modulo_ac (step : NativeSortedRewrite left right) :
    NativeModuloACRewrite left right := by
  induction step with
  | primitive step => exact native_sorted_primitive_modulo_ac step
  | unary _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .unary beforeAC, .unary rewrite, .unary afterAC⟩
  | binaryLeft _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .binary beforeAC .reflexive, .binaryLeft rewrite, .binary afterAC .reflexive⟩
  | binaryRight _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .binary .reflexive beforeAC, .binaryRight rewrite, .binary .reflexive afterAC⟩
  | kdfFirst _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .kdf beforeAC .reflexive .reflexive, .kdfFirst rewrite,
      .kdf afterAC .reflexive .reflexive⟩
  | kdfSecond _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .kdf .reflexive beforeAC .reflexive, .kdfSecond rewrite,
      .kdf .reflexive afterAC .reflexive⟩
  | kdfThird _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .kdf .reflexive .reflexive beforeAC, .kdfThird rewrite,
      .kdf .reflexive .reflexive afterAC⟩
  | naturalLeft _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .naturalAdd beforeAC .reflexive, .naturalLeft rewrite,
      .naturalAdd afterAC .reflexive⟩
  | naturalRight _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .naturalAdd .reflexive beforeAC, .naturalRight rewrite,
      .naturalAdd .reflexive afterAC⟩
  | list _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .list beforeAC, .list rewrite, .list afterAC⟩
  | consLeft _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .cons beforeAC .reflexive, .consLeft rewrite, .cons afterAC .reflexive⟩
  | consRight _ induction =>
    obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .cons .reflexive beforeAC, .consRight rewrite, .cons .reflexive afterAC⟩

theorem native_sorted_rewrite_decode (step : NativeSortedRewrite left right)
    (decoded : decodeNativeMessage left = some message) :
    ∃ result, ModuloACRewrite message result ∧ decodeNativeMessage right = some result :=
  native_modulo_ac_decode (native_sorted_rewrite_modulo_ac step) decoded

theorem native_sorted_kind_framed_rewrite (step : NativeSortedRewrite left right)
    (image : NativeKindFramedImage left) : NativeKindFramedImage right := by
  obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := native_sorted_rewrite_modulo_ac step
  exact native_kind_framed_ac afterAC
    (native_kind_framed_rewrite rewrite (native_kind_framed_ac beforeAC image))

theorem native_sorted_proper_termination :
    WellFounded (fun right left : MessageTerm =>
      NativeSortedRewrite (encodeNativeMessage left) (encodeNativeMessage right)) := by
  apply Subrelation.wf (r := fun right left => ModuloACRewrite left right) _ modulo_ac_termination
  intro right left step
  exact native_modulo_ac_reflection (native_sorted_rewrite_modulo_ac step)

theorem native_sorted_kind_termination :
    WellFounded (fun right left : NativeKindMessage => NativeSortedRewrite left.term right.term) := by
  apply Subrelation.wf (r := fun right left : NativeKindMessage =>
    NativeModuloACRewrite left.term right.term) _ native_kind_termination
  intro right left step
  exact native_sorted_rewrite_modulo_ac step

#print axioms native_sorted_matching_preservation
#print axioms native_sorted_rewrite_modulo_ac
#print axioms native_sorted_rewrite_decode
#print axioms native_sorted_kind_framed_rewrite
#print axioms native_sorted_proper_termination
#print axioms native_sorted_kind_termination

end Cairn.Equations
