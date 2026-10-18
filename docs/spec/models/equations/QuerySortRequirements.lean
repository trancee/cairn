import QuerySortShapes

namespace Cairn.Equations

abbrev NativeSortConstraint : Type := (QuerySort × Nat) × QuerySort

def appendNativeSortRequirements
    (first second : Option (List NativeSortConstraint)) : Option (List NativeSortConstraint) :=
  match first, second with
  | some left, some right => some (left ++ right)
  | none, _ | _, none => none

def nativeGroundSortRequirements (expected : QuerySort) (term : NativeQueryTerm) :
    Option (List NativeSortConstraint) :=
  if nativeSortedValueCheck expected term then some [] else none

def nativeSortRequirements (expected : QuerySort) : NativeQueryTerm → Option (List NativeSortConstraint)
  | .queryVariable source index =>
    match nativeSortIntersection source expected with
    | none => none
    | some refined => some [((source, index), refined)]
  | .naturalAdd left right =>
    if expected = .natural ∨ expected = .message then
      appendNativeSortRequirements (nativeSortRequirements .natural left)
        (nativeSortRequirements .natural right)
    else none
  | .unary _ argument =>
    if expected = .message then nativeSortRequirements .message argument else none
  | .binary _ left right =>
    if expected = .message then
      appendNativeSortRequirements (nativeSortRequirements .message left)
        (nativeSortRequirements .message right)
    else none
  | .kdf first second third =>
    if expected = .message then
      appendNativeSortRequirements (nativeSortRequirements .message first)
        (appendNativeSortRequirements (nativeSortRequirements .message second)
          (nativeSortRequirements .message third))
    else none
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.naturalOne) | term@(.roleA) | term@(.roleB) =>
    nativeGroundSortRequirements expected term
  | .list _ | .cons _ _ | .nil => none

def NativeSortRequirementsHold
    (requirements : Option (List NativeSortConstraint))
    (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  match requirements with
  | none => False
  | some constraints => ∀ constraint ∈ constraints,
    NativeSortedValue constraint.2 (assignment constraint.1.1 constraint.1.2)

theorem native_sort_requirements_append_iff (first second : Option (List NativeSortConstraint))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeSortRequirementsHold (appendNativeSortRequirements first second) assignment ↔
      NativeSortRequirementsHold first assignment ∧ NativeSortRequirementsHold second assignment := by
  cases first <;> cases second <;> simp [appendNativeSortRequirements, NativeSortRequirementsHold]
  constructor
  · intro holds
    exact ⟨fun sort index refined member => holds sort index refined (.inl member),
      fun sort index refined member => holds sort index refined (.inr member)⟩
  · rintro ⟨left, right⟩ sort index refined member
    rcases member with member | member
    · exact left sort index refined member
    · exact right sort index refined member

theorem native_ground_sort_requirements_iff (sort : QuerySort) (term : NativeQueryTerm)
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeSortedValue sort term ↔
      NativeSortRequirementsHold (nativeGroundSortRequirements sort term) assignment := by
  rw [native_sorted_value_check_iff]
  cases accepted : nativeSortedValueCheck sort term <;>
    simp [nativeGroundSortRequirements, NativeSortRequirementsHold, accepted]

#print axioms native_sort_requirements_append_iff
#print axioms native_ground_sort_requirements_iff

end Cairn.Equations
