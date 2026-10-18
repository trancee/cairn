import IntegerWords

namespace Cairn.Equations

private theorem repeated_prefix_cycle (weights : α → Int) (word : List α) (start : Int)
    (repeated : ¬ (integerWordPrefixes weights start word).Nodup) :
    ∃ before cycle after, word = before ++ cycle ++ after ∧ cycle ≠ [] ∧
      integerWordSum weights cycle = 0 := by
  classical
  induction word generalizing start with
  | nil => simp [integerWordPrefixes] at repeated
  | cons letter rest induction =>
    by_cases member : start ∈ integerWordPrefixes weights (start + weights letter) rest
    · obtain ⟨before, after, split, total⟩ := integer_word_prefix_member weights member
      refine ⟨[], letter :: before, after, by simp [split], by simp, ?_⟩
      simp only [integerWordSum]
      omega
    · have tailRepeated : ¬ (integerWordPrefixes weights (start + weights letter) rest).Nodup := by
        intro tailDistinct
        exact repeated (List.nodup_cons.mpr ⟨member, tailDistinct⟩)
      obtain ⟨before, cycle, after, split, nonempty, balanced⟩ := induction _ tailRepeated
      exact ⟨letter :: before, cycle, after, by simp [split], nonempty, balanced⟩

private theorem prefix_nodup_length (weights : α → Int) (word : List α) (bound : Nat)
    (distinct : (integerWordPrefixes weights 0 word).Nodup)
    (bounded : ∀ state ∈ integerWordPrefixes weights 0 word,
      -(bound : Int) ≤ state ∧ state ≤ bound) :
    word.length + 1 ≤ 2 * bound + 1 := by
  let interval := (List.range (2 * bound + 1)).map (fun (index : Nat) => (index : Int) - bound)
  have subset : ∀ state ∈ integerWordPrefixes weights 0 word, state ∈ interval := by
    intro state member
    have limits := bounded state member
    apply List.mem_map.mpr
    refine ⟨(state + (bound : Int)).toNat, List.mem_range.mpr (by omega), ?_⟩
    omega
  have lengthBound := distinct.length_le_of_subset subset
  simpa [interval, integer_word_prefix_length] using lengthBound

theorem integer_word_bounded_zero_sum (weights : α → Int) (word : List α) (bound : Nat)
    (nonempty : word ≠ []) (balanced : integerWordSum weights word = 0)
    (bounded : ∀ letter ∈ word, -(bound : Int) ≤ weights letter ∧ weights letter ≤ bound) :
    ∃ small rest, word.Perm (small ++ rest) ∧ small ≠ [] ∧
      integerWordSum weights small = 0 ∧ small.length ≤ 2 * bound + 1 := by
  by_cases short : word.length ≤ 2 * bound + 1
  · exact ⟨word, [], by simp, nonempty, balanced, short⟩
  · obtain ⟨ordered, permutation, limits⟩ :=
      integer_word_bounded_order weights word bound 0 (by omega) (by omega) bounded
    let initial := ordered.take (2 * bound + 1)
    have prefixLength : initial.length = 2 * bound + 1 := by
      have sameLength := permutation.length_eq
      simp only [initial, List.length_take]
      omega
    have prefixLimits : ∀ state ∈ integerWordPrefixes weights 0 initial,
        -(bound : Int) ≤ state ∧ state ≤ bound := by
      intro state member
      apply limits state
      have whole := integer_word_prefix_append_member weights
        (ordered.drop (2 * bound + 1)) member
      simpa only [initial, List.take_append_drop] using whole
    have repeated : ¬ (integerWordPrefixes weights 0 initial).Nodup := by
      intro distinct
      have lengthBound := prefix_nodup_length weights initial bound distinct prefixLimits
      omega
    obtain ⟨before, cycle, after, split, cycleNonempty, cycleBalanced⟩ :=
      repeated_prefix_cycle weights initial 0 repeated
    have cycleLength : cycle.length ≤ 2 * bound + 1 := by
      rw [split] at prefixLength
      simp only [List.length_append] at prefixLength
      omega
    refine ⟨cycle, before ++ after ++ ordered.drop (2 * bound + 1), ?_,
      cycleNonempty, cycleBalanced, cycleLength⟩
    apply permutation.symm.trans
    have orderedSplit : ordered = before ++ cycle ++ after ++ ordered.drop (2 * bound + 1) := by
      have initialSplit : ordered.take (2 * bound + 1) = before ++ cycle ++ after := split
      simpa only [initialSplit, List.append_assoc] using
        (List.take_append_drop (2 * bound + 1) ordered).symm
    conv => lhs; rw [orderedSplit]
    simpa only [List.append_assoc] using
      (List.perm_append_comm (l₁ := before) (l₂ := cycle)).append_right
        (after ++ ordered.drop (2 * bound + 1))

#print axioms integer_word_bounded_zero_sum

end Cairn.Equations
