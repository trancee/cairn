import NaturalMultiplicity

namespace Cairn.Equations

def integerWordSum (weights : α → Int) : List α → Int
  | [] => 0
  | letter :: rest => weights letter + integerWordSum weights rest

theorem integer_word_sum_append (weights : α → Int) (left right : List α) :
    integerWordSum weights (left ++ right) =
      integerWordSum weights left + integerWordSum weights right := by
  induction left with
  | nil => simp [integerWordSum]
  | cons _ _ induction => simp [integerWordSum, induction, Int.add_assoc]

theorem integer_word_sum_permutation (weights : α → Int) (permutation : left.Perm right) :
    integerWordSum weights left = integerWordSum weights right := by
  induction permutation with
  | nil => rfl
  | cons _ _ induction => simp only [integerWordSum]; omega
  | swap => simp only [integerWordSum]; omega
  | trans _ _ first second => exact first.trans second

private theorem sum_nonnegative (weights : α → Int) (word : List α)
    (nonnegative : ∀ letter ∈ word, 0 ≤ weights letter) :
    0 ≤ integerWordSum weights word := by
  induction word with
  | nil => exact Int.le_refl 0
  | cons letter rest induction =>
    have first := nonnegative letter (by simp)
    have remaining := induction (fun entry member =>
      nonnegative entry (List.mem_cons_of_mem _ member))
    simp only [integerWordSum]
    omega

private theorem sum_nonpositive (weights : α → Int) (word : List α)
    (nonpositive : ∀ letter ∈ word, weights letter ≤ 0) :
    integerWordSum weights word ≤ 0 := by
  induction word with
  | nil => exact Int.le_refl 0
  | cons letter rest induction =>
    have first := nonpositive letter (by simp)
    have remaining := induction (fun entry member =>
      nonpositive entry (List.mem_cons_of_mem _ member))
    simp only [integerWordSum]
    omega

def integerWordPrefixes (weights : α → Int) (start : Int) : List α → List Int
  | [] => [start]
  | letter :: rest => start :: integerWordPrefixes weights (start + weights letter) rest

theorem integer_word_prefix_length (weights : α → Int) (start : Int) (word : List α) :
    (integerWordPrefixes weights start word).length = word.length + 1 := by
  induction word generalizing start <;> simp_all [integerWordPrefixes]

theorem integer_word_prefix_member (weights : α → Int)
    (member : state ∈ integerWordPrefixes weights start word) :
    ∃ before after, word = before ++ after ∧ state = start + integerWordSum weights before := by
  induction word generalizing start with
  | nil =>
    have equal : state = start := List.mem_singleton.mp member
    exact ⟨[], [], rfl, by simpa [integerWordSum] using equal⟩
  | cons letter rest induction =>
    rcases List.mem_cons.mp member with equal | member
    · exact ⟨[], letter :: rest, rfl, by simpa [integerWordSum] using equal⟩
    · obtain ⟨before, after, split, total⟩ := induction member
      refine ⟨letter :: before, after, by simp [split], ?_⟩
      simp only [integerWordSum]
      omega

theorem integer_word_prefix_append_member (weights : α → Int) (right : List α)
    (member : state ∈ integerWordPrefixes weights start left) :
    state ∈ integerWordPrefixes weights start (left ++ right) := by
  induction left generalizing start with
  | nil =>
    have equal := List.mem_singleton.mp member
    subst state
    cases right <;> exact List.mem_cons_self
  | cons letter rest induction =>
    rcases List.mem_cons.mp member with rfl | member
    · exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ (induction member)

theorem integer_word_bounded_order (weights : α → Int) (word : List α) (bound : Nat)
    (start : Int) (startBound : -(bound : Int) ≤ start ∧ start ≤ bound)
    (balanced : start + integerWordSum weights word = 0)
    (bounded : ∀ letter ∈ word, -(bound : Int) ≤ weights letter ∧ weights letter ≤ bound) :
    ∃ ordered, ordered.Perm word ∧
      ∀ state ∈ integerWordPrefixes weights start ordered,
        -(bound : Int) ≤ state ∧ state ≤ bound := by
  classical
  cases source : word with
  | nil =>
    refine ⟨[], .nil, ?_⟩
    intro state member
    simpa only [List.mem_singleton.mp member] using startBound
  | cons head tail =>
    rw [source] at balanced bounded
    have selected : ∃ letter ∈ head :: tail,
        -(bound : Int) ≤ start + weights letter ∧ start + weights letter ≤ bound := by
      by_cases positive : 0 < start
      · have negative : ∃ letter ∈ head :: tail, weights letter < 0 := by
          apply Classical.byContradiction
          intro impossible
          have allNonnegative : ∀ letter ∈ head :: tail, 0 ≤ weights letter := by
            intro letter member
            apply Classical.byContradiction
            intro notNonnegative
            exact impossible ⟨letter, member, by omega⟩
          have total := sum_nonnegative weights (head :: tail) allNonnegative
          omega
        obtain ⟨letter, member, negative⟩ := negative
        have limits := bounded letter member
        exact ⟨letter, member, by omega⟩
      · by_cases negative : start < 0
        · have positive : ∃ letter ∈ head :: tail, 0 < weights letter := by
            apply Classical.byContradiction
            intro impossible
            have allNonpositive : ∀ letter ∈ head :: tail, weights letter ≤ 0 := by
              intro letter member
              apply Classical.byContradiction
              intro notNonpositive
              exact impossible ⟨letter, member, by omega⟩
            have total := sum_nonpositive weights (head :: tail) allNonpositive
            omega
          obtain ⟨letter, member, positive⟩ := positive
          have limits := bounded letter member
          exact ⟨letter, member, by omega⟩
        · have limits := bounded head (by simp)
          exact ⟨head, by simp, by omega⟩
    obtain ⟨letter, member, nextBound⟩ := selected
    obtain ⟨before, after, split⟩ := List.mem_iff_append.mp member
    have reordered : (head :: tail).Perm (letter :: (before ++ after)) := by
      rw [split]
      exact List.perm_middle
    have nextBalanced : start + weights letter + integerWordSum weights (before ++ after) = 0 := by
      have total := integer_word_sum_permutation weights reordered
      simp only [integerWordSum] at total balanced
      omega
    have nextLimits : ∀ entry ∈ before ++ after,
        -(bound : Int) ≤ weights entry ∧ weights entry ≤ bound := by
      intro entry member
      exact bounded entry (reordered.mem_iff.mpr (List.mem_cons_of_mem _ member))
    obtain ⟨ordered, permutation, limits⟩ :=
      integer_word_bounded_order weights (before ++ after) bound (start + weights letter)
        nextBound nextBalanced nextLimits
    refine ⟨letter :: ordered, (permutation.cons letter).trans reordered.symm, ?_⟩
    intro state member
    rcases List.mem_cons.mp member with rfl | member
    · exact startBound
    · exact limits state member
termination_by word.length
decreasing_by
  have lengths := reordered.length_eq
  simp only [List.length_cons] at lengths
  rw [source]
  simp only [List.length_cons]
  omega

#print axioms integer_word_sum_append
#print axioms integer_word_sum_permutation
#print axioms integer_word_bounded_order

end Cairn.Equations
