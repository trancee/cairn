import IntegerZeroSum

namespace Cairn.Equations

def integerAlphabetBound (weights : α → Int) : List α → Nat
  | [] => 0
  | letter :: rest => max (weights letter).natAbs (integerAlphabetBound weights rest)

theorem integer_alphabet_bound (weights : α → Int) (alphabet : List α)
    (member : letter ∈ alphabet) :
    -(integerAlphabetBound weights alphabet : Int) ≤ weights letter ∧
      weights letter ≤ integerAlphabetBound weights alphabet := by
  induction alphabet with
  | nil => simp at member
  | cons first rest induction =>
    rcases List.mem_cons.mp member with rfl | member
    · have own : -((weights letter).natAbs : Int) ≤ weights letter ∧
          weights letter ≤ ((weights letter).natAbs : Int) := by
        cases weights letter <;> simp [Int.natAbs] <;> omega
      have larger := Nat.le_max_left (weights letter).natAbs (integerAlphabetBound weights rest)
      simp only [integerAlphabetBound]
      omega
    · have limits := induction member
      have larger := Nat.le_max_right (weights first).natAbs (integerAlphabetBound weights rest)
      simp only [integerAlphabetBound]
      omega

def integerBoundedWords (alphabet : List α) : Nat → List (List α)
  | 0 => [[]]
  | budget + 1 =>
    [] :: alphabet.flatMap (fun letter =>
      (integerBoundedWords alphabet budget).map (List.cons letter))

theorem integer_bounded_words_iff (alphabet : List α) (budget : Nat) (word : List α) :
    word ∈ integerBoundedWords alphabet budget ↔
      word.length ≤ budget ∧ ∀ letter ∈ word, letter ∈ alphabet := by
  induction budget generalizing word with
  | zero => cases word <;> simp [integerBoundedWords]
  | succ budget induction =>
    cases word with
    | nil => simp [integerBoundedWords]
    | cons letter rest =>
      constructor
      · intro member
        rcases List.mem_cons.mp member with impossible | member
        · cases impossible
        · obtain ⟨first, firstMember, member⟩ := List.mem_flatMap.mp member
          obtain ⟨remaining, remainingMember, equal⟩ := List.mem_map.mp member
          obtain ⟨rfl, rfl⟩ := List.cons.inj equal
          have smaller := (induction _).mp remainingMember
          refine ⟨by simp only [List.length_cons]; omega, ?_⟩
          intro entry member
          rcases List.mem_cons.mp member with rfl | member
          · exact firstMember
          · exact smaller.2 entry member
      · rintro ⟨lengthBound, scope⟩
        apply List.mem_cons_of_mem
        apply List.mem_flatMap.mpr
        refine ⟨letter, scope letter (by simp), List.mem_map.mpr ⟨rest, ?_, rfl⟩⟩
        apply (induction rest).mpr
        refine ⟨by simp only [List.length_cons] at lengthBound; omega, ?_⟩
        exact fun entry member => scope entry (List.mem_cons_of_mem _ member)

def integerRowWordBasis (weights : α → Int) (alphabet : List α) : List (List α) :=
  (integerBoundedWords alphabet (2 * integerAlphabetBound weights alphabet + 1)).filter
    (fun word => decide (0 < word.length ∧ integerWordSum weights word = 0))

theorem integer_row_word_basis_sound (weights : α → Int) (alphabet : List α)
    (member : word ∈ integerRowWordBasis weights alphabet) :
    word ≠ [] ∧ (∀ letter ∈ word, letter ∈ alphabet) ∧ integerWordSum weights word = 0 := by
  have accepted := List.mem_filter.mp member
  have valid : 0 < word.length ∧ integerWordSum weights word = 0 := by
    simpa using accepted.2
  exact ⟨by intro equal; simp [equal] at valid,
    ((integer_bounded_words_iff alphabet _ word).mp accepted.1).2, valid.2⟩

theorem integer_row_word_basis_complete (weights : α → Int) (alphabet : List α)
    (word : List α) (scope : ∀ letter ∈ word, letter ∈ alphabet)
    (balanced : integerWordSum weights word = 0) :
    ∃ parts : List (List α), word.Perm parts.flatten ∧
      ∀ part ∈ parts, part ∈ integerRowWordBasis weights alphabet := by
  by_cases empty : word = []
  · subst word
    exact ⟨[], .refl [], by simp⟩
  · have bounded := fun letter member => integer_alphabet_bound weights alphabet (scope letter member)
    obtain ⟨small, rest, permutation, nonempty, zero, short⟩ :=
      integer_word_bounded_zero_sum weights word (integerAlphabetBound weights alphabet)
        empty balanced bounded
    have smallScope : ∀ letter ∈ small, letter ∈ alphabet := by
      intro letter member
      exact scope letter (permutation.mem_iff.mpr (List.mem_append_left _ member))
    have restScope : ∀ letter ∈ rest, letter ∈ alphabet := by
      intro letter member
      exact scope letter (permutation.mem_iff.mpr (List.mem_append_right _ member))
    have restZero : integerWordSum weights rest = 0 := by
      have total := integer_word_sum_permutation weights permutation
      rw [integer_word_sum_append, zero] at total
      omega
    have smallMember : small ∈ integerRowWordBasis weights alphabet := by
      apply List.mem_filter.mpr
      refine ⟨(integer_bounded_words_iff alphabet _ small).mpr ⟨short, smallScope⟩, ?_⟩
      have positive : 0 < small.length := List.length_pos_iff.mpr nonempty
      simpa using And.intro positive zero
    obtain ⟨parts, remaining, members⟩ :=
      integer_row_word_basis_complete weights alphabet rest restScope restZero
    refine ⟨small :: parts, ?_, ?_⟩
    · exact permutation.trans ((List.Perm.refl small).append remaining)
    · intro part member
      rcases List.mem_cons.mp member with rfl | member
      · exact smallMember
      · exact members part member
termination_by word.length
decreasing_by
  have lengths := permutation.length_eq
  have positive : 0 < small.length := List.length_pos_iff.mpr nonempty
  simp only [List.length_append] at lengths
  omega

#print axioms integer_alphabet_bound
#print axioms integer_bounded_words_iff
#print axioms integer_row_word_basis_sound
#print axioms integer_row_word_basis_complete

end Cairn.Equations
