import QueryInstances

namespace Cairn.Equations

def composeQuerySubstitutions (first second : QuerySubstitution) : QuerySubstitution where
  publicAtoms index :=
    let label := first.publicAtoms index
    if label % 2 = 0 then second.publicAtoms (label / 2) else label
  freshAtoms index :=
    let label := first.freshAtoms index
    if label % 2 = 0 then second.freshAtoms (label / 2) else label
  messages index := substituteQueryMessage second (first.messages index)
  naturals index := substituteQueryNatural second (first.naturals index)
  nodes index :=
    let label := first.nodes index
    if label % 2 = 0 then second.nodes (label / 2) else label

theorem native_query_composition (first second : QuerySubstitution) :
    nativeQueryAssignment (composeQuerySubstitutions first second) =
      composeNativeAssignments (nativeQueryAssignment first) (nativeQueryAssignment second) := by
  funext sort index
  cases sort with
  | publicAtom =>
    change encodeNativeMessage (.atom .publicAtom _) =
      substituteNativeQuery (nativeQueryAssignment second)
        (encodeNativeMessage (.atom .publicAtom (first.publicAtoms index)))
    rw [← native_message_substitution]
    by_cases even : first.publicAtoms index % 2 = 0 <;>
      simp [composeQuerySubstitutions, substituteQueryMessage, even]
  | freshAtom =>
    change encodeNativeMessage (.atom .freshAtom _) =
      substituteNativeQuery (nativeQueryAssignment second)
        (encodeNativeMessage (.atom .freshAtom (first.freshAtoms index)))
    rw [← native_message_substitution]
    by_cases even : first.freshAtoms index % 2 = 0 <;>
      simp [composeQuerySubstitutions, substituteQueryMessage, even]
  | message => exact native_message_substitution second (first.messages index)
  | natural => exact native_natural_substitution second (first.naturals index)
  | node =>
    by_cases even : first.nodes index % 2 = 0 <;>
      simp [nativeQueryAssignment, composeQuerySubstitutions, composeNativeAssignments,
        substituteNativeQuery, even]

def QueryAssignmentACOn (variables : List (QuerySort × Nat))
    (first second : QuerySubstitution) : Prop :=
  ∀ sort index, (sort, index) ∈ variables →
    match sort with
    | .publicAtom => first.publicAtoms index = second.publicAtoms index
    | .freshAtom => first.freshAtoms index = second.freshAtoms index
    | .message => MessageAC (first.messages index) (second.messages index)
    | .natural => NaturalAC (first.naturals index) (second.naturals index)
    | .node => first.nodes index = second.nodes index

-- AC changes sum structure, never a leaf's constructor, sort or index.
def nativeQueryLeaf : NativeQueryTerm → Option NativeQueryTerm
  | .atom sort index => some (.atom sort index)
  | .naturalAtom index => some (.naturalAtom index)
  | .nodeAtom index => some (.nodeAtom index)
  | .queryVariable sort index => some (.queryVariable sort index)
  | .naturalOne => some .naturalOne
  | .roleA => some .roleA
  | .roleB => some .roleB
  | .nil => some .nil
  | .naturalAdd _ _ | .unary _ _ | .binary _ _ _ | .kdf _ _ _ | .list _ | .cons _ _ => none

theorem native_query_ac_leaf (equivalent : NativeQueryAC left right) :
    nativeQueryLeaf left = nativeQueryLeaf right := by
  induction equivalent <;> simp_all [nativeQueryLeaf]

private theorem encoded_atom_leaf (sort : AtomSort) (label : Nat) :
    nativeQueryLeaf (encodeNativeMessage (.atom sort label)) =
      some (encodeNativeMessage (.atom sort label)) := by
  simp only [encodeNativeMessage]
  split <;> rfl

private theorem encoded_atom_ac_iff (sort : AtomSort) (first second : Nat) :
    NativeQueryAC (encodeNativeMessage (.atom sort first))
      (encodeNativeMessage (.atom sort second)) ↔ first = second := by
  constructor
  · intro equivalent
    have equal := native_query_ac_leaf equivalent
    rw [encoded_atom_leaf, encoded_atom_leaf] at equal
    exact (MessageTerm.atom.inj
      (native_message_encoding_injective (Option.some.inj equal))).2
  · rintro rfl
    exact .reflexive

private def nodeCode (label : Nat) : NativeQueryTerm :=
  if label % 2 = 0 then .queryVariable .node (label / 2) else .nodeAtom (label / 2)

private theorem node_code_leaf (label : Nat) :
    nativeQueryLeaf (nodeCode label) = some (nodeCode label) := by
  unfold nodeCode
  split <;> rfl

private theorem node_code_injective : Function.Injective nodeCode := by
  intro first second equal
  by_cases firstEven : first % 2 = 0 <;> by_cases secondEven : second % 2 = 0
  all_goals simp [nodeCode, firstEven, secondEven] at equal
  all_goals omega

theorem native_query_assignment_ac_on_iff (variables : List (QuerySort × Nat))
    (first second : QuerySubstitution) :
    NativeAssignmentACOn variables (nativeQueryAssignment first) (nativeQueryAssignment second) ↔
      QueryAssignmentACOn variables first second := by
  constructor
  · intro equivalent sort index member
    have related := equivalent sort index member
    cases sort with
    | publicAtom => exact (encoded_atom_ac_iff .publicAtom _ _).mp related
    | freshAtom => exact (encoded_atom_ac_iff .freshAtom _ _).mp related
    | message => exact native_message_ac_reflection related
    | natural => exact native_natural_ac_reflection related
    | node =>
      have equal := native_query_ac_leaf related
      change nativeQueryLeaf (nodeCode (first.nodes index)) =
        nativeQueryLeaf (nodeCode (second.nodes index)) at equal
      rw [node_code_leaf, node_code_leaf] at equal
      exact node_code_injective (Option.some.inj equal)
  · intro equivalent sort index member
    have related := equivalent sort index member
    cases sort with
    | publicAtom =>
      change first.publicAtoms index = second.publicAtoms index at related
      simp only [nativeQueryAssignment, related]
      exact .reflexive
    | freshAtom =>
      change first.freshAtoms index = second.freshAtoms index at related
      simp only [nativeQueryAssignment, related]
      exact .reflexive
    | message => exact native_message_ac_preservation related
    | natural => exact native_natural_ac_preservation related
    | node =>
      change first.nodes index = second.nodes index at related
      simp only [nativeQueryAssignment, related]
      exact .reflexive

def QueryACInstanceOn (variables : List (QuerySort × Nat))
    (general specific : QuerySubstitution) : Prop :=
  ∃ factor : QuerySubstitution,
    QueryAssignmentACOn variables specific (composeQuerySubstitutions general factor)

theorem native_query_ac_instance_iff (variables : List (QuerySort × Nat))
    (general specific : QuerySubstitution) :
    NativeACInstanceOn variables (nativeQueryAssignment general) (nativeQueryAssignment specific) ↔
      QueryACInstanceOn variables general specific := by
  constructor
  · rintro ⟨factor, sorted, equivalent⟩
    obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation sorted
    rw [← compatible, ← native_query_composition] at equivalent
    exact ⟨typed, (native_query_assignment_ac_on_iff variables _ _).mp equivalent⟩
  · rintro ⟨factor, equivalent⟩
    refine ⟨nativeQueryAssignment factor, native_typed_assignment_sorted factor, ?_⟩
    rw [← native_query_composition]
    exact (native_query_assignment_ac_on_iff variables _ _).mpr equivalent

#print axioms native_query_composition
#print axioms native_query_ac_leaf
#print axioms native_query_assignment_ac_on_iff
#print axioms native_query_ac_instance_iff

end Cairn.Equations
