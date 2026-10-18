import IntegerFamilyCompleteness
import IntegerFamilySoundness

namespace Cairn.Equations

example :
    (integerMatrixWordFamily [0, 1] [fun index => if index = 0 then 2 else -3]).length = 1 := by
  decide

example :
    let family := integerMatrixWordFamily [0, 1] [fun index => if index = 0 then 2 else -3]
    ∀ candidate ∈ family, (candidate 0).length = 3 ∧ (candidate 1).length = 2 := by decide

example :
    (integerMatrixWordFamily [0, 1, 2, 3]
      [fun index => if index < 2 then 1 else -1]).length = 7 := by decide

example : (integerMatrixWordFamily [0, 1] []).length = 1 := by decide

example : (integerMatrixWordFamily ([] : List Nat) [fun _ => 1]).length = 1 := by decide

example :
    integerMatrixWordFamily [0, 1] [fun index => if index = 0 then 0 else 1] = [] := by decide

example [DecidableEq α] [DecidableEq β] (alphabet : List α) (rows : List (α → Int))
    (values : α → List β) (unique : alphabet.Nodup) (defaultAtom : β)
    (nonempty : ∀ letter ∈ alphabet, values letter ≠ [])
    (balanced : ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet values atom) = 0) :
    ∃ candidate ∈ integerMatrixWordFamily alphabet rows, ∃ factor : List α → List β,
      (∀ generator, factor generator ≠ []) ∧
        ∀ letter ∈ alphabet, (values letter).Perm ((candidate letter).flatMap factor) :=
  integer_matrix_word_family_complete alphabet rows values unique defaultAtom nonempty balanced

example [DecidableEq α] (alphabet : List α) (rows : List (α → Int)) (unique : alphabet.Nodup)
    (member : candidate ∈ integerMatrixWordFamily alphabet rows) :
    ∀ generator row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet candidate generator) = 0 :=
  integer_matrix_word_family_sound alphabet rows unique member

example [DecidableEq α] (alphabet : List α) (rows : List (α → Int))
    (member : candidate ∈ integerMatrixWordFamily alphabet rows) :
    ∀ letter ∈ alphabet, candidate letter ≠ [] :=
  integer_matrix_word_family_nonempty alphabet rows member

end Cairn.Equations
