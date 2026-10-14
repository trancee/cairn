import Boundedness

open Cairn.Equations

example : MatchingSteps (.unary .flip .roleA) 1 .roleB := by
  repeat' constructor

example (messageAssignment : Nat → MessageTerm) (naturalAssignment : Nat → NaturalTerm)
    (normalized : ∀ identifier, Normal (messageAssignment identifier)) :
    ∃ count result, count ≤ 3 ∧
      MatchingSteps
        (instantiateTemplate messageAssignment naturalAssignment
          (.unary .fst (.binary .pair (.unary .flip (.messageVariable 0)) (.messageVariable 1))))
        count result ∧ Normal result := by
  exact normalized_substitution_bound
    (.unary .fst (.binary .pair (.unary .flip (.messageVariable 0)) (.messageVariable 1)))
    messageAssignment naturalAssignment normalized

example (messageAssignment : Nat → MessageTerm) (naturalAssignment : Nat → NaturalTerm)
    (normalized : ∀ identifier, Normal (messageAssignment identifier)) :
    ∃ count result, count ≤ 2 ∧
      MatchingSteps
        (instantiateTemplate messageAssignment naturalAssignment
          (.binary .sdec
            (.binary .senc (.messageVariable 0) (.natural (.add .one (.variable 1))))
            (.natural (.add (.variable 1) .one))))
        count result ∧ Normal result := by
  exact normalized_substitution_bound
    (.binary .sdec
      (.binary .senc (.messageVariable 0) (.natural (.add .one (.variable 1))))
      (.natural (.add (.variable 1) .one)))
    messageAssignment naturalAssignment normalized
