import QueryACWords
import QueryModule

/-!
Executable AC canonical form for native query terms. Natural sums are flattened,
their canonical summands sorted by rendering, and the result right-nested. Equal
canonical forms decide `NativeQueryAC`, so a reply certificate can check AC equality.
-/

namespace Cairn.Equations

def nativeACOrder (left right : NativeQueryTerm) : Bool :=
  decide (nativeMaudeChars left ≤ nativeMaudeChars right)

def nativeACSummands : NativeQueryTerm → List NativeQueryTerm
  | .naturalAdd left right => nativeACSummands left ++ nativeACSummands right
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.queryVariable _ _) | term@(.naturalOne) | term@(.roleA) | term@(.roleB) |
      term@(.unary _ _) | term@(.binary _ _ _) | term@(.kdf _ _ _) |
      term@(.list _) | term@(.cons _ _) | term@(.nil) => [term]

def nativeACRebuild : List NativeQueryTerm → NativeQueryTerm
  | [] => .naturalOne
  | [term] => term
  | first :: second :: rest => .naturalAdd first (nativeACRebuild (second :: rest))

def nativeACCanonical : NativeQueryTerm → NativeQueryTerm
  | .naturalAdd left right => nativeACRebuild
      ((nativeACSummands (nativeACCanonical left) ++
        nativeACSummands (nativeACCanonical right)).mergeSort nativeACOrder)
  | .unary symbol argument => .unary symbol (nativeACCanonical argument)
  | .binary symbol left right => .binary symbol (nativeACCanonical left) (nativeACCanonical right)
  | .kdf first second third =>
    .kdf (nativeACCanonical first) (nativeACCanonical second) (nativeACCanonical third)
  | .list argument => .list (nativeACCanonical argument)
  | .cons first rest => .cons (nativeACCanonical first) (nativeACCanonical rest)
  | term@(.atom _ _) | term@(.naturalAtom _) | term@(.nodeAtom _) |
      term@(.queryVariable _ _) | term@(.naturalOne) | term@(.roleA) | term@(.roleB) |
      term@(.nil) => term

def nativeACEqual (left right : NativeQueryTerm) : Bool :=
  nativeACCanonical left == nativeACCanonical right

private theorem order_transitive (first second third : NativeQueryTerm) :
    nativeACOrder first second = true → nativeACOrder second third = true →
      nativeACOrder first third = true := by
  simp only [nativeACOrder, decide_eq_true_eq]
  exact List.le_trans

private theorem order_total (first second : NativeQueryTerm) :
    (nativeACOrder first second || nativeACOrder second first) = true := by
  simp only [nativeACOrder, Bool.or_eq_true, decide_eq_true_eq]
  exact List.le_total _ _

private theorem order_antisymmetric (forward : nativeACOrder first second = true)
    (backward : nativeACOrder second first = true) : first = second := by
  simp only [nativeACOrder, decide_eq_true_eq] at forward backward
  exact native_maude_term_injective
    (by rw [nativeMaudeTerm, nativeMaudeTerm, List.le_antisymm forward backward])

private theorem sorted_eq {first second : List NativeQueryTerm} (permutation : first.Perm second) :
    first.mergeSort nativeACOrder = second.mergeSort nativeACOrder :=
  List.Perm.eq_of_pairwise (le := fun left right => nativeACOrder left right = true)
    (fun _ _ _ _ forward backward => order_antisymmetric forward backward)
    (List.pairwise_mergeSort order_transitive order_total _)
    (List.pairwise_mergeSort order_transitive order_total _)
    (((List.mergeSort_perm _ _).trans permutation).trans (List.mergeSort_perm _ _).symm)

private theorem sorted_nonempty {terms : List NativeQueryTerm} (nonempty : terms ≠ []) :
    terms.mergeSort nativeACOrder ≠ [] := by
  intro empty
  have permutation := List.mergeSort_perm terms nativeACOrder
  rw [empty] at permutation
  exact nonempty permutation.symm.eq_nil

private theorem summands_nonempty (term : NativeQueryTerm) : nativeACSummands term ≠ [] := by
  induction term with
  | naturalAdd _ _ first _ =>
    intro empty
    exact first (List.append_eq_nil_iff.mp empty).1
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil => simp [nativeACSummands]

private theorem summands_fixed (notAddition : nativeQueryHead term ≠ .naturalAdd) :
    nativeACSummands term = [term] := by
  cases term <;> simp_all [nativeQueryHead, nativeACSummands]

private theorem summand_head {term summand : NativeQueryTerm}
    (member : summand ∈ nativeACSummands term) : nativeQueryHead summand ≠ .naturalAdd := by
  induction term with
  | naturalAdd _ _ first second =>
    rcases List.mem_append.mp member with inside | inside
    · exact first inside
    · exact second inside
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil =>
    simp only [nativeACSummands, List.mem_singleton] at member
    subst member
    simp [nativeQueryHead]

private theorem atom_word_summands (term : NativeQueryTerm) :
    nativeACAtomWord term = (nativeACSummands term).flatMap nativeACAtomWord := by
  induction term with
  | naturalAdd _ _ first second =>
    simp only [nativeACAtomWord, nativeACSummands, List.flatMap_append, first, second]
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil => simp [nativeACSummands]

private theorem rebuild_atom_word : ∀ (terms : List NativeQueryTerm), terms ≠ [] →
    nativeACAtomWord (nativeACRebuild terms) = terms.flatMap nativeACAtomWord
  | [], empty => absurd rfl empty
  | [_], _ => by simp [nativeACRebuild]
  | first :: second :: rest, _ => by
    simp only [nativeACRebuild, nativeACAtomWord]
    rw [rebuild_atom_word (second :: rest) (by simp)]
    simp only [List.flatMap_cons]

private theorem rebuild_summands : ∀ (terms : List NativeQueryTerm), terms ≠ [] →
    (∀ term ∈ terms, nativeQueryHead term ≠ .naturalAdd) →
      nativeACSummands (nativeACRebuild terms) = terms
  | [], empty, _ => absurd rfl empty
  | [term], _, heads => by
    simp only [nativeACRebuild]
    exact summands_fixed (heads term (by simp))
  | first :: second :: rest, _, heads => by
    simp only [nativeACRebuild, nativeACSummands]
    rw [summands_fixed (heads first (by simp)),
      rebuild_summands (second :: rest) (by simp) (fun term member => heads term (by simp [member]))]
    rfl

private theorem canonical_add (left right : NativeQueryTerm) :
    nativeACCanonical (.naturalAdd left right) = nativeACRebuild
      ((nativeACSummands (nativeACCanonical left) ++
        nativeACSummands (nativeACCanonical right)).mergeSort nativeACOrder) := by
  simp only [nativeACCanonical]

private theorem canonical_add_nonempty (left right : NativeQueryTerm) :
    (nativeACSummands (nativeACCanonical left) ++
      nativeACSummands (nativeACCanonical right)).mergeSort nativeACOrder ≠ [] :=
  sorted_nonempty fun empty => summands_nonempty _ (List.append_eq_nil_iff.mp empty).1

private theorem canonical_add_summands (left right : NativeQueryTerm) :
    nativeACSummands (nativeACCanonical (.naturalAdd left right)) =
      (nativeACSummands (nativeACCanonical left) ++
        nativeACSummands (nativeACCanonical right)).mergeSort nativeACOrder := by
  rw [canonical_add]
  refine rebuild_summands _ (canonical_add_nonempty left right) fun term member => ?_
  rcases List.mem_append.mp ((List.mergeSort_perm _ _).subset member) with inside | inside
  · exact summand_head inside
  · exact summand_head inside

theorem native_ac_canonical_related (term : NativeQueryTerm) :
    NativeQueryAC term (nativeACCanonical term) := by
  induction term with
  | naturalAdd left right first second =>
    refine native_ac_atom_word_iff.mpr ?_
    rw [canonical_add, rebuild_atom_word _ (canonical_add_nonempty left right)]
    refine ((native_ac_atom_word_preservation first).append
      (native_ac_atom_word_preservation second)).trans ?_
    rw [atom_word_summands (nativeACCanonical left), atom_word_summands (nativeACCanonical right),
      ← List.flatMap_append]
    exact ((List.mergeSort_perm _ _).flatMap_right _).symm
  | unary _ _ related => exact .unary related
  | binary _ _ _ first second => exact .binary first second
  | kdf _ _ _ first second third => exact .kdf first second third
  | list _ related => exact .list related
  | cons _ _ first second => exact .cons first second
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB | nil =>
    exact .reflexive

theorem native_ac_canonical_iff :
    NativeQueryAC left right ↔ nativeACCanonical left = nativeACCanonical right := by
  constructor
  · intro equivalent
    induction equivalent with
    | reflexive => rfl
    | symmetric _ same => exact same.symm
    | transitive _ _ first second => exact first.trans second
    | @associative first second third =>
      rw [canonical_add (.naturalAdd first second) third, canonical_add first (.naturalAdd second third),
        canonical_add_summands, canonical_add_summands]
      refine congrArg nativeACRebuild (sorted_eq ?_)
      refine ((List.mergeSort_perm _ _).append (.refl _)).trans ?_
      rw [List.append_assoc]
      exact (List.Perm.refl _).append (List.mergeSort_perm _ _).symm
    | commutative =>
      rw [canonical_add, canonical_add]
      exact congrArg nativeACRebuild (sorted_eq List.perm_append_comm)
    | naturalAdd _ _ first second => rw [canonical_add, canonical_add, first, second]
    | unary _ same => simp only [nativeACCanonical, same]
    | binary _ _ first second => simp only [nativeACCanonical, first, second]
    | kdf _ _ _ first second third => simp only [nativeACCanonical, first, second, third]
    | list _ same => simp only [nativeACCanonical, same]
    | cons _ _ first second => simp only [nativeACCanonical, first, second]
  · intro same
    refine .transitive (native_ac_canonical_related left) ?_
    rw [same]
    exact .symmetric (native_ac_canonical_related right)

theorem native_ac_equal_iff :
    nativeACEqual left right = true ↔ NativeQueryAC left right := by
  rw [nativeACEqual, beq_iff_eq, native_ac_canonical_iff]

#print axioms native_ac_canonical_related
#print axioms native_ac_canonical_iff
#print axioms native_ac_equal_iff

end Cairn.Equations
