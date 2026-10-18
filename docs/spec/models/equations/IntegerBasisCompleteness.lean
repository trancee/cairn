import IntegerWordPruning

namespace Cairn.Equations

theorem integer_primitive_basis_complete [DecidableEq α] (alphabet : List α)
    (rows : List (α → Int)) (basis : List (List α))
    (sound : ∀ part ∈ basis, part ≠ [] ∧ (∀ letter ∈ part, letter ∈ alphabet) ∧
      ∀ row ∈ rows, integerWordSum row part = 0)
    (complete : ∀ word : List α, (∀ letter ∈ word, letter ∈ alphabet) →
      (∀ row ∈ rows, integerWordSum row word = 0) →
      ∃ parts : List (List α), word.Perm parts.flatten ∧ ∀ part ∈ parts, part ∈ basis)
    (word : List α) (scope : ∀ letter ∈ word, letter ∈ alphabet)
    (balanced : ∀ row ∈ rows, integerWordSum row word = 0) :
    ∃ parts : List (List α), word.Perm parts.flatten ∧
      ∀ part ∈ parts, part ∈ integerPrimitiveWordBasis basis := by
  by_cases empty : word = []
  · subst word
    exact ⟨[], .refl _, by simp⟩
  · obtain ⟨original, permutation, members⟩ := complete word scope balanced
    cases original with
    | nil => exact (empty permutation.eq_nil).elim
    | cons first tail =>
      obtain ⟨primitive, primitiveMember, rest, firstPermutation⟩ :=
        integer_primitive_subword basis first (members first (by simp))
      have primitiveValid := sound primitive (integer_primitive_basis_member basis primitiveMember)
      have extracted : word.Perm (primitive ++ (rest ++ tail.flatten)) := by
        simpa only [List.flatten_cons, List.append_assoc] using
          permutation.trans (firstPermutation.append_right tail.flatten)
      have remainingScope : ∀ letter ∈ rest ++ tail.flatten, letter ∈ alphabet := by
        intro letter member
        exact scope letter (extracted.mem_iff.mpr (List.mem_append_right _ member))
      have remainingBalanced : ∀ row ∈ rows,
          integerWordSum row (rest ++ tail.flatten) = 0 := by
        intro row member
        have total := integer_word_sum_permutation row extracted
        rw [integer_word_sum_append, primitiveValid.2.2 row member] at total
        have zero := balanced row member
        omega
      obtain ⟨parts, remaining, partMembers⟩ := integer_primitive_basis_complete
        alphabet rows basis sound complete (rest ++ tail.flatten) remainingScope remainingBalanced
      refine ⟨primitive :: parts,
        extracted.trans ((List.Perm.refl primitive).append remaining), ?_⟩
      intro part member
      rcases List.mem_cons.mp member with rfl | member
      · exact primitiveMember
      · exact partMembers part member
termination_by word.length
decreasing_by
  have lengths := extracted.length_eq
  have positive := List.length_pos_iff.mpr primitiveValid.1
  simp only [List.length_append] at lengths
  simp only [List.length_append]
  omega

#print axioms integer_primitive_basis_complete

end Cairn.Equations
