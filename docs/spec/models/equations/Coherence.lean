import Termination

namespace Cairn.Equations

inductive MatchingPrimitiveRewrite : MessageTerm → MessageTerm → Prop where
  | flipA : MatchingPrimitiveRewrite (.unary .flip .roleA) .roleB
  | flipB : MatchingPrimitiveRewrite (.unary .flip .roleB) .roleA
  | fst : MatchingPrimitiveRewrite (.unary .fst (.binary .pair left right)) left
  | snd : MatchingPrimitiveRewrite (.unary .snd (.binary .pair left right)) right
  | sdec : MessageAC firstKey secondKey →
      MatchingPrimitiveRewrite (.binary .sdec (.binary .senc payload firstKey) secondKey) payload
  | kdec : MessageAC firstKey secondKey →
      MatchingPrimitiveRewrite
        (.binary .kdec (.binary .kem payload (.unary .pk firstKey)) secondKey) payload

inductive MatchingRewrite : MessageTerm → MessageTerm → Prop where
  | primitive : MatchingPrimitiveRewrite left right → MatchingRewrite left right
  | unary : MatchingRewrite left right →
      MatchingRewrite (.unary symbol left) (.unary symbol right)
  | binaryLeft : MatchingRewrite left right →
      MatchingRewrite (.binary symbol left other) (.binary symbol right other)
  | binaryRight : MatchingRewrite left right →
      MatchingRewrite (.binary symbol other left) (.binary symbol other right)
  | kdfFirst : MatchingRewrite left right →
      MatchingRewrite (.kdf left second third) (.kdf right second third)
  | kdfSecond : MatchingRewrite left right →
      MatchingRewrite (.kdf first left third) (.kdf first right third)
  | kdfThird : MatchingRewrite left right →
      MatchingRewrite (.kdf first second left) (.kdf first second right)

private inductive StructuralAC : MessageTerm → MessageTerm → Prop where
  | atom : StructuralAC (.atom sort identifier) (.atom sort identifier)
  | natural : NaturalAC left right → StructuralAC (.natural left) (.natural right)
  | roleA : StructuralAC .roleA .roleA
  | roleB : StructuralAC .roleB .roleB
  | unary : StructuralAC left right → StructuralAC (.unary symbol left) (.unary symbol right)
  | binary : StructuralAC firstLeft firstRight → StructuralAC secondLeft secondRight →
      StructuralAC (.binary symbol firstLeft secondLeft) (.binary symbol firstRight secondRight)
  | kdf : StructuralAC firstLeft firstRight → StructuralAC secondLeft secondRight →
      StructuralAC thirdLeft thirdRight →
      StructuralAC (.kdf firstLeft secondLeft thirdLeft) (.kdf firstRight secondRight thirdRight)

private theorem structural_reflexive (term : MessageTerm) : StructuralAC term term := by
  induction term with
  | atom => exact .atom
  | natural => exact .natural .reflexive
  | roleA => exact .roleA
  | roleB => exact .roleB
  | unary _ _ induction => exact .unary induction
  | binary _ _ _ first second => exact .binary first second
  | kdf _ _ _ first second third => exact .kdf first second third

private theorem structural_symmetric (equivalent : StructuralAC left right) :
    StructuralAC right left := by
  induction equivalent with
  | atom => exact .atom
  | natural equivalent => exact .natural (.symmetric equivalent)
  | roleA => exact .roleA
  | roleB => exact .roleB
  | unary _ induction => exact .unary induction
  | binary _ _ first second => exact .binary first second
  | kdf _ _ _ first second third => exact .kdf first second third

private theorem structural_transitive
    (first : StructuralAC left middle) (second : StructuralAC middle right) :
    StructuralAC left right := by
  induction first generalizing right with
  | atom => exact second
  | natural equivalent =>
    cases second with
    | natural other => exact .natural (.transitive equivalent other)
  | roleA => exact second
  | roleB => exact second
  | unary _ induction =>
    cases second with
    | unary other => exact .unary (induction other)
  | binary _ _ first secondInduction =>
    cases second with
    | binary otherFirst otherSecond =>
      exact .binary (first otherFirst) (secondInduction otherSecond)
  | kdf _ _ _ first secondInduction third =>
    cases second with
    | kdf otherFirst otherSecond otherThird =>
      exact .kdf (first otherFirst) (secondInduction otherSecond) (third otherThird)

private theorem ac_structural (equivalent : MessageAC left right) :
    StructuralAC left right := by
  induction equivalent with
  | reflexive => exact structural_reflexive _
  | symmetric _ induction => exact structural_symmetric induction
  | transitive _ _ first second => exact structural_transitive first second
  | natural equivalent => exact .natural equivalent
  | unary _ induction => exact .unary induction
  | binaryLeft _ induction => exact .binary induction (structural_reflexive _)
  | binaryRight _ induction => exact .binary (structural_reflexive _) induction
  | kdfFirst _ induction =>
    exact .kdf induction (structural_reflexive _) (structural_reflexive _)
  | kdfSecond _ induction =>
    exact .kdf (structural_reflexive _) induction (structural_reflexive _)
  | kdfThird _ induction =>
    exact .kdf (structural_reflexive _) (structural_reflexive _) induction

private theorem structural_ac (equivalent : StructuralAC left right) :
    MessageAC left right := by
  induction equivalent with
  | atom => exact .reflexive
  | natural equivalent => exact .natural equivalent
  | roleA => exact .reflexive
  | roleB => exact .reflexive
  | unary _ induction => exact .unary induction
  | binary _ _ first second => exact .transitive (.binaryLeft first) (.binaryRight second)
  | kdf _ _ _ first second third =>
    exact .transitive (.kdfFirst first) (.transitive (.kdfSecond second) (.kdfThird third))

private theorem primitive_transport (step : PrimitiveRewrite before after)
    (equivalent : StructuralAC actual before) :
    ∃ result, MatchingPrimitiveRewrite actual result ∧ MessageAC result after := by
  cases step with
  | flipA =>
    cases equivalent with
    | unary argument =>
      cases argument
      exact ⟨_, .flipA, .reflexive⟩
  | flipB =>
    cases equivalent with
    | unary argument =>
      cases argument
      exact ⟨_, .flipB, .reflexive⟩
  | fst =>
    cases equivalent with
    | unary argument =>
      cases argument with
      | binary first _ => exact ⟨_, .fst, structural_ac first⟩
  | snd =>
    cases equivalent with
    | unary argument =>
      cases argument with
      | binary _ second => exact ⟨_, .snd, structural_ac second⟩
  | sdec =>
    cases equivalent with
    | binary ciphertext outerKey =>
      cases ciphertext with
      | binary payload innerKey =>
        exact ⟨_, .sdec (.transitive (structural_ac innerKey)
          (.symmetric (structural_ac outerKey))), structural_ac payload⟩
  | kdec =>
    cases equivalent with
    | binary ciphertext outerKey =>
      cases ciphertext with
      | binary payload publicKey =>
        cases publicKey with
        | unary innerKey =>
          exact ⟨_, .kdec (.transitive (structural_ac innerKey)
            (.symmetric (structural_ac outerKey))), structural_ac payload⟩

private theorem rewrite_transport (step : Rewrite before after)
    (equivalent : StructuralAC actual before) :
    ∃ result, MatchingRewrite actual result ∧ MessageAC result after := by
  induction step generalizing actual with
  | primitive step =>
    obtain ⟨result, matching, afterAC⟩ := primitive_transport step equivalent
    exact ⟨result, .primitive matching, afterAC⟩
  | unary _ induction =>
    cases equivalent with
    | unary argument =>
      obtain ⟨result, matching, afterAC⟩ := induction argument
      exact ⟨_, .unary matching, .unary afterAC⟩
  | binaryLeft _ induction =>
    cases equivalent with
    | binary first second =>
      obtain ⟨result, matching, afterAC⟩ := induction first
      exact ⟨_, .binaryLeft matching,
        .transitive (.binaryLeft afterAC) (.binaryRight (structural_ac second))⟩
  | binaryRight _ induction =>
    cases equivalent with
    | binary first second =>
      obtain ⟨result, matching, afterAC⟩ := induction second
      exact ⟨_, .binaryRight matching,
        .transitive (.binaryLeft (structural_ac first)) (.binaryRight afterAC)⟩
  | kdfFirst _ induction =>
    cases equivalent with
    | kdf first second third =>
      obtain ⟨result, matching, afterAC⟩ := induction first
      exact ⟨_, .kdfFirst matching, .transitive (.kdfFirst afterAC)
        (.transitive (.kdfSecond (structural_ac second)) (.kdfThird (structural_ac third)))⟩
  | kdfSecond _ induction =>
    cases equivalent with
    | kdf first second third =>
      obtain ⟨result, matching, afterAC⟩ := induction second
      exact ⟨_, .kdfSecond matching, .transitive (.kdfFirst (structural_ac first))
        (.transitive (.kdfSecond afterAC) (.kdfThird (structural_ac third)))⟩
  | kdfThird _ induction =>
    cases equivalent with
    | kdf first second third =>
      obtain ⟨result, matching, afterAC⟩ := induction third
      exact ⟨_, .kdfThird matching, .transitive (.kdfFirst (structural_ac first))
        (.transitive (.kdfSecond (structural_ac second)) (.kdfThird afterAC))⟩

theorem modulo_ac_matching_coherence (step : ModuloACRewrite left right) :
    ∃ result, MatchingRewrite left result ∧ MessageAC result right := by
  obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := step
  obtain ⟨result, matching, equivalent⟩ := rewrite_transport rewrite (ac_structural beforeAC)
  exact ⟨result, matching, .transitive equivalent afterAC⟩

theorem matching_primitive_modulo_ac (step : MatchingPrimitiveRewrite left right) :
    ModuloACRewrite left right := by
  cases step with
  | flipA => exact ⟨_, _, .reflexive, .primitive .flipA, .reflexive⟩
  | flipB => exact ⟨_, _, .reflexive, .primitive .flipB, .reflexive⟩
  | fst => exact ⟨_, _, .reflexive, .primitive .fst, .reflexive⟩
  | snd => exact ⟨_, _, .reflexive, .primitive .snd, .reflexive⟩
  | sdec equivalent =>
    exact ⟨_, _, .binaryRight (.symmetric equivalent), .primitive .sdec, .reflexive⟩
  | kdec equivalent =>
    exact ⟨_, _, .binaryRight (.symmetric equivalent), .primitive .kdec, .reflexive⟩

theorem matching_rewrite_modulo_ac (step : MatchingRewrite left right) :
    ModuloACRewrite left right := by
  induction step with
  | primitive step => exact matching_primitive_modulo_ac step
  | unary _ induction =>
    obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .unary beforeAC, .unary rewrite, .unary afterAC⟩
  | binaryLeft _ induction =>
    obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .binaryLeft beforeAC, .binaryLeft rewrite, .binaryLeft afterAC⟩
  | binaryRight _ induction =>
    obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .binaryRight beforeAC, .binaryRight rewrite, .binaryRight afterAC⟩
  | kdfFirst _ induction =>
    obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .kdfFirst beforeAC, .kdfFirst rewrite, .kdfFirst afterAC⟩
  | kdfSecond _ induction =>
    obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .kdfSecond beforeAC, .kdfSecond rewrite, .kdfSecond afterAC⟩
  | kdfThird _ induction =>
    obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := induction
    exact ⟨_, _, .kdfThird beforeAC, .kdfThird rewrite, .kdfThird afterAC⟩

theorem matching_termination :
    WellFounded (fun right left => MatchingRewrite left right) := by
  apply Subrelation.wf (r := fun right left => ModuloACRewrite left right) _ modulo_ac_termination
  intro right left step
  exact matching_rewrite_modulo_ac step

theorem matching_rewrite_ac_coherent (step : MatchingRewrite first second)
    (equivalent : MessageAC first third) :
    ∃ result, MatchingRewrite third result ∧ MessageAC second result := by
  obtain ⟨before, after, beforeAC, rewrite, afterAC⟩ := matching_rewrite_modulo_ac step
  obtain ⟨result, matching, resultAC⟩ := modulo_ac_matching_coherence
    ⟨before, after, .transitive (.symmetric equivalent) beforeAC, rewrite, afterAC⟩
  exact ⟨result, matching, .symmetric resultAC⟩

#print axioms modulo_ac_matching_coherence
#print axioms matching_primitive_modulo_ac
#print axioms matching_rewrite_modulo_ac
#print axioms matching_termination
#print axioms matching_rewrite_ac_coherent

end Cairn.Equations
