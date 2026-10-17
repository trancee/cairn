import QueryAC
import QueryRecognition

namespace Cairn.Equations

inductive NativePrimitiveRewrite : NativeQueryTerm → NativeQueryTerm → Prop where
  | flipA : NativePrimitiveRewrite (.unary .flip .roleA) .roleB
  | flipB : NativePrimitiveRewrite (.unary .flip .roleB) .roleA
  | fst : NativePrimitiveRewrite (.unary .fst (.binary .pair left right)) left
  | snd : NativePrimitiveRewrite (.unary .snd (.binary .pair left right)) right
  | sdec : NativePrimitiveRewrite (.binary .sdec (.binary .senc payload key) key) payload
  | kdec : NativePrimitiveRewrite
      (.binary .kdec (.binary .kem payload (.unary .pk key)) key) payload

inductive NativeRewrite : NativeQueryTerm → NativeQueryTerm → Prop where
  | primitive : NativePrimitiveRewrite left right → NativeRewrite left right
  | unary : NativeRewrite left right → NativeRewrite (.unary symbol left) (.unary symbol right)
  | binaryLeft : NativeRewrite left right →
      NativeRewrite (.binary symbol left other) (.binary symbol right other)
  | binaryRight : NativeRewrite left right →
      NativeRewrite (.binary symbol other left) (.binary symbol other right)
  | kdfFirst : NativeRewrite left right →
      NativeRewrite (.kdf left second third) (.kdf right second third)
  | kdfSecond : NativeRewrite left right →
      NativeRewrite (.kdf first left third) (.kdf first right third)
  | kdfThird : NativeRewrite left right →
      NativeRewrite (.kdf first second left) (.kdf first second right)
  | naturalLeft : NativeRewrite left right →
      NativeRewrite (.naturalAdd left other) (.naturalAdd right other)
  | naturalRight : NativeRewrite left right →
      NativeRewrite (.naturalAdd other left) (.naturalAdd other right)
  | list : NativeRewrite left right → NativeRewrite (.list left) (.list right)
  | consLeft : NativeRewrite left right → NativeRewrite (.cons left other) (.cons right other)
  | consRight : NativeRewrite left right → NativeRewrite (.cons other left) (.cons other right)

private theorem native_natural_has_no_rewrite (rewrite : NativeRewrite left right)
    (decoded : decodeNativeNatural left = some term) : False := by
  induction rewrite generalizing term with
  | primitive step => cases step <;> simp [decodeNativeNatural] at decoded
  | unary | binaryLeft | binaryRight | kdfFirst | kdfSecond | kdfThird | list | consLeft | consRight =>
    simp [decodeNativeNatural] at decoded
  | @naturalLeft left right other step induction =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural other <;>
      simp [decodeNativeNatural, first, second] at decoded
    exact induction first
  | @naturalRight left right other step induction =>
    cases first : decodeNativeNatural other <;> cases second : decodeNativeNatural left <;>
      simp [decodeNativeNatural, first, second] at decoded
    exact induction second

theorem native_primitive_preservation (rewrite : PrimitiveRewrite left right) :
    NativePrimitiveRewrite (encodeNativeMessage left) (encodeNativeMessage right) := by
  cases rewrite
  · exact .flipA
  · exact .flipB
  · exact .fst
  · exact .snd
  · exact .sdec
  · exact .kdec

private theorem native_primitive_decode (rewrite : NativePrimitiveRewrite left right)
    (decoded : decodeNativeMessage left = some term) :
    ∃ result, PrimitiveRewrite term result ∧ decodeNativeMessage right = some result := by
  cases rewrite with
  | flipA => simp [decodeNativeMessage] at decoded; subst term; exact ⟨_, .flipA, rfl⟩
  | flipB => simp [decodeNativeMessage] at decoded; subst term; exact ⟨_, .flipB, rfl⟩
  | @fst left right =>
    rename_i payload
    cases first : decodeNativeMessage payload <;> cases second : decodeNativeMessage right <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    exact ⟨_, .fst, rfl⟩
  | @snd left right =>
    cases first : decodeNativeMessage left <;> cases second : decodeNativeMessage right <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    exact ⟨_, .snd, rfl⟩
  | @sdec payload key =>
    cases first : decodeNativeMessage right <;> cases second : decodeNativeMessage key <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    exact ⟨_, .sdec, rfl⟩
  | @kdec payload key =>
    cases first : decodeNativeMessage right <;> cases second : decodeNativeMessage key <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    exact ⟨_, .kdec, rfl⟩

theorem native_rewrite_preservation (rewrite : Rewrite left right) :
    NativeRewrite (encodeNativeMessage left) (encodeNativeMessage right) := by
  induction rewrite with
  | primitive step => exact .primitive (native_primitive_preservation step)
  | unary _ induction => exact .unary induction
  | binaryLeft _ induction => exact .binaryLeft induction
  | binaryRight _ induction => exact .binaryRight induction
  | kdfFirst _ induction => exact .kdfFirst induction
  | kdfSecond _ induction => exact .kdfSecond induction
  | kdfThird _ induction => exact .kdfThird induction

theorem native_rewrite_decode (rewrite : NativeRewrite left right)
    (decoded : decodeNativeMessage left = some term) :
    ∃ result, Rewrite term result ∧ decodeNativeMessage right = some result := by
  induction rewrite generalizing term with
  | primitive step =>
    obtain ⟨result, rewrite, resultDecoded⟩ := native_primitive_decode step decoded
    exact ⟨result, .primitive rewrite, resultDecoded⟩
  | @unary left right symbol step induction =>
    cases child : decodeNativeMessage left <;> simp [decodeNativeMessage, child] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction child
    exact ⟨_, .unary rewrite, by simp [decodeNativeMessage, resultDecoded]⟩
  | @binaryLeft left right symbol other step induction =>
    cases first : decodeNativeMessage left <;> cases second : decodeNativeMessage other <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction first
    exact ⟨_, .binaryLeft rewrite, by simp [decodeNativeMessage, resultDecoded, second]⟩
  | @binaryRight left right symbol other step induction =>
    cases first : decodeNativeMessage other <;> cases second : decodeNativeMessage left <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction second
    exact ⟨_, .binaryRight rewrite, by simp [decodeNativeMessage, first, resultDecoded]⟩
  | @kdfFirst left right second third step induction =>
    cases firstValue : decodeNativeMessage left <;>
      cases secondValue : decodeNativeMessage second <;>
      cases thirdValue : decodeNativeMessage third <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction firstValue
    exact ⟨_, .kdfFirst rewrite, by simp [decodeNativeMessage, resultDecoded, secondValue, thirdValue]⟩
  | @kdfSecond left right first third step induction =>
    cases firstValue : decodeNativeMessage first <;>
      cases secondValue : decodeNativeMessage left <;>
      cases thirdValue : decodeNativeMessage third <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction secondValue
    exact ⟨_, .kdfSecond rewrite, by simp [decodeNativeMessage, firstValue, resultDecoded, thirdValue]⟩
  | @kdfThird left right first second step induction =>
    cases firstValue : decodeNativeMessage first <;>
      cases secondValue : decodeNativeMessage second <;>
      cases thirdValue : decodeNativeMessage left <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction thirdValue
    exact ⟨_, .kdfThird rewrite, by simp [decodeNativeMessage, firstValue, secondValue, resultDecoded]⟩
  | @naturalLeft left right other step induction =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural other <;>
      simp [decodeNativeMessage, first, second] at decoded
    exact False.elim (native_natural_has_no_rewrite step first)
  | @naturalRight left right other step induction =>
    cases first : decodeNativeNatural other <;> cases second : decodeNativeNatural left <;>
      simp [decodeNativeMessage, first, second] at decoded
    exact False.elim (native_natural_has_no_rewrite step second)
  | list | consLeft | consRight => simp [decodeNativeMessage] at decoded

theorem native_rewrite_image (rewrite : NativeRewrite (encodeNativeMessage term) target) :
    ∃ result, Rewrite term result ∧ encodeNativeMessage result = target := by
  obtain ⟨result, step, decoded⟩ := native_rewrite_decode rewrite (native_message_round_trip term)
  exact ⟨result, step, native_message_recognition target decoded⟩

theorem native_rewrite_reflection
    (rewrite : NativeRewrite (encodeNativeMessage left) (encodeNativeMessage right)) :
    Rewrite left right := by
  obtain ⟨result, step, encoded⟩ := native_rewrite_image rewrite
  have equality := native_message_encoding_injective encoded
  simpa [equality] using step

def NativeModuloACRewrite (left right : NativeQueryTerm) : Prop :=
  ∃ before after, NativeQueryAC left before ∧ NativeRewrite before after ∧ NativeQueryAC after right

theorem native_modulo_ac_preservation (rewrite : ModuloACRewrite left right) :
    NativeModuloACRewrite (encodeNativeMessage left) (encodeNativeMessage right) := by
  obtain ⟨before, after, firstAC, step, secondAC⟩ := rewrite
  exact ⟨_, _, native_message_ac_preservation firstAC, native_rewrite_preservation step,
    native_message_ac_preservation secondAC⟩

theorem native_modulo_ac_decode (rewrite : NativeModuloACRewrite left right)
    (decoded : decodeNativeMessage left = some term) :
    ∃ result, ModuloACRewrite term result ∧ decodeNativeMessage right = some result := by
  obtain ⟨before, after, firstAC, step, secondAC⟩ := rewrite
  obtain ⟨beforeTerm, beforeDecoded, beforeAC⟩ := native_ac_message_image firstAC decoded
  obtain ⟨afterTerm, afterStep, afterDecoded⟩ := native_rewrite_decode step beforeDecoded
  obtain ⟨result, resultDecoded, afterAC⟩ := native_ac_message_image secondAC afterDecoded
  exact ⟨result, ⟨beforeTerm, afterTerm, beforeAC, afterStep, afterAC⟩, resultDecoded⟩

theorem native_modulo_ac_reflection
    (rewrite : NativeModuloACRewrite (encodeNativeMessage left) (encodeNativeMessage right)) :
    ModuloACRewrite left right := by
  obtain ⟨result, step, decoded⟩ := native_modulo_ac_decode rewrite (native_message_round_trip left)
  rw [native_message_round_trip] at decoded
  have equality := Option.some.inj decoded
  simpa [equality] using step

#print axioms native_primitive_preservation
#print axioms native_rewrite_preservation
#print axioms native_rewrite_decode
#print axioms native_rewrite_image
#print axioms native_rewrite_reflection
#print axioms native_modulo_ac_preservation
#print axioms native_modulo_ac_decode
#print axioms native_modulo_ac_reflection

end Cairn.Equations
