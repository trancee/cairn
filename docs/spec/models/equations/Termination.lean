import Lean

namespace Cairn.Equations

inductive NaturalTerm where
  | one
  | variable (identifier : Nat)
  | add (left right : NaturalTerm)

inductive AtomSort where
  | publicAtom
  | freshAtom
  | messageAtom

inductive UnarySymbol where
  | flip
  | fst
  | hash
  | pk
  | snd

inductive BinarySymbol where
  | ext
  | kdec
  | kem
  | mac
  | pair
  | sdec
  | senc

inductive MessageTerm where
  | atom (sort : AtomSort) (identifier : Nat)
  | natural (term : NaturalTerm)
  | roleA
  | roleB
  | unary (symbol : UnarySymbol) (argument : MessageTerm)
  | binary (symbol : BinarySymbol) (left right : MessageTerm)
  | kdf (first second third : MessageTerm)

def naturalWeight : NaturalTerm → Nat
  | .one | .variable _ => 1
  | .add left right => naturalWeight left + naturalWeight right + 1

def messageWeight : MessageTerm → Nat
  | .atom _ _ | .roleA | .roleB => 1
  | .natural term => naturalWeight term
  | .unary _ argument => messageWeight argument + 1
  | .binary _ left right => messageWeight left + messageWeight right + 1
  | .kdf first second third =>
    messageWeight first + messageWeight second + messageWeight third + 1

inductive NaturalAC : NaturalTerm → NaturalTerm → Prop where
  | reflexive : NaturalAC term term
  | symmetric : NaturalAC left right → NaturalAC right left
  | transitive : NaturalAC first second → NaturalAC second third → NaturalAC first third
  | associative : NaturalAC (.add (.add first second) third) (.add first (.add second third))
  | commutative : NaturalAC (.add left right) (.add right left)
  | addLeft : NaturalAC left right → NaturalAC (.add left other) (.add right other)
  | addRight : NaturalAC left right → NaturalAC (.add other left) (.add other right)

inductive MessageAC : MessageTerm → MessageTerm → Prop where
  | reflexive : MessageAC term term
  | symmetric : MessageAC left right → MessageAC right left
  | transitive : MessageAC first second → MessageAC second third → MessageAC first third
  | natural : NaturalAC left right → MessageAC (.natural left) (.natural right)
  | unary : MessageAC left right → MessageAC (.unary symbol left) (.unary symbol right)
  | binaryLeft : MessageAC left right →
      MessageAC (.binary symbol left other) (.binary symbol right other)
  | binaryRight : MessageAC left right →
      MessageAC (.binary symbol other left) (.binary symbol other right)
  | kdfFirst : MessageAC left right →
      MessageAC (.kdf left second third) (.kdf right second third)
  | kdfSecond : MessageAC left right →
      MessageAC (.kdf first left third) (.kdf first right third)
  | kdfThird : MessageAC left right →
      MessageAC (.kdf first second left) (.kdf first second right)

inductive PrimitiveRewrite : MessageTerm → MessageTerm → Prop where
  | flipA : PrimitiveRewrite (.unary .flip .roleA) .roleB
  | flipB : PrimitiveRewrite (.unary .flip .roleB) .roleA
  | fst : PrimitiveRewrite (.unary .fst (.binary .pair left right)) left
  | snd : PrimitiveRewrite (.unary .snd (.binary .pair left right)) right
  | sdec : PrimitiveRewrite (.binary .sdec (.binary .senc payload key) key) payload
  | kdec : PrimitiveRewrite (.binary .kdec (.binary .kem payload (.unary .pk key)) key) payload

inductive Rewrite : MessageTerm → MessageTerm → Prop where
  | primitive : PrimitiveRewrite left right → Rewrite left right
  | unary : Rewrite left right → Rewrite (.unary symbol left) (.unary symbol right)
  | binaryLeft : Rewrite left right →
      Rewrite (.binary symbol left other) (.binary symbol right other)
  | binaryRight : Rewrite left right →
      Rewrite (.binary symbol other left) (.binary symbol other right)
  | kdfFirst : Rewrite left right → Rewrite (.kdf left second third) (.kdf right second third)
  | kdfSecond : Rewrite left right → Rewrite (.kdf first left third) (.kdf first right third)
  | kdfThird : Rewrite left right → Rewrite (.kdf first second left) (.kdf first second right)

def ModuloACRewrite (left right : MessageTerm) : Prop :=
  ∃ before after, MessageAC left before ∧ Rewrite before after ∧ MessageAC after right

theorem natural_ac_preserves_weight {left right : NaturalTerm}
    (equivalent : NaturalAC left right) : naturalWeight left = naturalWeight right := by
  induction equivalent <;> simp_all [naturalWeight] <;> omega

theorem message_ac_preserves_weight {left right : MessageTerm}
    (equivalent : MessageAC left right) : messageWeight left = messageWeight right := by
  induction equivalent with
  | reflexive => rfl
  | symmetric _ induction => exact induction.symm
  | transitive _ _ first second => exact first.trans second
  | natural equivalent => exact natural_ac_preserves_weight equivalent
  | @unary left right symbol _ induction =>
    cases symbol <;> simp only [messageWeight, induction]
  | binaryLeft _ induction => simp only [messageWeight, induction]
  | binaryRight _ induction => simp only [messageWeight, induction]
  | kdfFirst _ induction => simp only [messageWeight, induction]
  | kdfSecond _ induction => simp only [messageWeight, induction]
  | kdfThird _ induction => simp only [messageWeight, induction]

theorem primitive_rewrite_decreases_weight {left right : MessageTerm}
    (rewrite : PrimitiveRewrite left right) : messageWeight right < messageWeight left := by
  cases rewrite <;> simp [messageWeight] <;> omega

theorem rewrite_decreases_weight {left right : MessageTerm}
    (rewrite : Rewrite left right) : messageWeight right < messageWeight left := by
  induction rewrite with
  | primitive step => exact primitive_rewrite_decreases_weight step
  | @unary left right symbol step induction =>
    cases symbol <;> simp_all [messageWeight] <;> omega
  | binaryLeft step induction => simp_all [messageWeight]
  | binaryRight step induction => simp_all [messageWeight]
  | kdfFirst step induction => simp_all [messageWeight]
  | kdfSecond step induction => simp_all [messageWeight]
  | kdfThird step induction => simp_all [messageWeight]

theorem modulo_ac_rewrite_decreases_weight {left right : MessageTerm}
    (rewrite : ModuloACRewrite left right) : messageWeight right < messageWeight left := by
  obtain ⟨before, after, beforeAC, step, afterAC⟩ := rewrite
  have decreasing := rewrite_decreases_weight step
  rw [← message_ac_preserves_weight beforeAC, message_ac_preserves_weight afterAC] at decreasing
  exact decreasing

theorem modulo_ac_termination :
    WellFounded (fun right left => ModuloACRewrite left right) := by
  apply Subrelation.wf (r := (measure messageWeight).rel) _ (measure messageWeight).wf
  intro right left rewrite
  exact modulo_ac_rewrite_decreases_weight rewrite

#print axioms natural_ac_preserves_weight
#print axioms message_ac_preserves_weight
#print axioms primitive_rewrite_decreases_weight
#print axioms rewrite_decreases_weight
#print axioms modulo_ac_rewrite_decreases_weight
#print axioms modulo_ac_termination

end Cairn.Equations
