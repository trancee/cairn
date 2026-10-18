import QueryAC

namespace Cairn.Equations

inductive NativeQueryHead where
  | atom (sort : AtomSort) (index : Nat)
  | naturalAtom (index : Nat)
  | nodeAtom (index : Nat)
  | queryVariable (sort : QuerySort) (index : Nat)
  | naturalOne
  | naturalAdd
  | roleA
  | roleB
  | unary (symbol : UnarySymbol)
  | binary (symbol : BinarySymbol)
  | kdf
  | list
  | cons
  | nil

def nativeQueryHead : NativeQueryTerm → NativeQueryHead
  | .atom sort index => .atom sort index
  | .naturalAtom index => .naturalAtom index
  | .nodeAtom index => .nodeAtom index
  | .queryVariable sort index => .queryVariable sort index
  | .naturalOne => .naturalOne
  | .naturalAdd _ _ => .naturalAdd
  | .roleA => .roleA
  | .roleB => .roleB
  | .unary symbol _ => .unary symbol
  | .binary symbol _ _ => .binary symbol
  | .kdf _ _ _ => .kdf
  | .list _ => .list
  | .cons _ _ => .cons
  | .nil => .nil

-- Addition has no ordered free-constructor arguments modulo AC.
def nativeFreeChildren : NativeQueryTerm → List NativeQueryTerm
  | .unary _ argument | .list argument => [argument]
  | .binary _ first second | .cons first second => [first, second]
  | .kdf first second third => [first, second, third]
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .queryVariable _ _
  | .naturalOne | .naturalAdd _ _ | .roleA | .roleB | .nil => []

def NativeChildrenAC : List NativeQueryTerm → List NativeQueryTerm → Prop
  | [], [] => True
  | first :: rest, second :: remaining =>
    NativeQueryAC first second ∧ NativeChildrenAC rest remaining
  | [], _ :: _ | _ :: _, [] => False

private theorem children_reflexive (terms : List NativeQueryTerm) :
    NativeChildrenAC terms terms := by
  induction terms with
  | nil => trivial
  | cons _ _ induction => exact ⟨.reflexive, induction⟩

private theorem children_symmetric (related : NativeChildrenAC left right) :
    NativeChildrenAC right left := by
  induction left generalizing right with
  | nil => cases right <;> simp_all [NativeChildrenAC]
  | cons _ _ induction =>
    cases right with
    | nil => exact related.elim
    | cons _ _ => exact ⟨.symmetric related.1, induction related.2⟩

private theorem children_transitive (first : NativeChildrenAC left middle)
    (second : NativeChildrenAC middle right) : NativeChildrenAC left right := by
  induction left generalizing middle right with
  | nil => cases middle <;> cases right <;> simp_all [NativeChildrenAC]
  | cons _ _ induction =>
    cases middle with
    | nil => exact first.elim
    | cons _ _ =>
      cases right with
      | nil => exact second.elim
      | cons _ _ => exact ⟨.transitive first.1 second.1, induction first.2 second.2⟩

theorem native_query_ac_head (equivalent : NativeQueryAC left right) :
    nativeQueryHead left = nativeQueryHead right := by
  induction equivalent <;> simp_all [nativeQueryHead]

theorem native_query_ac_free_children (equivalent : NativeQueryAC left right) :
    NativeChildrenAC (nativeFreeChildren left) (nativeFreeChildren right) := by
  induction equivalent with
  | reflexive => exact children_reflexive _
  | symmetric _ induction => exact children_symmetric induction
  | transitive _ _ first second => exact children_transitive first second
  | associative | commutative | naturalAdd => trivial
  | unary equivalent _ | list equivalent _ => exact ⟨equivalent, trivial⟩
  | binary first second _ _ | cons first second _ _ =>
    exact ⟨first, second, trivial⟩
  | kdf first second third _ _ _ => exact ⟨first, second, third, trivial⟩

theorem native_query_ac_constructor_iff (notAddition : nativeQueryHead left ≠ .naturalAdd) :
    NativeQueryAC left right ↔
      nativeQueryHead left = nativeQueryHead right ∧
        NativeChildrenAC (nativeFreeChildren left) (nativeFreeChildren right) := by
  constructor
  · intro equivalent
    exact ⟨native_query_ac_head equivalent, native_query_ac_free_children equivalent⟩
  · rintro ⟨head, children⟩
    cases left <;> cases right <;> simp_all [nativeQueryHead, nativeFreeChildren, NativeChildrenAC]
    all_goals first
      | exact .reflexive
      | exact .unary children
      | exact .binary children.1 children.2
      | exact .kdf children.1 children.2.1 children.2.2
      | exact .list children
      | exact .cons children.1 children.2

theorem native_ac_unary_iff :
    NativeQueryAC (.unary symbol left) (.unary symbol right) ↔ NativeQueryAC left right := by
  rw [native_query_ac_constructor_iff (by intro impossible; cases impossible)]
  simp [nativeQueryHead, nativeFreeChildren, NativeChildrenAC]

theorem native_ac_binary_iff :
    NativeQueryAC (.binary symbol firstLeft secondLeft) (.binary symbol firstRight secondRight) ↔
      NativeQueryAC firstLeft firstRight ∧ NativeQueryAC secondLeft secondRight := by
  rw [native_query_ac_constructor_iff (by intro impossible; cases impossible)]
  simp [nativeQueryHead, nativeFreeChildren, NativeChildrenAC]

theorem native_ac_kdf_iff :
    NativeQueryAC (.kdf firstLeft secondLeft thirdLeft) (.kdf firstRight secondRight thirdRight) ↔
      NativeQueryAC firstLeft firstRight ∧ NativeQueryAC secondLeft secondRight ∧
        NativeQueryAC thirdLeft thirdRight := by
  rw [native_query_ac_constructor_iff (by intro impossible; cases impossible)]
  simp [nativeQueryHead, nativeFreeChildren, NativeChildrenAC]

theorem native_ac_list_iff :
    NativeQueryAC (.list left) (.list right) ↔ NativeQueryAC left right := by
  rw [native_query_ac_constructor_iff (by intro impossible; cases impossible)]
  simp [nativeQueryHead, nativeFreeChildren, NativeChildrenAC]

theorem native_ac_cons_iff :
    NativeQueryAC (.cons firstLeft secondLeft) (.cons firstRight secondRight) ↔
      NativeQueryAC firstLeft firstRight ∧ NativeQueryAC secondLeft secondRight := by
  rw [native_query_ac_constructor_iff (by intro impossible; cases impossible)]
  simp [nativeQueryHead, nativeFreeChildren, NativeChildrenAC]

#print axioms native_query_ac_head
#print axioms native_query_ac_free_children
#print axioms native_query_ac_constructor_iff
#print axioms native_ac_unary_iff
#print axioms native_ac_binary_iff
#print axioms native_ac_kdf_iff
#print axioms native_ac_list_iff
#print axioms native_ac_cons_iff

end Cairn.Equations
