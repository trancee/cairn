import Termination

namespace Cairn.Equations

inductive QuerySort where
  | publicAtom
  | freshAtom
  | message
  | natural
  | node

inductive NativeQueryTerm where
  | atom (sort : AtomSort) (index : Nat)
  | naturalAtom (index : Nat)
  | nodeAtom (index : Nat)
  | queryVariable (sort : QuerySort) (index : Nat)
  | naturalOne
  | naturalAdd (left right : NativeQueryTerm)
  | roleA
  | roleB
  | unary (symbol : UnarySymbol) (argument : NativeQueryTerm)
  | binary (symbol : BinarySymbol) (left right : NativeQueryTerm)
  | kdf (first second third : NativeQueryTerm)
  | list (argument : NativeQueryTerm)
  | cons (first rest : NativeQueryTerm)
  | nil

def atomQuerySort : AtomSort → QuerySort
  | .publicAtom => .publicAtom
  | .freshAtom => .freshAtom
  | .messageAtom => .message

def encodeNativeNatural : NaturalTerm → NativeQueryTerm
  | .one => .naturalOne
  | .variable identifier =>
    if identifier % 2 = 0 then .queryVariable .natural (identifier / 2)
    else .naturalAtom (identifier / 2)
  | .add left right => .naturalAdd (encodeNativeNatural left) (encodeNativeNatural right)

def encodeNativeMessage : MessageTerm → NativeQueryTerm
  | .atom sort identifier =>
    if identifier % 2 = 0 then .queryVariable (atomQuerySort sort) (identifier / 2)
    else .atom sort (identifier / 2)
  | .natural term => encodeNativeNatural term
  | .roleA => .roleA
  | .roleB => .roleB
  | .unary symbol argument => .unary symbol (encodeNativeMessage argument)
  | .binary symbol left right =>
    .binary symbol (encodeNativeMessage left) (encodeNativeMessage right)
  | .kdf first second third =>
    .kdf (encodeNativeMessage first) (encodeNativeMessage second) (encodeNativeMessage third)

def decodeNativeNatural : NativeQueryTerm → Option NaturalTerm
  | .naturalOne => some .one
  | .naturalAtom index => some (.variable (2 * index + 1))
  | .queryVariable .natural index => some (.variable (2 * index))
  | .naturalAdd left right => do
    let first ← decodeNativeNatural left
    let second ← decodeNativeNatural right
    return .add first second
  | .atom _ _ | .nodeAtom _ => none
  | .queryVariable .publicAtom _ | .queryVariable .freshAtom _
  | .queryVariable .message _ | .queryVariable .node _ => none
  | .roleA | .roleB | .unary _ _ | .binary _ _ _ | .kdf _ _ _ => none
  | .list _ | .cons _ _ | .nil => none

def decodeNativeMessage : NativeQueryTerm → Option MessageTerm
  | .atom sort index => some (.atom sort (2 * index + 1))
  | .queryVariable .publicAtom index => some (.atom .publicAtom (2 * index))
  | .queryVariable .freshAtom index => some (.atom .freshAtom (2 * index))
  | .queryVariable .message index => some (.atom .messageAtom (2 * index))
  | .naturalAtom index => some (.natural (.variable (2 * index + 1)))
  | .queryVariable .natural index => some (.natural (.variable (2 * index)))
  | .naturalOne => some (.natural .one)
  | .naturalAdd left right => do
    let first ← decodeNativeNatural left
    let second ← decodeNativeNatural right
    return .natural (.add first second)
  | .roleA => some .roleA
  | .roleB => some .roleB
  | .unary symbol argument => do
    let result ← decodeNativeMessage argument
    return .unary symbol result
  | .binary symbol left right => do
    let first ← decodeNativeMessage left
    let second ← decodeNativeMessage right
    return .binary symbol first second
  | .kdf first second third => do
    let firstResult ← decodeNativeMessage first
    let secondResult ← decodeNativeMessage second
    let thirdResult ← decodeNativeMessage third
    return .kdf firstResult secondResult thirdResult
  | .nodeAtom _ | .queryVariable .node _ | .list _ | .cons _ _ | .nil => none

theorem native_natural_round_trip (term : NaturalTerm) :
    decodeNativeNatural (encodeNativeNatural term) = some term := by
  induction term with
  | one => rfl
  | «variable» identifier =>
    by_cases even : identifier % 2 = 0
    · have recovered : 2 * (identifier / 2) = identifier := by omega
      simp [encodeNativeNatural, decodeNativeNatural, even, recovered]
    · have recovered : 2 * (identifier / 2) + 1 = identifier := by omega
      simp [encodeNativeNatural, decodeNativeNatural, even, recovered]
  | add left right first second =>
    simp [encodeNativeNatural, decodeNativeNatural, first, second]

private theorem native_natural_message_round_trip (term : NaturalTerm) :
    decodeNativeMessage (encodeNativeNatural term) = some (.natural term) := by
  cases term with
  | one => rfl
  | «variable» identifier =>
    by_cases even : identifier % 2 = 0
    · have recovered : 2 * (identifier / 2) = identifier := by omega
      simp [encodeNativeNatural, decodeNativeMessage, even, recovered]
    · have recovered : 2 * (identifier / 2) + 1 = identifier := by omega
      simp [encodeNativeNatural, decodeNativeMessage, even, recovered]
  | add left right =>
    simp [encodeNativeNatural, decodeNativeMessage, native_natural_round_trip]

theorem native_message_round_trip (term : MessageTerm) :
    decodeNativeMessage (encodeNativeMessage term) = some term := by
  induction term with
  | atom sort identifier =>
    by_cases even : identifier % 2 = 0
    · have recovered : 2 * (identifier / 2) = identifier := by omega
      cases sort <;> simp [encodeNativeMessage, atomQuerySort, decodeNativeMessage, even, recovered]
    · have recovered : 2 * (identifier / 2) + 1 = identifier := by omega
      simp [encodeNativeMessage, decodeNativeMessage, even, recovered]
  | natural term => exact native_natural_message_round_trip term
  | roleA => rfl
  | roleB => rfl
  | unary symbol argument induction =>
    simp [encodeNativeMessage, decodeNativeMessage, induction]
  | binary symbol left right first second =>
    simp [encodeNativeMessage, decodeNativeMessage, first, second]
  | kdf first second third firstInduction secondInduction thirdInduction =>
    simp [encodeNativeMessage, decodeNativeMessage, firstInduction, secondInduction, thirdInduction]

theorem native_natural_encoding_injective :
    Function.Injective encodeNativeNatural := by
  intro left right equality
  have decoded := congrArg decodeNativeNatural equality
  simpa [native_natural_round_trip] using decoded

theorem native_message_encoding_injective :
    Function.Injective encodeNativeMessage := by
  intro left right equality
  have decoded := congrArg decodeNativeMessage equality
  simpa [native_message_round_trip] using decoded

#print axioms native_natural_round_trip
#print axioms native_message_round_trip
#print axioms native_natural_encoding_injective
#print axioms native_message_encoding_injective

end Cairn.Equations
