import QueryImage

namespace Cairn.Equations

private theorem encode_even_natural (index : Nat) :
    encodeNativeNatural (.variable (2 * index)) = .queryVariable .natural index := by
  have even : (2 * index) % 2 = 0 := by omega
  have division : (2 * index) / 2 = index := by omega
  simp [encodeNativeNatural, even, division]

private theorem encode_odd_natural (index : Nat) :
    encodeNativeNatural (.variable (2 * index + 1)) = .naturalAtom index := by
  have division : (2 * index + 1) / 2 = index := by omega
  simp [encodeNativeNatural, division]

private theorem encode_even_atom (sort : AtomSort) (index : Nat) :
    encodeNativeMessage (.atom sort (2 * index)) = .queryVariable (atomQuerySort sort) index := by
  have even : (2 * index) % 2 = 0 := by omega
  have division : (2 * index) / 2 = index := by omega
  simp [encodeNativeMessage, even, division]

private theorem encode_odd_atom (sort : AtomSort) (index : Nat) :
    encodeNativeMessage (.atom sort (2 * index + 1)) = .atom sort index := by
  have division : (2 * index + 1) / 2 = index := by omega
  simp [encodeNativeMessage, division]

theorem native_natural_recognition (native : NativeQueryTerm)
    (decoded : decodeNativeNatural native = some term) : encodeNativeNatural term = native := by
  induction native generalizing term with
  | naturalOne => simp [decodeNativeNatural] at decoded; subst term; rfl
  | naturalAtom index =>
    simp [decodeNativeNatural] at decoded
    subst term
    exact encode_odd_natural index
  | queryVariable sort index =>
    cases sort <;> simp [decodeNativeNatural] at decoded
    subst term
    exact encode_even_natural index
  | naturalAdd left right firstInduction secondInduction =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural right <;>
      simp [decodeNativeNatural, first, second] at decoded
    subst term
    simp only [encodeNativeNatural]
    rw [firstInduction first, secondInduction second]
  | atom | nodeAtom | roleA | roleB | unary | binary | kdf | list | cons | nil =>
    simp [decodeNativeNatural] at decoded

theorem native_message_recognition (native : NativeQueryTerm)
    (decoded : decodeNativeMessage native = some term) : encodeNativeMessage term = native := by
  induction native generalizing term with
  | atom sort index =>
    simp [decodeNativeMessage] at decoded
    subst term
    exact encode_odd_atom sort index
  | queryVariable sort index =>
    cases sort <;> simp [decodeNativeMessage] at decoded
    all_goals subst term
    · exact encode_even_atom .publicAtom index
    · exact encode_even_atom .freshAtom index
    · exact encode_even_atom .messageAtom index
    · exact encode_even_natural index
  | naturalAtom index =>
    simp [decodeNativeMessage] at decoded
    subst term
    exact encode_odd_natural index
  | naturalOne => simp [decodeNativeMessage] at decoded; subst term; rfl
  | naturalAdd left right firstInduction secondInduction =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural right <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    simp only [encodeNativeMessage, encodeNativeNatural]
    rw [native_natural_recognition left first, native_natural_recognition right second]
  | roleA => simp [decodeNativeMessage] at decoded; subst term; rfl
  | roleB => simp [decodeNativeMessage] at decoded; subst term; rfl
  | unary symbol argument induction =>
    cases child : decodeNativeMessage argument <;> simp [decodeNativeMessage, child] at decoded
    subst term
    simp only [encodeNativeMessage]
    rw [induction child]
  | binary symbol left right firstInduction secondInduction =>
    cases first : decodeNativeMessage left <;> cases second : decodeNativeMessage right <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    simp only [encodeNativeMessage]
    rw [firstInduction first, secondInduction second]
  | kdf first second third firstInduction secondInduction thirdInduction =>
    cases firstValue : decodeNativeMessage first <;>
      cases secondValue : decodeNativeMessage second <;>
      cases thirdValue : decodeNativeMessage third <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    simp only [encodeNativeMessage]
    rw [firstInduction firstValue, secondInduction secondValue, thirdInduction thirdValue]
  | nodeAtom | list | cons | nil => simp [decodeNativeMessage] at decoded

#print axioms native_natural_recognition
#print axioms native_message_recognition

end Cairn.Equations
