import Convergence

open Cairn.Equations

private def leftKey : MessageTerm :=
  .binary .pair (.unary .flip .roleA) (.natural (.add .one (.variable 0)))

private def rightKey : MessageTerm :=
  .binary .pair (.unary .flip .roleA) (.natural (.add (.variable 0) .one))

private theorem keys_ac : MessageAC leftKey rightKey :=
  .binaryRight (.natural .commutative)

example (payload : MessageTerm) :
    Joinable payload (.binary .sdec
      (.binary .senc payload (.binary .pair .roleB (.natural (.add .one (.variable 0)))))
      rightKey) := by
  apply matching_local_confluence
    (term := .binary .sdec (.binary .senc payload leftKey) rightKey)
  · exact .primitive (.sdec keys_ac)
  · exact .binaryLeft (.binaryRight (.binaryLeft (.primitive .flipA)))

example (payload : MessageTerm) :
    Joinable payload (.binary .kdec (.binary .kem payload (.unary .pk leftKey))
      (.binary .pair .roleB (.natural (.add (.variable 0) .one)))) := by
  apply matching_local_confluence
    (term := .binary .kdec (.binary .kem payload (.unary .pk leftKey)) rightKey)
  · exact .primitive (.kdec keys_ac)
  · exact .binaryRight (.binaryLeft (.primitive .flipA))

example (first : ModuloACSteps term firstCount left)
    (second : ModuloACSteps term secondCount right) :
    ∃ leftResult rightResult leftCount rightCount,
      MatchingSteps left leftCount leftResult ∧
      MatchingSteps right rightCount rightResult ∧ MessageAC leftResult rightResult :=
  modulo_ac_confluence first second
