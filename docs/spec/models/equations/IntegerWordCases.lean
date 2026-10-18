import IntegerMatrixBasis

namespace Cairn.Equations

example (weights : α → Int) (word : List α) (bound : Nat)
    (nonempty : word ≠ []) (balanced : integerWordSum weights word = 0)
    (bounded : ∀ letter ∈ word, -(bound : Int) ≤ weights letter ∧ weights letter ≤ bound) :
    ∃ small rest, word.Perm (small ++ rest) ∧ small ≠ [] ∧
      integerWordSum weights small = 0 ∧ small.length ≤ 2 * bound + 1 :=
  integer_word_bounded_zero_sum weights word bound nonempty balanced bounded

example [DecidableEq α] (alphabet : List α) (rows : List (α → Int)) (word : List α)
    (scope : ∀ letter ∈ word, letter ∈ alphabet)
    (balanced : ∀ row ∈ rows, integerWordSum row word = 0) :
    ∃ parts : List (List α), word.Perm parts.flatten ∧
      ∀ part ∈ parts, part ∈ integerMatrixWordBasis alphabet rows :=
  integer_matrix_word_basis_complete alphabet rows word scope balanced

example : integerMatrixWordBasis ([] : List Nat) [fun _ => 0] = [] := rfl

example : (integerMatrixWordBasis [0, 1] []).length = 2 := rfl

example : (integerMatrixWordBasis [0, 1] [fun _ => 0]).length = 2 := by decide

example : integerMatrixWordBasis [0, 1] [fun _ => 1] = [] := by decide

example :
    let basis := integerMatrixWordBasis [0, 1] [fun index => if index = 0 then 2 else -3]
    basis.length = 1 ∧ ∀ word ∈ basis, word.count 0 = 3 ∧ word.count 1 = 2 := by decide

example :
    let basis := integerMatrixWordBasis [0, 1, 2]
      [fun index => if index = 0 then 1 else if index = 1 then -1 else 0,
       fun index => if index = 1 then 1 else if index = 2 then -1 else 0]
    basis.length = 1 ∧ ∀ word ∈ basis,
      word.count 0 = 1 ∧ word.count 1 = 1 ∧ word.count 2 = 1 := by decide

example [DecidableEq α] (alphabet : List α) (rows : List (α → Int))
    (member : word ∈ integerMatrixWordBasis alphabet rows) :
    word ≠ [] ∧ (∀ letter ∈ word, letter ∈ alphabet) ∧
      ∀ row ∈ rows, integerWordSum row word = 0 :=
  integer_matrix_word_basis_sound alphabet rows member

end Cairn.Equations
