import Coherence
import QueryRewrite

namespace Cairn.Equations

theorem native_matching_preservation (rewrite : MatchingRewrite left right) :
    NativeModuloACRewrite (encodeNativeMessage left) (encodeNativeMessage right) :=
  native_modulo_ac_preservation (matching_rewrite_modulo_ac rewrite)

theorem native_matching_realization
    (rewrite : NativeModuloACRewrite (encodeNativeMessage left) (encodeNativeMessage right)) :
    ∃ result, MatchingRewrite left result ∧ MessageAC result right :=
  modulo_ac_matching_coherence (native_modulo_ac_reflection rewrite)

#print axioms native_matching_preservation
#print axioms native_matching_realization

end Cairn.Equations
