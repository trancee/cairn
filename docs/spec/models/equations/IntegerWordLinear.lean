import IntegerWordMixture

namespace Cairn.Equations

theorem integer_word_sum_add (first second : α → Int) (word : List α) :
    integerWordSum (fun letter => first letter + second letter) word =
      integerWordSum first word + integerWordSum second word := by
  induction word with
  | nil => rfl
  | cons letter rest induction =>
    simp only [integerWordSum, induction]
    omega

theorem integer_word_sum_subtract (first second : α → Int) (word : List α) :
    integerWordSum (fun letter => first letter - second letter) word =
      integerWordSum first word - integerWordSum second word := by
  induction word with
  | nil => rfl
  | cons letter rest induction =>
    simp only [integerWordSum, induction]
    omega

theorem integer_word_sum_congr (word : List α) (first second : α → Int)
    (agree : ∀ letter ∈ word, first letter = second letter) :
    integerWordSum first word = integerWordSum second word := by
  induction word with
  | nil => rfl
  | cons letter rest induction =>
    rw [integerWordSum, integerWordSum, agree letter (by simp),
      induction (fun entry member => agree entry (List.mem_cons_of_mem _ member))]

theorem integer_word_sum_indicator [BEq α] [LawfulBEq α] (word : List α) (target : α) :
    integerWordSum (fun letter => if letter == target then 1 else 0) word =
      (word.count target : Int) := by
  induction word with
  | nil => rfl
  | cons letter rest induction =>
    by_cases same : letter = target
    · subst letter
      simp [integerWordSum, induction, Int.add_comm]
    · simp [integerWordSum, same, List.count_cons_of_ne same, induction]

theorem integer_word_count_pairing [BEq α] [LawfulBEq α] (source target : List α) :
    integerWordSum (fun letter => (source.count letter : Int)) target =
      integerWordSum (fun letter => (target.count letter : Int)) source := by
  induction source with
  | nil =>
    change integerWordSum (fun _ => 0) target = 0
    induction target <;> simp_all [integerWordSum]
  | cons first rest induction =>
    have counts (letter : α) :
        ((first :: rest).count letter : Int) =
          (if letter == first then 1 else 0) + (rest.count letter : Int) := by
      by_cases same : letter = first
      · subst letter
        simp [Int.add_comm]
      · rw [List.count_cons_of_ne (Ne.symm same)]
        simp [same]
    rw [show (fun letter => ((first :: rest).count letter : Int)) =
        (fun letter => (if letter == first then 1 else 0) + (rest.count letter : Int))
        from funext counts,
      integer_word_sum_add, integer_word_sum_indicator, induction]
    rfl

theorem integer_word_flatmap_count [BEq β] (word : List α) (values : α → List β) (atom : β) :
    integerWordSum (fun letter => ((values letter).count atom : Int)) word =
      ((word.flatMap values).count atom : Int) := by
  induction word <;>
    simp_all [integerWordSum, List.flatMap_cons, List.count_append]

theorem integer_word_equation_counts [BEq α] [LawfulBEq α] [BEq β]
    (alphabet left right : List α) (values : α → List β) (unique : alphabet.Nodup)
    (leftScope : ∀ letter ∈ left, letter ∈ alphabet)
    (rightScope : ∀ letter ∈ right, letter ∈ alphabet) (atom : β) :
    integerWordSum (fun letter => (left.count letter : Int) - (right.count letter : Int))
      (integerWordTranspose alphabet values atom) =
        ((left.flatMap values).count atom : Int) - ((right.flatMap values).count atom : Int) := by
  rw [integer_word_sum_subtract, integer_word_count_pairing left,
    integer_word_count_pairing right]
  have counts (letter : α) (member : letter ∈ alphabet) :
      ((integerWordTranspose alphabet values atom).count letter : Int) =
        ((values letter).count atom : Int) := by
    change ((integerWordExpansion alphabet (fun entry => (values entry).count atom)).count letter :
      Int) = _
    rw [integer_word_expansion_count, integer_word_nodup_count alphabet unique]
    simp [member]
  rw [integer_word_sum_congr left _ _ (fun letter member => counts letter (leftScope letter member)),
    integer_word_sum_congr right _ _ (fun letter member => counts letter (rightScope letter member)),
    integer_word_flatmap_count, integer_word_flatmap_count]

#print axioms integer_word_sum_add
#print axioms integer_word_sum_subtract
#print axioms integer_word_sum_congr
#print axioms integer_word_sum_indicator
#print axioms integer_word_count_pairing
#print axioms integer_word_flatmap_count
#print axioms integer_word_equation_counts

end Cairn.Equations
