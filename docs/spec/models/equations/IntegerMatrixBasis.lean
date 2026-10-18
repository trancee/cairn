import IntegerBasisExtension
import IntegerBasisCompleteness

namespace Cairn.Equations

private theorem flatten_singletons (word : List α) :
    (word.map (fun letter => [letter])).flatten = word := by
  induction word <;> simp_all

def integerMatrixWordBasis [DecidableEq α] (alphabet : List α) :
    List (α → Int) → List (List α)
  | [] => alphabet.map (fun letter => [letter])
  | row :: rows =>
    let remaining := integerMatrixWordBasis alphabet rows
    integerPrimitiveWordBasis (integerBasisExtension row remaining)

theorem integer_matrix_word_basis_sound [DecidableEq α] (alphabet : List α) (rows : List (α → Int))
    (member : word ∈ integerMatrixWordBasis alphabet rows) :
    word ≠ [] ∧ (∀ letter ∈ word, letter ∈ alphabet) ∧
      ∀ row ∈ rows, integerWordSum row word = 0 := by
  induction rows generalizing word with
  | nil =>
    obtain ⟨letter, letterMember, rfl⟩ := List.mem_map.mp member
    refine ⟨by simp, ?_, by simp⟩
    intro entry member
    simpa only [List.mem_singleton.mp member] using letterMember
  | cons row rows induction =>
    exact integer_basis_extension_sound alphabet rows row (integerMatrixWordBasis alphabet rows)
      (fun _ member => induction member)
      (integer_primitive_basis_member _ member)

theorem integer_matrix_word_basis_complete [DecidableEq α] (alphabet : List α) (rows : List (α → Int))
    (word : List α) (scope : ∀ letter ∈ word, letter ∈ alphabet)
    (balanced : ∀ row ∈ rows, integerWordSum row word = 0) :
    ∃ parts : List (List α), word.Perm parts.flatten ∧
      ∀ part ∈ parts, part ∈ integerMatrixWordBasis alphabet rows := by
  induction rows generalizing word with
  | nil =>
    refine ⟨word.map (fun letter => [letter]), ?_, ?_⟩
    · rw [flatten_singletons]
    · intro part member
      obtain ⟨letter, letterMember, rfl⟩ := List.mem_map.mp member
      exact List.mem_map.mpr ⟨letter, scope letter letterMember, rfl⟩
  | cons row rows induction =>
    apply integer_primitive_basis_complete alphabet (row :: rows)
      (integerBasisExtension row (integerMatrixWordBasis alphabet rows))
      (fun _ member => integer_basis_extension_sound alphabet rows row _ (fun _ member =>
        integer_matrix_word_basis_sound alphabet rows member) member)
      (integer_basis_extension_complete alphabet rows row _ (fun word scope balanced =>
        induction word scope balanced)) word scope balanced

#print axioms integer_matrix_word_basis_sound
#print axioms integer_matrix_word_basis_complete

end Cairn.Equations
