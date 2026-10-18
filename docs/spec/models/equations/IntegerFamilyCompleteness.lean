import IntegerWordFamily
import IntegerMixtureAlgebra

namespace Cairn.Equations

theorem integer_matrix_word_family_complete [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (values : α → List β)
    (unique : alphabet.Nodup) (defaultAtom : β)
    (nonempty : ∀ letter ∈ alphabet, values letter ≠ [])
    (balanced : ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet values atom) = 0) :
    ∃ candidate ∈ integerMatrixWordFamily alphabet rows, ∃ factor : List α → List β,
      (∀ generator, factor generator ≠ []) ∧
        ∀ letter ∈ alphabet, (values letter).Perm ((candidate letter).flatMap factor) := by
  obtain ⟨factors, reconstruct⟩ :=
    integer_matrix_word_factorization alphabet rows values unique balanced
  let basis := (integerMatrixWordBasis alphabet rows).eraseDups
  let active := basis.filter (fun generator => !(factors generator).isEmpty)
  let factor (generator : List α) :=
    if (factors generator).isEmpty then [defaultAtom] else factors generator
  let candidate (letter : α) := integerWordMixture active (fun generator => [generator]) letter
  have agree (generator : List α) (member : generator ∈ active) :
      factor generator = factors generator := by
    have allowed := (List.mem_filter.mp member).2
    cases contents : factors generator with
    | nil => simp [contents] at allowed
    | cons first tail => simp [factor, contents]
  have factored (letter : α) (member : letter ∈ alphabet) :
      (values letter).Perm (integerWordMixture active factor letter) := by
    have original := reconstruct letter member
    rw [integer_word_mixture_filter_nonempty] at original
    have unchanged := integer_word_mixture_congr active factor factors letter agree
    rw [← unchanged] at original
    exact original
  have instantiate (letter : α) :
      (candidate letter).flatMap factor = integerWordMixture active factor letter :=
    integer_word_mixture_bind_singletons active factor letter
  have candidateNonempty (letter : α) (member : letter ∈ alphabet) : candidate letter ≠ [] := by
    intro empty
    have original := factored letter member
    rw [← instantiate letter, empty] at original
    exact nonempty letter member original.eq_nil
  have included : candidate ∈ integerMatrixWordFamily alphabet rows := by
    apply List.mem_filter.mpr
    constructor
    · exact List.mem_map.mpr ⟨active, integer_word_selection_filter basis _, rfl⟩
    · apply List.all_eq_true.mpr
      intro letter member
      cases contents : candidate letter with
      | nil => exact (candidateNonempty letter member contents).elim
      | cons first rest => simp
  refine ⟨candidate, included, factor, ?_, ?_⟩
  · intro generator
    cases contents : factors generator with
    | nil => simp [factor, contents]
    | cons first rest => simp [factor, contents]
  · intro letter member
    rw [instantiate]
    exact factored letter member

#print axioms integer_matrix_word_family_complete

end Cairn.Equations
