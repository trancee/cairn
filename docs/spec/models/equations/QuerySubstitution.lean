import QueryRewrite

namespace Cairn.Equations

structure QuerySubstitution where
  publicAtoms : Nat → Nat
  freshAtoms : Nat → Nat
  messages : Nat → MessageTerm
  naturals : Nat → NaturalTerm
  nodes : Nat → Nat

def substituteQueryNatural (assignment : QuerySubstitution) : NaturalTerm → NaturalTerm
  | .one => .one
  | .variable identifier =>
    if identifier % 2 = 0 then assignment.naturals (identifier / 2) else .variable identifier
  | .add left right =>
    .add (substituteQueryNatural assignment left) (substituteQueryNatural assignment right)

def substituteQueryMessage (assignment : QuerySubstitution) : MessageTerm → MessageTerm
  | .atom sort identifier =>
    if identifier % 2 = 0 then
      match sort with
      | .publicAtom => .atom .publicAtom (assignment.publicAtoms (identifier / 2))
      | .freshAtom => .atom .freshAtom (assignment.freshAtoms (identifier / 2))
      | .messageAtom => assignment.messages (identifier / 2)
    else .atom sort identifier
  | .natural term => .natural (substituteQueryNatural assignment term)
  | .roleA => .roleA
  | .roleB => .roleB
  | .unary symbol argument => .unary symbol (substituteQueryMessage assignment argument)
  | .binary symbol left right =>
    .binary symbol (substituteQueryMessage assignment left) (substituteQueryMessage assignment right)
  | .kdf first second third => .kdf (substituteQueryMessage assignment first)
    (substituteQueryMessage assignment second) (substituteQueryMessage assignment third)

def nativeQueryAssignment (assignment : QuerySubstitution) :
    QuerySort → Nat → NativeQueryTerm
  | .publicAtom, index => encodeNativeMessage (.atom .publicAtom (assignment.publicAtoms index))
  | .freshAtom, index => encodeNativeMessage (.atom .freshAtom (assignment.freshAtoms index))
  | .message, index => encodeNativeMessage (assignment.messages index)
  | .natural, index => encodeNativeNatural (assignment.naturals index)
  | .node, index =>
    if assignment.nodes index % 2 = 0 then .queryVariable .node (assignment.nodes index / 2)
    else .nodeAtom (assignment.nodes index / 2)

def substituteNativeQuery (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeQueryTerm → NativeQueryTerm
  | .queryVariable sort index => assignment sort index
  | .naturalAdd left right =>
    .naturalAdd (substituteNativeQuery assignment left) (substituteNativeQuery assignment right)
  | .unary symbol argument => .unary symbol (substituteNativeQuery assignment argument)
  | .binary symbol left right =>
    .binary symbol (substituteNativeQuery assignment left) (substituteNativeQuery assignment right)
  | .kdf first second third => .kdf (substituteNativeQuery assignment first)
    (substituteNativeQuery assignment second) (substituteNativeQuery assignment third)
  | .list argument => .list (substituteNativeQuery assignment argument)
  | .cons left right =>
    .cons (substituteNativeQuery assignment left) (substituteNativeQuery assignment right)
  | .atom sort index => .atom sort index
  | .naturalAtom index => .naturalAtom index
  | .nodeAtom index => .nodeAtom index
  | .naturalOne => .naturalOne
  | .roleA => .roleA
  | .roleB => .roleB
  | .nil => .nil

theorem native_natural_substitution (assignment : QuerySubstitution) (term : NaturalTerm) :
    encodeNativeNatural (substituteQueryNatural assignment term) =
      substituteNativeQuery (nativeQueryAssignment assignment) (encodeNativeNatural term) := by
  induction term with
  | one => rfl
  | «variable» identifier =>
    by_cases even : identifier % 2 = 0 <;>
      simp [substituteQueryNatural, encodeNativeNatural, substituteNativeQuery,
        nativeQueryAssignment, even]
  | add left right firstInduction secondInduction =>
    simp only [substituteQueryNatural, encodeNativeNatural, substituteNativeQuery]
    rw [firstInduction, secondInduction]

theorem native_message_substitution (assignment : QuerySubstitution) (term : MessageTerm) :
    encodeNativeMessage (substituteQueryMessage assignment term) =
      substituteNativeQuery (nativeQueryAssignment assignment) (encodeNativeMessage term) := by
  induction term with
  | atom sort identifier =>
    cases sort <;> by_cases even : identifier % 2 = 0 <;>
      simp [substituteQueryMessage, encodeNativeMessage, substituteNativeQuery,
        nativeQueryAssignment, atomQuerySort, even]
  | natural term => exact native_natural_substitution assignment term
  | roleA => rfl
  | roleB => rfl
  | unary symbol argument induction =>
    simp only [substituteQueryMessage, encodeNativeMessage, substituteNativeQuery]
    rw [induction]
  | binary symbol left right firstInduction secondInduction =>
    simp only [substituteQueryMessage, encodeNativeMessage, substituteNativeQuery]
    rw [firstInduction, secondInduction]
  | kdf first second third firstInduction secondInduction thirdInduction =>
    simp only [substituteQueryMessage, encodeNativeMessage, substituteNativeQuery]
    rw [firstInduction, secondInduction, thirdInduction]

theorem native_natural_substitution_image (assignment : QuerySubstitution) (term : NaturalTerm) :
    decodeNativeNatural
      (substituteNativeQuery (nativeQueryAssignment assignment) (encodeNativeNatural term)) =
        some (substituteQueryNatural assignment term) := by
  rw [← native_natural_substitution, native_natural_round_trip]

theorem native_message_substitution_image (assignment : QuerySubstitution) (term : MessageTerm) :
    decodeNativeMessage
      (substituteNativeQuery (nativeQueryAssignment assignment) (encodeNativeMessage term)) =
        some (substituteQueryMessage assignment term) := by
  rw [← native_message_substitution, native_message_round_trip]

theorem native_ac_substitution (assignment : QuerySort → Nat → NativeQueryTerm)
    (equivalent : NativeQueryAC left right) :
    NativeQueryAC (substituteNativeQuery assignment left)
      (substituteNativeQuery assignment right) := by
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

theorem native_rewrite_substitution (assignment : QuerySort → Nat → NativeQueryTerm)
    (rewrite : NativeRewrite left right) :
    NativeRewrite (substituteNativeQuery assignment left)
      (substituteNativeQuery assignment right) := by
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

#print axioms native_natural_substitution
#print axioms native_message_substitution
#print axioms native_natural_substitution_image
#print axioms native_message_substitution_image
#print axioms native_ac_substitution
#print axioms native_rewrite_substitution

end Cairn.Equations
