import IntegerWordMixture

namespace Cairn.Equations

theorem integer_matrix_word_factorization [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (values : α → List β)
    (unique : alphabet.Nodup)
    (balanced : ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet values atom) = 0) :
    ∃ factors : List α → List β, ∀ letter ∈ alphabet,
      (values letter).Perm
        (integerWordMixture (integerMatrixWordBasis alphabet rows).eraseDups factors letter) := by
  classical
  let basis := (integerMatrixWordBasis alphabet rows).eraseDups
  let atoms := (alphabet.flatMap values).eraseDups
  have basisUnique : basis.Nodup := integer_word_erase_duplicates_unique _
  have atomUnique : atoms.Nodup := integer_word_erase_duplicates_unique _
  have decomposable (atom : β) :
      ∃ parts : List (List α), (integerWordTranspose alphabet values atom).Perm parts.flatten ∧
        ∀ generator ∈ parts, generator ∈ basis := by
    obtain ⟨parts, permutation, members⟩ := integer_matrix_word_basis_complete alphabet rows
      (integerWordTranspose alphabet values atom)
      (fun _ member => integer_word_expansion_scope _ _ member) (balanced atom)
    exact ⟨parts, permutation, fun generator member => List.mem_eraseDups.mpr
      (members generator member)⟩
  let parts (atom : β) := Classical.choose (decomposable atom)
  have decomposed (atom : β) := Classical.choose_spec (decomposable atom)
  let factors (generator : List α) := integerWordTranspose atoms parts generator
  refine ⟨factors, ?_⟩
  intro letter scopeMember
  rw [List.perm_iff_count]
  intro atom
  rw [integer_word_mixture_count]
  have factorCounts (generator : List α) :
      (factors generator).count atom =
        if atom ∈ atoms then (parts atom).count generator else 0 := by
    change (integerWordExpansion atoms (fun entry => (parts entry).count generator)).count atom = _
    rw [integer_word_expansion_count, integer_word_nodup_count atoms atomUnique]
    split <;> simp_all
  by_cases present : atom ∈ atoms
  · have counts (generator : List α) :
        (factors generator).count atom = (parts atom).count generator := by
      rw [factorCounts]
      simp [present]
    simp only [counts]
    have grouped := integer_word_expansion_permutation basis (parts atom) basisUnique
      (decomposed atom).2
    have combined := (decomposed atom).1.trans grouped.flatten
    have count := combined.count_eq letter
    change (integerWordExpansion alphabet (fun entry => (values entry).count atom)).count letter =
      _ at count
    rw [integer_word_expansion_count, integer_word_nodup_count alphabet unique] at count
    simpa [scopeMember] using count
  · have absent : atom ∉ values letter := by
      intro occurs
      exact present (List.mem_eraseDups.mpr (List.mem_flatMap.mpr ⟨letter, scopeMember, occurs⟩))
    have counts (generator : List α) : (factors generator).count atom = 0 := by
      rw [factorCounts]
      simp [present]
    simp only [counts]
    rw [integer_word_expansion_zero, List.count_eq_zero.mpr absent]
    rfl

#print axioms integer_matrix_word_factorization

end Cairn.Equations
