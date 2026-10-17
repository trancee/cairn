import QueryFraming

namespace Cairn.Equations

structure NativeLeafRelabeling where
  atoms : AtomSort → Nat → NativeQueryTerm
  naturals : Nat → NativeQueryTerm
  nodes : Nat → NativeQueryTerm
  variables : QuerySort → Nat → NativeQueryTerm

def relabelNative (assignment : NativeLeafRelabeling) : NativeQueryTerm → NativeQueryTerm
  | .atom sort index => assignment.atoms sort index
  | .naturalAtom index => assignment.naturals index
  | .nodeAtom index => assignment.nodes index
  | .queryVariable sort index => assignment.variables sort index
  | .naturalOne => .naturalOne
  | .naturalAdd left right =>
    .naturalAdd (relabelNative assignment left) (relabelNative assignment right)
  | .roleA => .roleA
  | .roleB => .roleB
  | .unary symbol argument => .unary symbol (relabelNative assignment argument)
  | .binary symbol left right =>
    .binary symbol (relabelNative assignment left) (relabelNative assignment right)
  | .kdf first second third => .kdf (relabelNative assignment first)
    (relabelNative assignment second) (relabelNative assignment third)
  | .list argument => .list (relabelNative assignment argument)
  | .cons first rest => .cons (relabelNative assignment first) (relabelNative assignment rest)
  | .nil => .nil

theorem native_ac_relabeling (assignment : NativeLeafRelabeling)
    (equivalent : NativeQueryAC left right) :
    NativeQueryAC (relabelNative assignment left) (relabelNative assignment right) := by
  induction equivalent with
  | reflexive => exact .reflexive
  | symmetric _ induction => exact .symmetric induction
  | transitive _ _ first second => exact .transitive first second
  | associative => exact .associative
  | commutative => exact .commutative
  | naturalAdd _ _ first second => exact .naturalAdd first second
  | unary _ induction => exact .unary induction
  | binary _ _ first second => exact .binary first second
  | kdf _ _ _ first second third => exact .kdf first second third
  | list _ induction => exact .list induction
  | cons _ _ first second => exact .cons first second

theorem native_rewrite_relabeling (assignment : NativeLeafRelabeling)
    (rewrite : NativeRewrite left right) :
    NativeRewrite (relabelNative assignment left) (relabelNative assignment right) := by
  induction rewrite with
  | primitive step =>
    cases step
    · exact .primitive .flipA
    · exact .primitive .flipB
    · exact .primitive .fst
    · exact .primitive .snd
    · exact .primitive .sdec
    · exact .primitive .kdec
  | unary _ induction => exact .unary induction
  | binaryLeft _ induction => exact .binaryLeft induction
  | binaryRight _ induction => exact .binaryRight induction
  | kdfFirst _ induction => exact .kdfFirst induction
  | kdfSecond _ induction => exact .kdfSecond induction
  | kdfThird _ induction => exact .kdfThird induction
  | naturalLeft _ induction => exact .naturalLeft induction
  | naturalRight _ induction => exact .naturalRight induction
  | list _ induction => exact .list induction
  | consLeft _ induction => exact .consLeft induction
  | consRight _ induction => exact .consRight induction

theorem native_modulo_ac_relabeling (assignment : NativeLeafRelabeling)
    (rewrite : NativeModuloACRewrite left right) :
    NativeModuloACRewrite (relabelNative assignment left) (relabelNative assignment right) := by
  obtain ⟨before, after, first, step, second⟩ := rewrite
  exact ⟨_, _, native_ac_relabeling assignment first, native_rewrite_relabeling assignment step,
    native_ac_relabeling assignment second⟩

#print axioms native_ac_relabeling
#print axioms native_rewrite_relabeling
#print axioms native_modulo_ac_relabeling

end Cairn.Equations
