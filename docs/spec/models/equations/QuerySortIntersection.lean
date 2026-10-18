import QuerySystems

namespace Cairn.Equations

def nativeSortedValueCheck : QuerySort → NativeQueryTerm → Bool
  | .message, term => (decodeNativeMessage term).isSome
  | .natural, term => (decodeNativeNatural term).isSome
  | .publicAtom, .atom .publicAtom _ | .publicAtom, .queryVariable .publicAtom _ => true
  | .freshAtom, .atom .freshAtom _ | .freshAtom, .queryVariable .freshAtom _ => true
  | .node, .nodeAtom _ | .node, .queryVariable .node _ => true
  | .publicAtom, _ | .freshAtom, _ | .node, _ => false

theorem native_sorted_value_check_iff (sort : QuerySort) (term : NativeQueryTerm) :
    NativeSortedValue sort term ↔ nativeSortedValueCheck sort term = true := by
  constructor
  · intro value
    cases value with
    | publicAtom | publicVariable | freshAtom | freshVariable | nodeAtom | nodeVariable => rfl
    | message decoded => simp [nativeSortedValueCheck, decoded]
    | natural decoded => simp [nativeSortedValueCheck, decoded]
  · intro accepted
    cases sort with
    | message =>
      cases decoded : decodeNativeMessage term with
      | none => simp [nativeSortedValueCheck, decoded] at accepted
      | some value => exact .message decoded
    | natural =>
      cases decoded : decodeNativeNatural term with
      | none => simp [nativeSortedValueCheck, decoded] at accepted
      | some value => exact .natural decoded
    | publicAtom | freshAtom | node =>
      cases term with
      | atom atomSort index =>
        cases atomSort <;> simp_all [nativeSortedValueCheck] <;>
          first | exact .publicAtom | exact .freshAtom
      | queryVariable source index =>
        cases source <;> simp_all [nativeSortedValueCheck] <;>
          first | exact .publicVariable | exact .freshVariable | exact .nodeVariable
      | nodeAtom index => simp_all [nativeSortedValueCheck] <;> exact .nodeAtom
      | naturalAtom | naturalOne | naturalAdd | roleA | roleB | unary | binary | kdf |
          list | cons | nil => simp [nativeSortedValueCheck] at accepted

def nativeSortIntersection : QuerySort → QuerySort → Option QuerySort
  | .publicAtom, .publicAtom | .publicAtom, .message | .message, .publicAtom => some .publicAtom
  | .freshAtom, .freshAtom | .freshAtom, .message | .message, .freshAtom => some .freshAtom
  | .natural, .natural | .natural, .message | .message, .natural => some .natural
  | .message, .message => some .message
  | .node, .node => some .node
  | .publicAtom, .freshAtom | .publicAtom, .natural | .publicAtom, .node |
      .freshAtom, .publicAtom | .freshAtom, .natural | .freshAtom, .node |
      .natural, .publicAtom | .natural, .freshAtom | .natural, .node |
      .node, .publicAtom | .node, .freshAtom | .node, .natural |
      .message, .node | .node, .message => none

private theorem public_message (value : NativeSortedValue .publicAtom term) :
    NativeSortedValue .message term := by
  cases value <;> exact .message rfl

private theorem fresh_message (value : NativeSortedValue .freshAtom term) :
    NativeSortedValue .message term := by
  cases value <;> exact .message rfl

private theorem natural_message (value : NativeSortedValue .natural term) :
    NativeSortedValue .message term := by
  cases value with
  | @natural _ natural decoded =>
    rw [← native_natural_recognition _ decoded]
    exact .message (native_message_round_trip (.natural natural))

theorem native_sort_intersection_iff (first second : QuerySort) (term : NativeQueryTerm) :
    (NativeSortedValue first term ∧ NativeSortedValue second term) ↔
      ∃ refined, nativeSortIntersection first second = some refined ∧
        NativeSortedValue refined term := by
  cases first <;> cases second <;> simp only [nativeSortIntersection]
  all_goals first
    | exact ⟨fun both => ⟨_, rfl, both.1⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨value, value⟩⟩
    | exact ⟨fun both => ⟨_, rfl, both.1⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨value, public_message value⟩⟩
    | exact ⟨fun both => ⟨_, rfl, both.2⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨public_message value, value⟩⟩
    | exact ⟨fun both => ⟨_, rfl, both.1⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨value, fresh_message value⟩⟩
    | exact ⟨fun both => ⟨_, rfl, both.2⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨fresh_message value, value⟩⟩
    | exact ⟨fun both => ⟨_, rfl, both.1⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨value, natural_message value⟩⟩
    | exact ⟨fun both => ⟨_, rfl, both.2⟩, fun ⟨_, equal, value⟩ => by
        cases equal
        exact ⟨natural_message value, value⟩⟩
    | constructor
      · intro both
        cases both.1 <;> cases both.2 <;>
          simp_all [decodeNativeMessage, decodeNativeNatural]
      · rintro ⟨_, equal, _⟩
        cases equal

#print axioms native_sorted_value_check_iff
#print axioms native_sort_intersection_iff

end Cairn.Equations
