import QueryNaturalRendering

namespace Cairn.Equations

def nativeRawRigidNode : NativeQueryTerm → Bool
  | .queryVariable _ _ | .naturalAdd _ _ => false
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .naturalOne | .roleA | .roleB |
      .unary _ _ | .binary _ _ _ | .kdf _ _ _ | .list _ | .cons _ _ | .nil => true

def nativeRawLabel (source : List NativeQueryTerm) (labels : List Nat)
    (term : NativeQueryTerm) : Nat :=
  labels[source.idxOf term]?.getD source.length

def nativeRawLabelWords (size : Nat) : List (List Nat) :=
  (integerBoundedWords (List.range size) size).filter (fun labels => labels.length == size)

def NativeRawPlanConsistent (equations : NativeEquationSystem)
    (label : NativeQueryTerm → Nat) : Prop :=
  (∀ equation ∈ equations, label equation.1 = label equation.2) ∧
    ∀ first ∈ nativeSystemSubterms equations, ∀ second ∈ nativeSystemSubterms equations,
      nativeRawRigidNode first = true → nativeRawRigidNode second = true →
      label first = label second →
      nativeQueryHead first = nativeQueryHead second ∧
        (nativeQueryChildren first).map label = (nativeQueryChildren second).map label

instance (equations : NativeEquationSystem) (label : NativeQueryTerm → Nat) :
    Decidable (NativeRawPlanConsistent equations label) := by
  unfold NativeRawPlanConsistent
  infer_instance

def nativeRawNodeEquation (label : NativeQueryTerm → Nat) :
    NativeQueryTerm → Option (NaturalTerm × NaturalTerm)
  | .queryVariable _ _ => none
  | term@(.naturalAdd left right) =>
    some (.variable (2 * label term),
      .add (.variable (2 * label left)) (.variable (2 * label right)))
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.naturalOne) | term@(.roleA) | term@(.roleB) |
      term@(.unary _ _) | term@(.binary _ _ _) | term@(.kdf _ _ _) |
      term@(.list _) | term@(.cons _ _) | term@(.nil) =>
    some (.variable (2 * label term), .variable (2 * label term + 1))

def nativeRawNaturalSystem (equations : NativeEquationSystem)
    (label : NativeQueryTerm → Nat) : NaturalEquationSystem :=
  (nativeSystemSubterms equations).filterMap (nativeRawNodeEquation label) ++
    (List.range (nativeSystemSubterms equations).length).map
      (fun index => (.variable (2 * index), .variable (2 * index)))

def nativeRawMarkers (source : List NativeQueryTerm) (label : NativeQueryTerm → Nat) : List Nat :=
  ((source.filter nativeRawRigidNode).map label).eraseDups

def nativeRawRepresentative (source : List NativeQueryTerm)
    (label : NativeQueryTerm → Nat) (marker : Nat) : Option NativeQueryTerm :=
  source.find? (fun term => nativeRawRigidNode term && label term == marker)

def nativeBuildQueryHead : NativeQueryHead → List NativeQueryTerm → Option NativeQueryTerm
  | .atom sort index, [] => some (.atom sort index)
  | .naturalAtom index, [] => some (.naturalAtom index)
  | .nodeAtom index, [] => some (.nodeAtom index)
  | .queryVariable sort index, [] => some (.queryVariable sort index)
  | .naturalOne, [] => some .naturalOne
  | .naturalAdd, [left, right] => some (.naturalAdd left right)
  | .roleA, [] => some .roleA
  | .roleB, [] => some .roleB
  | .unary symbol, [argument] => some (.unary symbol argument)
  | .binary symbol, [left, right] => some (.binary symbol left right)
  | .kdf, [first, second, third] => some (.kdf first second third)
  | .list, [argument] => some (.list argument)
  | .cons, [first, second] => some (.cons first second)
  | .nil, [] => some .nil
  | .atom _ _, _ | .naturalAtom _, _ | .nodeAtom _, _ | .queryVariable _ _, _ |
      .naturalOne, _ | .naturalAdd, _ | .roleA, _ | .roleB, _ | .unary _, _ |
      .binary _, _ | .kdf, _ | .list, _ | .cons, _ | .nil, _ => none

def nativeRawRenderMarker (source : List NativeQueryTerm) (label : NativeQueryTerm → Nat)
    (assignment : QuerySort → Nat → NativeQueryTerm) (available : List Nat)
    (marker : Nat) : Option NativeQueryTerm :=
  if _present : marker ∈ available then do
    let representative ← nativeRawRepresentative source label marker
    let children ← (nativeQueryChildren representative).mapM (fun child =>
      nativeRenderNatural
        (nativeRawRenderMarker source label assignment (available.filter (fun index => index != marker)))
        (assignment .natural (label child)))
    nativeBuildQueryHead (nativeQueryHead representative) children
  else none
termination_by available.length
decreasing_by simpa using native_marker_removal_shorter _present

theorem native_raw_label_map (source : List NativeQueryTerm) (label : NativeQueryTerm → Nat)
    (member : term ∈ source) :
    nativeRawLabel source (source.map label) term = label term := by
  unfold nativeRawLabel
  rw [List.getElem?_map, List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem member)]
  simp [List.getElem_idxOf (List.idxOf_lt_length_of_mem member)]

theorem native_raw_label_words_iff (size : Nat) (labels : List Nat) :
    labels ∈ nativeRawLabelWords size ↔
      labels.length = size ∧ ∀ label ∈ labels, label < size := by
  simp only [nativeRawLabelWords, List.mem_filter, integer_bounded_words_iff, beq_iff_eq,
    List.mem_range]
  constructor
  · rintro ⟨⟨_, bounded⟩, length⟩
    exact ⟨length, bounded⟩
  · rintro ⟨length, bounded⟩
    exact ⟨⟨by omega, bounded⟩, length⟩

theorem native_raw_label_bound (included : labels ∈ nativeRawLabelWords source.length)
    (member : term ∈ source) : nativeRawLabel source labels term < source.length := by
  have description := (native_raw_label_words_iff source.length labels).mp included
  have bounded : source.idxOf term < labels.length := by
    rw [description.1]
    exact List.idxOf_lt_length_of_mem member
  unfold nativeRawLabel
  rw [List.getElem?_eq_getElem bounded]
  exact description.2 _ (List.getElem_mem bounded)

theorem native_raw_rigid_equation (rigid : nativeRawRigidNode term = true) :
    nativeRawNodeEquation label term =
      some (.variable (2 * label term), .variable (2 * label term + 1)) := by
  cases term <;> simp_all [nativeRawRigidNode, nativeRawNodeEquation]

theorem native_raw_node_equation_member (member : term ∈ nativeSystemSubterms equations)
    (compiled : nativeRawNodeEquation label term = some equation) :
    equation ∈ nativeRawNaturalSystem equations label := by
  exact List.mem_append.mpr (.inl (List.mem_filterMap.mpr ⟨term, member, compiled⟩))

#print axioms native_raw_label_map
#print axioms native_raw_label_words_iff
#print axioms native_raw_label_bound
#print axioms native_raw_rigid_equation
#print axioms native_raw_node_equation_member

end Cairn.Equations
