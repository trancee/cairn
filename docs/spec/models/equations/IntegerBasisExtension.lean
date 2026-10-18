import IntegerWordBasis

namespace Cairn.Equations

theorem integer_word_sum_flatten (weights : α → Int) (parts : List (List α)) :
    integerWordSum weights parts.flatten =
      integerWordSum (fun part => integerWordSum weights part) parts := by
  induction parts with
  | nil => rfl
  | cons _ _ induction =>
    simp only [List.flatten_cons, integer_word_sum_append, integerWordSum, induction]

private theorem sum_zero (weights : α → Int) (word : List α)
    (zero : ∀ letter ∈ word, weights letter = 0) : integerWordSum weights word = 0 := by
  induction word with
  | nil => rfl
  | cons first rest induction =>
    have firstZero := zero first (by simp)
    have restZero := induction (fun entry member => zero entry (List.mem_cons_of_mem _ member))
    simp [integerWordSum, firstZero, restZero]

private theorem flatten_map_flatten (groups : List (List (List α))) :
    (groups.map List.flatten).flatten = groups.flatten.flatten := by
  induction groups <;> simp_all [List.flatten_append]

def integerBasisExtension (row : α → Int) (basis : List (List α)) : List (List α) :=
  (integerRowWordBasis (fun word => integerWordSum row word) basis).map List.flatten

theorem integer_basis_extension_sound (alphabet : List α) (rows : List (α → Int))
    (row : α → Int) (basis : List (List α))
    (known : ∀ part ∈ basis, part ≠ [] ∧ (∀ letter ∈ part, letter ∈ alphabet) ∧
      ∀ checked ∈ rows, integerWordSum checked part = 0)
    (member : word ∈ integerBasisExtension row basis) :
    word ≠ [] ∧ (∀ letter ∈ word, letter ∈ alphabet) ∧
      ∀ checked ∈ row :: rows, integerWordSum checked word = 0 := by
  obtain ⟨parts, partsMember, rfl⟩ := List.mem_map.mp member
  have valid := integer_row_word_basis_sound (fun part => integerWordSum row part) basis partsMember
  have partValid := fun part member => known part (valid.2.1 part member)
  refine ⟨?_, ?_, ?_⟩
  · intro empty
    cases parts with
    | nil => exact valid.1 rfl
    | cons first rest =>
      have firstValid := partValid first (by simp)
      change first ++ rest.flatten = [] at empty
      cases first with
      | nil => exact firstValid.1 rfl
      | cons => cases empty
  · intro letter member
    obtain ⟨part, partMember, letterMember⟩ := List.mem_flatten.mp member
    exact (partValid part partMember).2.1 letter letterMember
  · intro checked member
    rcases List.mem_cons.mp member with rfl | member
    · rw [integer_word_sum_flatten]
      exact valid.2.2
    · rw [integer_word_sum_flatten]
      apply sum_zero
      intro part partMember
      exact (partValid part partMember).2.2 checked member

theorem integer_basis_extension_complete (alphabet : List α) (rows : List (α → Int))
    (row : α → Int) (basis : List (List α))
    (known : ∀ word : List α, (∀ letter ∈ word, letter ∈ alphabet) →
      (∀ checked ∈ rows, integerWordSum checked word = 0) →
      ∃ parts : List (List α), word.Perm parts.flatten ∧ ∀ part ∈ parts, part ∈ basis)
    (word : List α) (scope : ∀ letter ∈ word, letter ∈ alphabet)
    (balanced : ∀ checked ∈ row :: rows, integerWordSum checked word = 0) :
    ∃ parts : List (List α), word.Perm parts.flatten ∧
      ∀ part ∈ parts, part ∈ integerBasisExtension row basis := by
  obtain ⟨parts, permutation, members⟩ :=
    known word scope (fun checked member => balanced checked (List.mem_cons_of_mem _ member))
  have total : integerWordSum (fun part => integerWordSum row part) parts = 0 := by
    rw [← integer_word_sum_flatten, ← integer_word_sum_permutation row permutation]
    exact balanced row (by simp)
  obtain ⟨groups, grouped, groupMembers⟩ := integer_row_word_basis_complete
    (fun part => integerWordSum row part) basis parts members total
  refine ⟨groups.map List.flatten, ?_, ?_⟩
  · rw [flatten_map_flatten]
    exact permutation.trans grouped.flatten
  · intro part member
    obtain ⟨group, groupMember, rfl⟩ := List.mem_map.mp member
    exact List.mem_map.mpr ⟨group, groupMembers group groupMember, rfl⟩

#print axioms integer_word_sum_flatten
#print axioms integer_basis_extension_sound
#print axioms integer_basis_extension_complete

end Cairn.Equations
