import QuerySourceTerms

namespace Cairn.Equations

def nativeQueryACSetoid : Setoid NativeQueryTerm where
  r := NativeQueryAC
  iseqv := ⟨fun _ => .reflexive, fun related => .symmetric related,
    fun first second => .transitive first second⟩

abbrev NativeACClass : Type := Quotient nativeQueryACSetoid

def nativeACClassOf (term : NativeQueryTerm) : NativeACClass := Quotient.mk _ term

theorem native_ac_class_eq_iff :
    nativeACClassOf left = nativeACClassOf right ↔ NativeQueryAC left right := by
  constructor
  · exact Quotient.exact
  · intro related
    exact Quotient.sound related

def nativeACClassAdd (first second : NativeACClass) : NativeACClass :=
  Quotient.liftOn₂ first second (fun left right => nativeACClassOf (.naturalAdd left right))
    (fun _ _ _ _ left right => Quotient.sound (.naturalAdd left right))

theorem native_ac_class_add_associative (first second third : NativeACClass) :
    nativeACClassAdd (nativeACClassAdd first second) third =
      nativeACClassAdd first (nativeACClassAdd second third) := by
  refine Quotient.inductionOn₃ first second third (fun _ _ _ => ?_)
  exact Quotient.sound .associative

theorem native_ac_class_add_commutative (first second : NativeACClass) :
    nativeACClassAdd first second = nativeACClassAdd second first := by
  refine Quotient.inductionOn₂ first second (fun _ _ => ?_)
  exact Quotient.sound .commutative

def nativeACWordJoin : Option NativeACClass → Option NativeACClass → Option NativeACClass
  | none, right => right
  | left, none => left
  | some left, some right => some (nativeACClassAdd left right)

private theorem join_associative (first second third : Option NativeACClass) :
    nativeACWordJoin (nativeACWordJoin first second) third =
      nativeACWordJoin first (nativeACWordJoin second third) := by
  cases first <;> cases second <;> cases third <;> simp only [nativeACWordJoin]
  exact congrArg some (native_ac_class_add_associative _ _ _)

private theorem join_commutative (first second : Option NativeACClass) :
    nativeACWordJoin first second = nativeACWordJoin second first := by
  cases first <;> cases second <;> simp only [nativeACWordJoin]
  exact congrArg some (native_ac_class_add_commutative _ _)

private theorem join_swap (first second third : Option NativeACClass) :
    nativeACWordJoin first (nativeACWordJoin second third) =
      nativeACWordJoin second (nativeACWordJoin first third) := by
  rw [← join_associative, join_commutative first second, join_associative]

def nativeACWordValue : List NativeACClass → Option NativeACClass
  | [] => none
  | first :: rest => nativeACWordJoin (some first) (nativeACWordValue rest)

theorem native_ac_word_append (first second : List NativeACClass) :
    nativeACWordValue (first ++ second) =
      nativeACWordJoin (nativeACWordValue first) (nativeACWordValue second) := by
  induction first with
  | nil => rfl
  | cons _ _ induction => simp only [List.cons_append, nativeACWordValue, induction, join_associative]

theorem native_ac_word_permutation (permutation : first.Perm second) :
    nativeACWordValue first = nativeACWordValue second := by
  induction permutation with
  | nil => rfl
  | cons _ _ induction => simp only [nativeACWordValue, induction]
  | swap => exact join_swap _ _ _
  | trans _ _ first second => exact first.trans second

def nativeACAtomWord : NativeQueryTerm → List NativeACClass
  | .naturalAdd left right => nativeACAtomWord left ++ nativeACAtomWord right
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.queryVariable _ _) | term@(.naturalOne) | term@(.roleA) | term@(.roleB) |
      term@(.unary _ _) | term@(.binary _ _ _) | term@(.kdf _ _ _) |
      term@(.list _) | term@(.cons _ _) | term@(.nil) => [nativeACClassOf term]

theorem native_ac_atom_word_nonempty (term : NativeQueryTerm) : nativeACAtomWord term ≠ [] := by
  induction term with
  | naturalAdd left right first _ =>
    intro empty
    change nativeACAtomWord left ++ nativeACAtomWord right = [] at empty
    exact first (List.append_eq_nil_iff.mp empty).1
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil => simp [nativeACAtomWord]

theorem native_ac_atom_word_value (term : NativeQueryTerm) :
    nativeACWordValue (nativeACAtomWord term) = some (nativeACClassOf term) := by
  induction term with
  | naturalAdd _ _ first second =>
    rw [nativeACAtomWord, native_ac_word_append, first, second]
    rfl
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil => rfl

private theorem fixed_word (notAddition : nativeQueryHead term ≠ .naturalAdd) :
    nativeACAtomWord term = [nativeACClassOf term] := by
  cases term <;> simp_all [nativeQueryHead, nativeACAtomWord]

private theorem fixed_words_related (equivalent : NativeQueryAC left right)
    (notAddition : nativeQueryHead left ≠ .naturalAdd) :
    (nativeACAtomWord left).Perm (nativeACAtomWord right) := by
  have other : nativeQueryHead right ≠ .naturalAdd := by
    rw [← native_query_ac_head equivalent]
    exact notAddition
  rw [fixed_word notAddition, fixed_word other, native_ac_class_eq_iff.mpr equivalent]

theorem native_ac_atom_word_preservation (equivalent : NativeQueryAC left right) :
    (nativeACAtomWord left).Perm (nativeACAtomWord right) := by
  induction equivalent with
  | reflexive => exact .refl _
  | symmetric _ induction => exact induction.symm
  | transitive _ _ first second => exact first.trans second
  | associative => simp only [nativeACAtomWord, List.append_assoc]; exact .refl _
  | commutative => exact List.perm_append_comm
  | naturalAdd _ _ first second => exact first.append second
  | unary related _ => exact fixed_words_related (.unary related) (by intro impossible; cases impossible)
  | binary first second _ _ =>
    exact fixed_words_related (.binary first second) (by intro impossible; cases impossible)
  | kdf first second third _ _ _ =>
    exact fixed_words_related (.kdf first second third) (by intro impossible; cases impossible)
  | list related _ => exact fixed_words_related (.list related) (by intro impossible; cases impossible)
  | cons first second _ _ =>
    exact fixed_words_related (.cons first second) (by intro impossible; cases impossible)

theorem native_ac_atom_word_iff :
    NativeQueryAC left right ↔ (nativeACAtomWord left).Perm (nativeACAtomWord right) := by
  refine ⟨native_ac_atom_word_preservation, fun permutation => ?_⟩
  have same := native_ac_word_permutation permutation
  rw [native_ac_atom_word_value, native_ac_atom_word_value] at same
  exact native_ac_class_eq_iff.mp (Option.some.inj same)

def nativeACClassWeight (value : NativeACClass) : Nat :=
  Quotient.liftOn value (fun term => nativeQueryFunctionCount term + 1)
    (fun _ _ related => congrArg (· + 1) (native_query_ac_preserves_count related))

theorem native_ac_class_weight_positive (value : NativeACClass) : 0 < nativeACClassWeight value := by
  exact Quotient.inductionOn value (fun _ => Nat.zero_lt_succ _)

theorem native_ac_class_weight_add (first second : NativeACClass) :
    nativeACClassWeight (nativeACClassAdd first second) =
      nativeACClassWeight first + nativeACClassWeight second := by
  refine Quotient.inductionOn₂ first second (fun left right => ?_)
  change nativeQueryFunctionCount (.naturalAdd left right) + 1 =
    (nativeQueryFunctionCount left + 1) + (nativeQueryFunctionCount right + 1)
  simp only [nativeQueryFunctionCount]
  omega

#print axioms native_ac_class_eq_iff
#print axioms native_ac_class_add_associative
#print axioms native_ac_class_add_commutative
#print axioms native_ac_word_append
#print axioms native_ac_word_permutation
#print axioms native_ac_atom_word_nonempty
#print axioms native_ac_atom_word_value
#print axioms native_ac_atom_word_iff
#print axioms native_ac_class_weight_positive
#print axioms native_ac_class_weight_add

end Cairn.Equations
