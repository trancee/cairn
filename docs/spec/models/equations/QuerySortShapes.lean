import QuerySortIntersection

namespace Cairn.Equations

theorem native_sorted_add_shape (sort : QuerySort) (left right : NativeQueryTerm) :
    NativeSortedValue sort (.naturalAdd left right) ↔
      (sort = .natural ∨ sort = .message) ∧
        NativeSortedValue .natural left ∧ NativeSortedValue .natural right := by
  simp only [native_sorted_value_check_iff]
  cases sort with
  | publicAtom | freshAtom | node => simp [nativeSortedValueCheck]
  | natural =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural right <;>
      simp_all [nativeSortedValueCheck, decodeNativeNatural]
  | message =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural right <;>
      simp_all [nativeSortedValueCheck, decodeNativeMessage]

theorem native_sorted_unary_shape (sort : QuerySort) (symbol : UnarySymbol) (term : NativeQueryTerm) :
    NativeSortedValue sort (.unary symbol term) ↔
      sort = .message ∧ NativeSortedValue .message term := by
  simp only [native_sorted_value_check_iff]
  cases sort with
  | publicAtom | freshAtom | node => simp [nativeSortedValueCheck]
  | natural => simp [nativeSortedValueCheck, decodeNativeNatural]
  | message =>
    cases decoded : decodeNativeMessage term <;>
      simp_all [nativeSortedValueCheck, decodeNativeMessage]

theorem native_sorted_binary_shape (sort : QuerySort) (symbol : BinarySymbol)
    (left right : NativeQueryTerm) :
    NativeSortedValue sort (.binary symbol left right) ↔
      sort = .message ∧ NativeSortedValue .message left ∧ NativeSortedValue .message right := by
  simp only [native_sorted_value_check_iff]
  cases sort with
  | publicAtom | freshAtom | node => simp [nativeSortedValueCheck]
  | natural => simp [nativeSortedValueCheck, decodeNativeNatural]
  | message =>
    cases first : decodeNativeMessage left <;> cases second : decodeNativeMessage right <;>
      simp_all [nativeSortedValueCheck, decodeNativeMessage]

theorem native_sorted_kdf_shape (sort : QuerySort) (first second third : NativeQueryTerm) :
    NativeSortedValue sort (.kdf first second third) ↔
      sort = .message ∧ NativeSortedValue .message first ∧
        NativeSortedValue .message second ∧ NativeSortedValue .message third := by
  simp only [native_sorted_value_check_iff]
  cases sort with
  | publicAtom | freshAtom | node => simp [nativeSortedValueCheck]
  | natural => simp [nativeSortedValueCheck, decodeNativeNatural]
  | message =>
    cases firstDecoded : decodeNativeMessage first <;>
      cases secondDecoded : decodeNativeMessage second <;>
      cases thirdDecoded : decodeNativeMessage third <;>
      simp_all [nativeSortedValueCheck, decodeNativeMessage]

#print axioms native_sorted_add_shape
#print axioms native_sorted_unary_shape
#print axioms native_sorted_binary_shape
#print axioms native_sorted_kdf_shape

end Cairn.Equations
