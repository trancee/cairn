import QuerySortRequirements

namespace Cairn.Equations

theorem native_sort_requirements_iff (assignment : QuerySort → Nat → NativeQueryTerm)
    (sorted : NativeSortedAssignment assignment) (expected : QuerySort) (term : NativeQueryTerm) :
    NativeSortedValue expected (substituteNativeQuery assignment term) ↔
      NativeSortRequirementsHold (nativeSortRequirements expected term) assignment := by
  induction term generalizing expected with
  | queryVariable source index =>
    simp only [substituteNativeQuery, nativeSortRequirements]
    cases found : nativeSortIntersection source expected with
    | none =>
      simp only [NativeSortRequirementsHold]
      constructor
      · intro value
        obtain ⟨refined, compatible, _⟩ :=
          (native_sort_intersection_iff source expected _).mp ⟨sorted source index, value⟩
        rw [found] at compatible
        cases compatible
      · exact False.elim
    | some refined =>
      simp only [NativeSortRequirementsHold, List.mem_singleton, forall_eq]
      constructor
      · intro value
        obtain ⟨actual, compatible, accepted⟩ :=
          (native_sort_intersection_iff source expected _).mp ⟨sorted source index, value⟩
        rw [found] at compatible
        cases compatible
        exact accepted
      · intro value
        exact ((native_sort_intersection_iff source expected _).mpr ⟨refined, found, value⟩).2
  | naturalAdd left right first second =>
    simp only [substituteNativeQuery, native_sorted_add_shape, nativeSortRequirements]
    by_cases allowed : expected = .natural ∨ expected = .message
    · rw [ite_eq_left allowed, native_sort_requirements_append_iff]
      simp only [allowed, true_and, first .natural, second .natural]
    · rw [ite_eq_right allowed]
      simp only [allowed, false_and, NativeSortRequirementsHold]
  | unary symbol argument induction =>
    simp only [substituteNativeQuery, native_sorted_unary_shape, nativeSortRequirements]
    by_cases allowed : expected = .message
    · rw [ite_eq_left allowed]
      simp only [allowed, true_and, induction .message]
    · rw [ite_eq_right allowed]
      simp only [allowed, false_and, NativeSortRequirementsHold]
  | binary symbol left right first second =>
    simp only [substituteNativeQuery, native_sorted_binary_shape, nativeSortRequirements]
    by_cases allowed : expected = .message
    · rw [ite_eq_left allowed, native_sort_requirements_append_iff]
      simp only [allowed, true_and, first .message, second .message]
    · rw [ite_eq_right allowed]
      simp only [allowed, false_and, NativeSortRequirementsHold]
  | kdf first second third firstInduction secondInduction thirdInduction =>
    simp only [substituteNativeQuery, native_sorted_kdf_shape, nativeSortRequirements]
    by_cases allowed : expected = .message
    · rw [ite_eq_left allowed, native_sort_requirements_append_iff,
        native_sort_requirements_append_iff]
      simp only [allowed, true_and, firstInduction .message,
        secondInduction .message, thirdInduction .message]
    · rw [ite_eq_right allowed]
      simp only [allowed, false_and, NativeSortRequirementsHold]
  | atom sort index => exact native_ground_sort_requirements_iff expected (.atom sort index) assignment
  | naturalAtom index => exact native_ground_sort_requirements_iff expected (.naturalAtom index) assignment
  | nodeAtom index => exact native_ground_sort_requirements_iff expected (.nodeAtom index) assignment
  | naturalOne => exact native_ground_sort_requirements_iff expected .naturalOne assignment
  | roleA => exact native_ground_sort_requirements_iff expected .roleA assignment
  | roleB => exact native_ground_sort_requirements_iff expected .roleB assignment
  | list | cons | nil =>
    simp only [substituteNativeQuery, nativeSortRequirements, NativeSortRequirementsHold,
      native_sorted_value_check_iff]
    cases expected with
    | publicAtom | freshAtom | node => simp [nativeSortedValueCheck]
    | message => simp [nativeSortedValueCheck, decodeNativeMessage]
    | natural => simp [nativeSortedValueCheck, decodeNativeNatural]

#print axioms native_sort_requirements_iff

end Cairn.Equations
