import Coherence

open Cairn.Equations

example (payload : MessageTerm) :
    MatchingPrimitiveRewrite
      (.binary .sdec
        (.binary .senc payload (.natural (.add .one (.variable 0))))
        (.natural (.add (.variable 0) .one)))
      payload := by
  constructor
  exact MessageAC.natural NaturalAC.commutative

example (payload : MessageTerm) :
    MatchingRewrite
      (.kdf .roleA .roleB
        (.binary .kdec
          (.binary .kem payload (.unary .pk (.natural (.add .one (.variable 0)))))
          (.natural (.add (.variable 0) .one))))
      (.kdf .roleA .roleB payload) := by
  exact .kdfThird (.primitive (.kdec (.natural .commutative)))
