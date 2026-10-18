import IntegerWordFamily
import IntegerMixtureSoundness

namespace Cairn.Equations

theorem integer_matrix_word_family_sound [DecidableEq α] (alphabet : List α)
    (rows : List (α → Int)) (unique : alphabet.Nodup)
    (member : candidate ∈ integerMatrixWordFamily alphabet rows) :
    ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet candidate atom) = 0 := by
  obtain ⟨selected, selectedMember, rfl⟩ := List.mem_map.mp (List.mem_filter.mp member).1
  have valid (generator : List α) (occurs : generator ∈ selected) :
      generator ≠ [] ∧ (∀ letter ∈ generator, letter ∈ alphabet) ∧
        ∀ row ∈ rows, integerWordSum row generator = 0 :=
    integer_matrix_word_basis_sound alphabet rows (List.mem_eraseDups.mp
      (integer_word_selection_scope _ selected selectedMember generator occurs))
  intro atom row checked
  exact integer_word_mixture_balanced alphabet selected (fun generator => [generator]) unique
    (fun generator occurs => (valid generator occurs).2.1) row
    (fun generator occurs => (valid generator occurs).2.2 row checked) atom

#print axioms integer_matrix_word_family_sound

end Cairn.Equations
