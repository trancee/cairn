import QueryRawPlans

namespace Cairn.Equations

def nativeRebuildQueryNode (values : NativeQueryTerm → NativeQueryTerm) :
    NativeQueryTerm → NativeQueryTerm
  | .naturalAdd left right => .naturalAdd (values left) (values right)
  | .unary symbol argument => .unary symbol (values argument)
  | .binary symbol left right => .binary symbol (values left) (values right)
  | .kdf first second third => .kdf (values first) (values second) (values third)
  | .list argument => .list (values argument)
  | .cons first second => .cons (values first) (values second)
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.queryVariable _ _) | term@(.naturalOne) |
      term@(.roleA) | term@(.roleB) | term@(.nil) => term

theorem native_build_query_node (values : NativeQueryTerm → NativeQueryTerm)
    (term : NativeQueryTerm) :
    nativeBuildQueryHead (nativeQueryHead term) ((nativeQueryChildren term).map values) =
      some (nativeRebuildQueryNode values term) := by
  cases term <;> rfl

theorem native_rebuild_query_node_equal (first second : NativeQueryTerm)
    (head : nativeQueryHead first = nativeQueryHead second)
    (children : (nativeQueryChildren first).map values = (nativeQueryChildren second).map values) :
    nativeRebuildQueryNode values first = nativeRebuildQueryNode values second := by
  apply Option.some.inj
  rw [← native_build_query_node, ← native_build_query_node, head, children]

theorem native_source_term_realization (source : List NativeQueryTerm)
    (values : NativeQueryTerm → NativeQueryTerm) (assignment : QuerySort → Nat → NativeQueryTerm)
    (closed : ∀ parent ∈ source, ∀ child ∈ nativeQueryChildren parent, child ∈ source)
    (variables : ∀ sort index, NativeQueryTerm.queryVariable sort index ∈ source →
      NativeQueryAC (assignment sort index) (values (.queryVariable sort index)))
    (rigid : ∀ term ∈ source, nativeRawRigidNode term = true →
      NativeQueryAC (values term) (nativeRebuildQueryNode values term))
    (addition : ∀ left right, NativeQueryTerm.naturalAdd left right ∈ source →
      NativeQueryAC (values (.naturalAdd left right)) (.naturalAdd (values left) (values right)))
    (member : term ∈ source) :
    NativeQueryAC (substituteNativeQuery assignment term) (values term) := by
  induction term with
  | queryVariable sort index => exact variables sort index member
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    exact .symmetric (rigid _ member rfl)
  | naturalAdd left right first second =>
    exact .transitive (.naturalAdd
      (first (closed _ member _ (by simp [nativeQueryChildren])))
      (second (closed _ member _ (by simp [nativeQueryChildren]))))
      (.symmetric (addition left right member))
  | unary symbol argument induction =>
    exact .transitive (.unary (induction
      (closed _ member _ (by simp [nativeQueryChildren])))) (.symmetric (rigid _ member rfl))
  | list argument induction =>
    exact .transitive (.list (induction
      (closed _ member _ (by simp [nativeQueryChildren])))) (.symmetric (rigid _ member rfl))
  | binary symbol left right first second =>
    exact .transitive (.binary
      (first (closed _ member _ (by simp [nativeQueryChildren])))
      (second (closed _ member _ (by simp [nativeQueryChildren]))))
      (.symmetric (rigid _ member rfl))
  | cons left right first second =>
    exact .transitive (.cons
      (first (closed _ member _ (by simp [nativeQueryChildren])))
      (second (closed _ member _ (by simp [nativeQueryChildren]))))
      (.symmetric (rigid _ member rfl))
  | kdf first second third firstInduction secondInduction thirdInduction =>
    exact .transitive (.kdf
      (firstInduction (closed _ member _ (by simp [nativeQueryChildren])))
      (secondInduction (closed _ member _ (by simp [nativeQueryChildren])))
      (thirdInduction (closed _ member _ (by simp [nativeQueryChildren]))))
      (.symmetric (rigid _ member rfl))

theorem native_source_child_substitution_count
    (assignment : QuerySort → Nat → NativeQueryTerm)
    (member : child ∈ nativeQueryChildren parent) :
    nativeQueryFunctionCount (substituteNativeQuery assignment child) <
      nativeQueryFunctionCount (substituteNativeQuery assignment parent) := by
  cases parent <;> simp only [nativeQueryChildren, List.mem_cons,
    List.not_mem_nil, or_false] at member
  all_goals first
    | contradiction
    | subst child; simp only [substituteNativeQuery, nativeQueryFunctionCount]; omega
    | rcases member with rfl | rfl <;>
        simp only [substituteNativeQuery, nativeQueryFunctionCount] <;> omega
    | rcases member with rfl | rfl | rfl <;>
        simp only [substituteNativeQuery, nativeQueryFunctionCount] <;> omega

#print axioms native_build_query_node
#print axioms native_rebuild_query_node_equal
#print axioms native_source_term_realization
#print axioms native_source_child_substitution_count

end Cairn.Equations
