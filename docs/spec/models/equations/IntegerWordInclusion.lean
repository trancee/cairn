import IntegerWordBasis

namespace Cairn.Equations

def integerWordContains [DecidableEq α] (small large : List α) : Bool :=
  small.all (fun letter => decide (small.count letter ≤ large.count letter))

theorem integer_word_contains_iff [DecidableEq α] (small large : List α) :
    integerWordContains small large = true ↔
      ∃ rest, large.Perm (small ++ rest) := by
  constructor
  · intro included
    induction small generalizing large with
    | nil => exact ⟨large, .refl _⟩
    | cons first tail induction =>
      have counts : ∀ letter ∈ first :: tail,
          (first :: tail).count letter ≤ large.count letter := by
        simpa only [integerWordContains, List.all_eq_true, decide_eq_true_eq] using included
      have firstCount := counts first (by simp)
      have member : first ∈ large := by
        apply List.one_le_count_iff.mp
        simp only [List.count_cons_self] at firstCount
        omega
      have tailIncluded : integerWordContains tail (large.erase first) = true := by
        simp only [integerWordContains, List.all_eq_true, decide_eq_true_eq]
        intro letter member
        have count := counts letter (List.mem_cons_of_mem _ member)
        by_cases same : letter = first
        · subst letter
          simp only [List.count_cons_self] at count
          rw [List.count_erase_self]
          omega
        · rw [List.count_cons_of_ne (Ne.symm same)] at count
          rw [List.count_erase_of_ne same]
          exact count
      obtain ⟨rest, remaining⟩ := induction (large.erase first) tailIncluded
      exact ⟨rest, (List.perm_cons_erase member).trans (remaining.cons first)⟩
  · rintro ⟨rest, permutation⟩
    simp only [integerWordContains, List.all_eq_true, decide_eq_true_eq]
    intro letter _
    have count := permutation.count_eq letter
    rw [List.count_append] at count
    omega

#print axioms integer_word_contains_iff

end Cairn.Equations
