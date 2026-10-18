import QuerySortRefinement

namespace Cairn.Equations

def nativePrincipalSort (term : NativeQueryTerm) : Option QuerySort :=
  if nativeSortedValueCheck .publicAtom term then some .publicAtom
  else if nativeSortedValueCheck .freshAtom term then some .freshAtom
  else if nativeSortedValueCheck .natural term then some .natural
  else if nativeSortedValueCheck .message term then some .message
  else if nativeSortedValueCheck .node term then some .node
  else none

private theorem intersection_widens
    (compatible : nativeSortIntersection expected actual = some actual)
    (value : NativeSortedValue actual term) : NativeSortedValue expected term :=
  ((native_sort_intersection_iff expected actual term).mpr ⟨actual, compatible, value⟩).1

private theorem intersection_excludes
    (incompatible : nativeSortIntersection expected actual = none)
    (value : NativeSortedValue actual term) : ¬ NativeSortedValue expected term := by
  intro other
  obtain ⟨refined, found, _⟩ :=
    (native_sort_intersection_iff expected actual term).mp ⟨other, value⟩
  rw [incompatible] at found
  cases found

private theorem narrow_fingerprint (notMessage : actual ≠ .message)
    (value : NativeSortedValue actual term) (expected : QuerySort) (index : Nat) :
    NativeSortedValue expected term ↔
      NativeSortedValue expected (.queryVariable actual index) := by
  by_cases widens : nativeSortIntersection expected actual = some actual
  · exact ⟨fun _ => intersection_widens widens (native_identity_assignment_sorted actual index),
      fun _ => intersection_widens widens value⟩
  · have absent : nativeSortIntersection expected actual = none := by
      cases expected <;> cases actual <;> simp_all [nativeSortIntersection]
    exact ⟨fun other => (intersection_excludes absent value other).elim,
      fun other => (intersection_excludes absent
        (native_identity_assignment_sorted actual index) other).elim⟩

private theorem message_variable_iff (expected : QuerySort) (index : Nat) :
    NativeSortedValue expected (.queryVariable .message index) ↔ expected = .message := by
  cases expected <;> simp [native_sorted_value_check_iff, nativeSortedValueCheck,
    decodeNativeMessage, decodeNativeNatural]

private theorem message_fingerprint
    (value : NativeSortedValue .message term)
    (notPublic : ¬ nativeSortedValueCheck .publicAtom term = true)
    (notFresh : ¬ nativeSortedValueCheck .freshAtom term = true)
    (notNatural : ¬ nativeSortedValueCheck .natural term = true)
    (expected : QuerySort) (index : Nat) :
    NativeSortedValue expected term ↔
      NativeSortedValue expected (.queryVariable .message index) := by
  rw [message_variable_iff]
  cases expected with
  | message => exact ⟨fun _ => rfl, fun _ => value⟩
  | publicAtom =>
    exact ⟨fun other => (notPublic ((native_sorted_value_check_iff _ _).mp other)).elim,
      fun impossible => by cases impossible⟩
  | freshAtom =>
    exact ⟨fun other => (notFresh ((native_sorted_value_check_iff _ _).mp other)).elim,
      fun impossible => by cases impossible⟩
  | natural =>
    exact ⟨fun other => (notNatural ((native_sorted_value_check_iff _ _).mp other)).elim,
      fun impossible => by cases impossible⟩
  | node =>
    exact ⟨fun other => (intersection_excludes rfl value other).elim,
      fun impossible => by cases impossible⟩

private theorem principal_fingerprint (found : nativePrincipalSort term = some actual)
    (expected : QuerySort) (index : Nat) :
    NativeSortedValue expected term ↔
      NativeSortedValue expected (.queryVariable actual index) := by
  unfold nativePrincipalSort at found
  split at found
  · cases found
    exact narrow_fingerprint (by decide) ((native_sorted_value_check_iff _ _).mpr ‹_›) expected index
  · rename_i notPublic
    split at found
    · cases found
      exact narrow_fingerprint (by decide) ((native_sorted_value_check_iff _ _).mpr ‹_›) expected index
    · rename_i notFresh
      split at found
      · cases found
        exact narrow_fingerprint (by decide) ((native_sorted_value_check_iff _ _).mpr ‹_›) expected index
      · rename_i notNatural
        split at found
        · cases found
          exact message_fingerprint ((native_sorted_value_check_iff _ _).mpr ‹_›)
            notPublic notFresh notNatural expected index
        · split at found
          · cases found
            exact narrow_fingerprint (by decide)
              ((native_sorted_value_check_iff _ _).mpr ‹_›) expected index
          · cases found

private theorem principal_exists (value : NativeSortedValue expected term) :
    ∃ actual, nativePrincipalSort term = some actual := by
  unfold nativePrincipalSort
  split
  · exact ⟨_, rfl⟩
  · rename_i notPublic
    split
    · exact ⟨_, rfl⟩
    · rename_i notFresh
      split
      · exact ⟨_, rfl⟩
      · rename_i notNatural
        split
        · exact ⟨_, rfl⟩
        · rename_i notMessage
          split
          · exact ⟨_, rfl⟩
          · rename_i notNode
            have accepted := (native_sorted_value_check_iff expected term).mp value
            cases expected with
            | publicAtom => exact (notPublic accepted).elim
            | freshAtom => exact (notFresh accepted).elim
            | natural => exact (notNatural accepted).elim
            | message => exact (notMessage accepted).elim
            | node => exact (notNode accepted).elim

theorem native_principal_sort_iff (term : NativeQueryTerm) (expected : QuerySort) (index : Nat) :
    NativeSortedValue expected term ↔
      ∃ principal, nativePrincipalSort term = some principal ∧
        NativeSortedValue expected (.queryVariable principal index) := by
  constructor
  · intro value
    obtain ⟨principal, found⟩ := principal_exists value
    exact ⟨principal, found, (principal_fingerprint found expected index).mp value⟩
  · rintro ⟨principal, found, value⟩
    exact (principal_fingerprint found expected index).mpr value

#print axioms native_principal_sort_iff

end Cairn.Equations
