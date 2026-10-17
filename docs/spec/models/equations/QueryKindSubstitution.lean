import QuerySortedSubstitution

namespace Cairn.Equations

theorem native_kind_natural_image (decoded : decodeNativeNatural term = some source) :
    ∃ result, decodeNativeNatural (relabelNative kindAbstraction term) = some result := by
  induction term generalizing source with
  | naturalOne | naturalAtom => exact ⟨_, rfl⟩
  | queryVariable sort index =>
    cases sort <;> simp only [decodeNativeNatural, reduceCtorEq] at decoded
    exact ⟨_, rfl⟩
  | naturalAdd left right first second =>
    cases firstDecoded : decodeNativeNatural left <;>
      cases secondDecoded : decodeNativeNatural right <;>
      simp [decodeNativeNatural, firstDecoded, secondDecoded] at decoded
    obtain ⟨firstResult, firstImage⟩ := first firstDecoded
    obtain ⟨secondResult, secondImage⟩ := second secondDecoded
    exact ⟨.add firstResult secondResult,
      by simp [relabelNative, decodeNativeNatural, firstImage, secondImage]⟩
  | atom | nodeAtom | roleA | roleB | unary | binary | kdf | list | cons | nil =>
    simp [decodeNativeNatural] at decoded

theorem native_kind_proper_image (proper : NativeProperMessage term) :
    NativeProperMessage (relabelNative kindAbstraction term) := by
  obtain ⟨source, decoded⟩ := proper
  induction term generalizing source with
  | atom sort index => cases sort <;> exact ⟨_, rfl⟩
  | naturalOne | naturalAtom | roleA | roleB => exact ⟨_, rfl⟩
  | queryVariable sort index =>
    cases sort <;> simp only [decodeNativeMessage, reduceCtorEq] at decoded
    all_goals exact ⟨_, rfl⟩
  | naturalAdd left right first second =>
    cases firstDecoded : decodeNativeNatural left <;>
      cases secondDecoded : decodeNativeNatural right <;>
      simp [decodeNativeMessage, firstDecoded, secondDecoded] at decoded
    obtain ⟨firstResult, firstImage⟩ := native_kind_natural_image firstDecoded
    obtain ⟨secondResult, secondImage⟩ := native_kind_natural_image secondDecoded
    exact ⟨.natural (.add firstResult secondResult),
      by simp [relabelNative, decodeNativeMessage, firstImage, secondImage]⟩
  | unary symbol argument induction =>
    cases child : decodeNativeMessage argument <;> simp [decodeNativeMessage, child] at decoded
    obtain ⟨childResult, childImage⟩ := induction _ child
    exact ⟨.unary symbol childResult, by simp [relabelNative, decodeNativeMessage, childImage]⟩
  | binary symbol left right first second =>
    cases firstDecoded : decodeNativeMessage left <;>
      cases secondDecoded : decodeNativeMessage right <;>
      simp [decodeNativeMessage, firstDecoded, secondDecoded] at decoded
    obtain ⟨firstResult, firstImage⟩ := first _ firstDecoded
    obtain ⟨secondResult, secondImage⟩ := second _ secondDecoded
    exact ⟨.binary symbol firstResult secondResult,
      by simp [relabelNative, decodeNativeMessage, firstImage, secondImage]⟩
  | kdf first second third firstInduction secondInduction thirdInduction =>
    cases firstDecoded : decodeNativeMessage first <;>
      cases secondDecoded : decodeNativeMessage second <;>
      cases thirdDecoded : decodeNativeMessage third <;>
      simp [decodeNativeMessage, firstDecoded, secondDecoded, thirdDecoded] at decoded
    obtain ⟨firstResult, firstImage⟩ := firstInduction _ firstDecoded
    obtain ⟨secondResult, secondImage⟩ := secondInduction _ secondDecoded
    obtain ⟨thirdResult, thirdImage⟩ := thirdInduction _ thirdDecoded
    exact ⟨.kdf firstResult secondResult thirdResult,
      by simp [relabelNative, decodeNativeMessage, firstImage, secondImage, thirdImage]⟩
  | nodeAtom | list | cons | nil => simp [decodeNativeMessage] at decoded

private theorem abstract_public (value : NativeSortedValue .publicAtom term) :
    NativeSortedValue .publicAtom (relabelNative kindAbstraction term) := by
  cases value with
  | publicAtom => exact .publicAtom
  | publicVariable => exact .publicVariable

private theorem abstract_fresh (value : NativeSortedValue .freshAtom term) :
    NativeSortedValue .natural (relabelNative kindAbstraction term) := by
  cases value with
  | freshAtom => exact .natural rfl
  | freshVariable => exact .natural rfl

private theorem abstract_node (value : NativeSortedValue .node term) :
    NativeSortedValue .node (relabelNative kindAbstraction term) := by
  cases value with
  | nodeAtom => exact .nodeAtom
  | nodeVariable => exact .nodeVariable

theorem native_kind_assignment_sorted (sorted : NativeSortedAssignment assignment) :
    NativeSortedAssignment (abstractKindAssignment assignment) := by
  intro sort index
  cases sort with
  | publicAtom => exact abstract_public (sorted .publicAtom index)
  | freshAtom => exact .freshVariable
  | message =>
    have value := sorted .message index
    cases value with
    | message decoded =>
      obtain ⟨_, image⟩ := native_kind_proper_image ⟨_, decoded⟩
      exact .message image
  | natural =>
    simp only [abstractKindAssignment]
    split
    · have value := sorted .natural (index / 2)
      cases value with
      | natural decoded =>
        obtain ⟨_, image⟩ := native_kind_natural_image decoded
        exact .natural image
    · exact abstract_fresh (sorted .freshAtom (index / 2))
  | node => exact abstract_node (sorted .node index)

theorem native_kind_shadow_representation (sorted : NativeSortedAssignment assignment) :
    ∃ shadow : QuerySubstitution,
      abstractKindAssignment assignment = nativeQueryAssignment shadow := by
  obtain ⟨shadow, compatible⟩ :=
    native_sorted_assignment_representation (native_kind_assignment_sorted sorted)
  exact ⟨shadow, compatible.symm⟩

theorem native_kind_sorted_framed_substitution (sorted : NativeSortedAssignment assignment)
    (image : NativeKindFramedImage term) :
    NativeKindFramedImage (substituteNativeQuery assignment term) := by
  obtain ⟨shadow, compatible⟩ := native_kind_shadow_representation sorted
  exact native_kind_framed_substitution assignment shadow compatible image

#print axioms native_kind_natural_image
#print axioms native_kind_proper_image
#print axioms native_kind_assignment_sorted
#print axioms native_kind_shadow_representation
#print axioms native_kind_sorted_framed_substitution

end Cairn.Equations
