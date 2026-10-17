import QueryMatching

open Cairn.Equations

example (payload : MessageTerm) :
    NativeModuloACRewrite
      (encodeNativeMessage (.binary .sdec
        (.binary .senc payload (.natural (.add (.variable 1) (.variable 14))))
        (.natural (.add (.variable 14) (.variable 1)))))
      (encodeNativeMessage payload) := by
  apply native_matching_preservation
  exact .primitive (.sdec (.natural .commutative))

example (payload key : MessageTerm) :
    NativeRewrite
      (encodeNativeMessage (.kdf .roleA .roleB
        (.binary .kdec (.binary .kem payload (.unary .pk key)) key)))
      (encodeNativeMessage (.kdf .roleA .roleB payload)) :=
  native_rewrite_preservation (.kdfThird (.primitive .kdec))

example (rewrite : NativeRewrite (encodeNativeNatural term) target) : False := by
  obtain ⟨result, step, _⟩ := native_rewrite_image (term := .natural term) rewrite
  cases step with
  | primitive step => cases step

example (equivalent : NativeQueryAC (encodeNativeMessage term) target) :
    ∃ result, encodeNativeMessage result = target ∧ MessageAC term result := by
  obtain ⟨result, decoded, related⟩ :=
    native_ac_message_image equivalent (native_message_round_trip term)
  exact ⟨result, native_message_recognition target decoded, related⟩
