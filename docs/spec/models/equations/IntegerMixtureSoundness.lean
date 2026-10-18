import IntegerWordMixture

namespace Cairn.Equations

theorem integer_word_mixture_transpose [DecidableEq α] [BEq β] [LawfulBEq β]
    (alphabet : List α) (basis : List (List α)) (values : List α → List β)
    (unique : alphabet.Nodup)
    (scope : ∀ generator ∈ basis, ∀ letter ∈ generator, letter ∈ alphabet) (atom : β) :
    (integerWordTranspose alphabet (integerWordMixture basis values) atom).Perm
      (integerWordExpansion basis (fun generator => (values generator).count atom)).flatten := by
  have expandedScope :
      ∀ letter ∈
        (integerWordExpansion basis (fun generator => (values generator).count atom)).flatten,
        letter ∈ alphabet := by
    intro letter member
    obtain ⟨generator, generated, occurs⟩ := List.mem_flatten.mp member
    exact scope generator (integer_word_expansion_scope _ _ generated) letter occurs
  apply List.perm_iff_count.mpr
  intro letter
  change (integerWordExpansion alphabet
    (fun entry => (integerWordMixture basis values entry).count atom)).count letter = _
  rw [integer_word_expansion_count, integer_word_nodup_count alphabet unique]
  by_cases member : letter ∈ alphabet
  · simpa [member] using integer_word_mixture_count basis values letter atom
  · have absent : letter ∉
        (integerWordExpansion basis (fun generator => (values generator).count atom)).flatten :=
      fun occurs => member (expandedScope letter occurs)
    simp [member, List.count_eq_zero.mpr absent]

private theorem zero_word_sum (weights : α → Int) (word : List α)
    (zero : ∀ letter ∈ word, weights letter = 0) : integerWordSum weights word = 0 := by
  induction word with
  | nil => rfl
  | cons first rest induction =>
    simp only [integerWordSum, zero first (by simp),
      induction (fun letter member => zero letter (List.mem_cons_of_mem _ member)), Int.zero_add]

theorem integer_word_mixture_balanced [DecidableEq α] [BEq β] [LawfulBEq β]
    (alphabet : List α) (basis : List (List α)) (values : List α → List β)
    (unique : alphabet.Nodup)
    (scope : ∀ generator ∈ basis, ∀ letter ∈ generator, letter ∈ alphabet)
    (row : α → Int) (balanced : ∀ generator ∈ basis, integerWordSum row generator = 0)
    (atom : β) :
    integerWordSum row (integerWordTranspose alphabet (integerWordMixture basis values) atom) =
      0 := by
  rw [integer_word_sum_permutation row
    (integer_word_mixture_transpose alphabet basis values unique scope atom),
    integer_word_sum_flatten]
  apply zero_word_sum
  intro generator member
  exact balanced generator (integer_word_expansion_scope _ _ member)

#print axioms integer_word_mixture_transpose
#print axioms integer_word_mixture_balanced

end Cairn.Equations
