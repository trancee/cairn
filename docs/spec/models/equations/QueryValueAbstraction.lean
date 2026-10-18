import QueryPrincipalSort

namespace Cairn.Equations

theorem native_sorted_value_ac_iff (equivalent : NativeQueryAC left right) (sort : QuerySort) :
    NativeSortedValue sort left ↔ NativeSortedValue sort right := by
  induction equivalent generalizing sort with
  | reflexive => rfl
  | symmetric _ induction => exact (induction sort).symm
  | transitive _ _ first second => exact (first sort).trans (second sort)
  | associative => simp [native_sorted_add_shape, and_assoc]
  | commutative =>
    simp only [native_sorted_add_shape]
    exact ⟨fun ⟨allowed, first, second⟩ => ⟨allowed, second, first⟩,
      fun ⟨allowed, first, second⟩ => ⟨allowed, second, first⟩⟩
  | naturalAdd _ _ first second =>
    simp only [native_sorted_add_shape, first .natural, second .natural]
  | unary _ induction => simp only [native_sorted_unary_shape, induction .message]
  | binary _ _ first second =>
    simp only [native_sorted_binary_shape, first .message, second .message]
  | kdf _ _ _ first second third =>
    simp only [native_sorted_kdf_shape, first .message, second .message, third .message]
  | list | cons =>
    cases sort <;> simp [native_sorted_value_check_iff, nativeSortedValueCheck,
      decodeNativeMessage, decodeNativeNatural]

theorem native_unrestricted_sort_fingerprint_substitution
    (fingerprint : ∀ sort index expected,
      NativeSortedValue expected (first sort index) ↔
        NativeSortedValue expected (second sort index))
    (term : NativeQueryTerm) (expected : QuerySort) :
    NativeSortedValue expected (substituteNativeQuery first term) ↔
      NativeSortedValue expected (substituteNativeQuery second term) := by
  induction term generalizing expected with
  | queryVariable sort index => exact fingerprint sort index expected
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil => rfl
  | naturalAdd _ _ first second =>
    simp only [substituteNativeQuery, native_sorted_add_shape, first .natural, second .natural]
  | unary _ _ induction =>
    simp only [substituteNativeQuery, native_sorted_unary_shape, induction .message]
  | binary _ _ _ first second =>
    simp only [substituteNativeQuery, native_sorted_binary_shape, first .message, second .message]
  | kdf _ _ _ first second third =>
    simp only [substituteNativeQuery, native_sorted_kdf_shape,
      first .message, second .message, third .message]
  | list | cons =>
    cases expected <;> simp [substituteNativeQuery, native_sorted_value_check_iff,
      nativeSortedValueCheck, decodeNativeMessage, decodeNativeNatural]

theorem native_sorted_substitution_variable_proper
    (proper : NativeSortedValue expected (substituteNativeQuery assignment term))
    (member : (sort, index) ∈ nativeQueryVariables term) :
    ∃ principal, NativeSortedValue principal (assignment sort index) := by
  induction term generalizing expected with
  | queryVariable source position =>
    have equal := List.mem_singleton.mp member
    cases equal
    exact ⟨expected, proper⟩
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    simp [nativeQueryVariables] at member
  | naturalAdd _ _ first second =>
    have values := (native_sorted_add_shape expected _ _).mp proper
    rcases List.mem_append.mp member with left | right
    · exact first values.2.1 left
    · exact second values.2.2 right
  | unary _ _ induction =>
    exact induction ((native_sorted_unary_shape expected _ _).mp proper).2 member
  | binary _ _ _ first second =>
    have values := (native_sorted_binary_shape expected _ _ _).mp proper
    rcases List.mem_append.mp member with left | right
    · exact first values.2.1 left
    · exact second values.2.2 right
  | kdf _ _ _ first second third =>
    have values := (native_sorted_kdf_shape expected _ _ _).mp proper
    rcases List.mem_append.mp member with left | right
    · rcases List.mem_append.mp left with firstMember | secondMember
      · exact first values.2.1 firstMember
      · exact second values.2.2.1 secondMember
    · exact third values.2.2.2 right
  | list | cons =>
    cases expected <;> simp [substituteNativeQuery, native_sorted_value_check_iff,
      nativeSortedValueCheck, decodeNativeMessage, decodeNativeNatural] at proper

#print axioms native_sorted_value_ac_iff
#print axioms native_unrestricted_sort_fingerprint_substitution
#print axioms native_sorted_substitution_variable_proper

end Cairn.Equations
