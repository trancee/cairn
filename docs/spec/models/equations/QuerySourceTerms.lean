import QueryConstructors
import QuerySystems

namespace Cairn.Equations

deriving instance DecidableEq for AtomSort
deriving instance DecidableEq for UnarySymbol
deriving instance DecidableEq for BinarySymbol
deriving instance DecidableEq for NativeQueryTerm
deriving instance DecidableEq for NativeQueryHead

def nativeQueryChildren : NativeQueryTerm → List NativeQueryTerm
  | .unary _ argument | .list argument => [argument]
  | .binary _ left right | .naturalAdd left right | .cons left right => [left, right]
  | .kdf first second third => [first, second, third]
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .queryVariable _ _ |
      .naturalOne | .roleA | .roleB | .nil => []

def nativeQuerySubterms : NativeQueryTerm → List NativeQueryTerm
  | term@(.unary _ argument) | term@(.list argument) => term :: nativeQuerySubterms argument
  | term@(.binary _ left right) | term@(.naturalAdd left right) | term@(.cons left right) =>
    term :: (nativeQuerySubterms left ++ nativeQuerySubterms right)
  | term@(.kdf first second third) =>
    term :: (nativeQuerySubterms first ++ nativeQuerySubterms second ++ nativeQuerySubterms third)
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.queryVariable _ _) | term@(.naturalOne) | term@(.roleA) |
      term@(.roleB) | term@(.nil) => [term]

def nativeSystemSubterms (equations : NativeEquationSystem) : List NativeQueryTerm :=
  equations.flatMap (fun equation => nativeQuerySubterms equation.1 ++ nativeQuerySubterms equation.2)

theorem native_subterms_self (term : NativeQueryTerm) : term ∈ nativeQuerySubterms term := by
  cases term <;> simp [nativeQuerySubterms]

theorem native_subterms_children (member : child ∈ nativeQueryChildren parent) :
    child ∈ nativeQuerySubterms parent := by
  cases parent <;> simp_all [nativeQueryChildren, nativeQuerySubterms, native_subterms_self]
  all_goals first
    | rcases member with rfl | rfl <;> simp [native_subterms_self]
    | rcases member with rfl | rfl | rfl <;> simp [native_subterms_self]

theorem native_subterms_transitive (member : middle ∈ nativeQuerySubterms parent)
    (nested : child ∈ nativeQuerySubterms middle) : child ∈ nativeQuerySubterms parent := by
  induction parent generalizing middle with
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB | nil =>
    have equal := List.mem_singleton.mp member
    subst middle
    exact nested
  | unary _ _ induction | list _ induction =>
    rcases List.mem_cons.mp member with rfl | member
    · exact nested
    · exact List.mem_cons_of_mem _ (induction member nested)
  | binary _ _ _ first second | naturalAdd _ _ first second | cons _ _ first second =>
    rcases List.mem_cons.mp member with rfl | member
    · exact nested
    · apply List.mem_cons_of_mem
      rcases List.mem_append.mp member with left | right
      · exact List.mem_append.mpr (.inl (first left nested))
      · exact List.mem_append.mpr (.inr (second right nested))
  | kdf _ _ _ first second third =>
    rcases List.mem_cons.mp member with rfl | member
    · exact nested
    · apply List.mem_cons_of_mem
      rcases List.mem_append.mp member with left | right
      · rcases List.mem_append.mp left with firstMember | secondMember
        · exact List.mem_append.mpr (.inl (List.mem_append.mpr (.inl (first firstMember nested))))
        · exact List.mem_append.mpr (.inl (List.mem_append.mpr (.inr (second secondMember nested))))
      · exact List.mem_append.mpr (.inr (third right nested))

theorem native_system_subterms_children (member : parent ∈ nativeSystemSubterms equations)
    (childMember : child ∈ nativeQueryChildren parent) :
    child ∈ nativeSystemSubterms equations := by
  obtain ⟨equation, included, occurs⟩ := List.mem_flatMap.mp member
  refine List.mem_flatMap.mpr ⟨equation, included, ?_⟩
  rcases List.mem_append.mp occurs with left | right
  · exact List.mem_append.mpr (.inl
      (native_subterms_transitive left (native_subterms_children childMember)))
  · exact List.mem_append.mpr (.inr
      (native_subterms_transitive right (native_subterms_children childMember)))

theorem native_system_subterms_roots (member : equation ∈ equations) :
    equation.1 ∈ nativeSystemSubterms equations ∧ equation.2 ∈ nativeSystemSubterms equations := by
  exact ⟨List.mem_flatMap.mpr ⟨equation, member,
    List.mem_append.mpr (.inl (native_subterms_self _))⟩,
    List.mem_flatMap.mpr ⟨equation, member,
      List.mem_append.mpr (.inr (native_subterms_self _))⟩⟩

theorem native_variable_subterm (member : (sort, index) ∈ nativeQueryVariables term) :
    NativeQueryTerm.queryVariable sort index ∈ nativeQuerySubterms term := by
  induction term with
  | queryVariable _ _ =>
    obtain ⟨rfl, rfl⟩ := Prod.mk.inj (List.mem_singleton.mp member)
    exact List.mem_singleton.mpr rfl
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    simp [nativeQueryVariables] at member
  | unary _ _ induction | list _ induction =>
    exact List.mem_cons_of_mem _ (induction member)
  | naturalAdd _ _ first second | binary _ _ _ first second | cons _ _ first second =>
    apply List.mem_cons_of_mem
    rcases List.mem_append.mp member with left | right
    · exact List.mem_append.mpr (.inl (first left))
    · exact List.mem_append.mpr (.inr (second right))
  | kdf _ _ _ first second third =>
    apply List.mem_cons_of_mem
    rcases List.mem_append.mp member with left | right
    · rcases List.mem_append.mp left with firstMember | secondMember
      · exact List.mem_append.mpr (.inl (List.mem_append.mpr (.inl (first firstMember))))
      · exact List.mem_append.mpr (.inl (List.mem_append.mpr (.inr (second secondMember))))
    · exact List.mem_append.mpr (.inr (third right))

theorem native_system_variable_subterm (member : (sort, index) ∈ nativeSystemVariables equations) :
    NativeQueryTerm.queryVariable sort index ∈ nativeSystemSubterms equations := by
  obtain ⟨equation, included, occurs⟩ := List.mem_flatMap.mp member
  refine List.mem_flatMap.mpr ⟨equation, included, ?_⟩
  rcases List.mem_append.mp occurs with left | right
  · exact List.mem_append.mpr (.inl (native_variable_subterm left))
  · exact List.mem_append.mpr (.inr (native_variable_subterm right))

theorem native_variable_subterm_iff (term : NativeQueryTerm) :
    NativeQueryTerm.queryVariable sort index ∈ nativeQuerySubterms term ↔
      (sort, index) ∈ nativeQueryVariables term := by
  induction term <;> simp_all [nativeQuerySubterms, nativeQueryVariables]

theorem native_system_variable_subterm_iff :
    NativeQueryTerm.queryVariable sort index ∈ nativeSystemSubterms equations ↔
      (sort, index) ∈ nativeSystemVariables equations := by
  constructor
  · intro member
    obtain ⟨equation, included, occurs⟩ := List.mem_flatMap.mp member
    refine List.mem_flatMap.mpr ⟨equation, included, ?_⟩
    rcases List.mem_append.mp occurs with first | second
    · exact List.mem_append.mpr (.inl ((native_variable_subterm_iff _).mp first))
    · exact List.mem_append.mpr (.inr ((native_variable_subterm_iff _).mp second))
  · exact native_system_variable_subterm

#print axioms native_subterms_self
#print axioms native_subterms_children
#print axioms native_subterms_transitive
#print axioms native_system_subterms_children
#print axioms native_system_subterms_roots
#print axioms native_variable_subterm
#print axioms native_system_variable_subterm
#print axioms native_variable_subterm_iff
#print axioms native_system_variable_subterm_iff

end Cairn.Equations
