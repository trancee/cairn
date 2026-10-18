import IntegerMatrixBasis

namespace Cairn.Equations

def integerWordExpansion (alphabet : List α) (multiplicities : α → Nat) : List α :=
  alphabet.flatMap (fun letter => List.replicate (multiplicities letter) letter)

theorem integer_word_erase_duplicates_unique [BEq α] [LawfulBEq α] (alphabet : List α) :
    alphabet.eraseDups.Nodup := by
  cases alphabet with
  | nil => simp
  | cons first tail =>
    rw [List.eraseDups_cons, List.nodup_cons]
    constructor
    · simp
    · exact integer_word_erase_duplicates_unique (tail.filter (fun entry => !entry == first))
termination_by alphabet.length
decreasing_by
  have shorter := List.length_filter_le (fun entry => !entry == first) tail
  simp only [List.length_cons]
  omega

theorem integer_word_expansion_scope (alphabet : List α) (multiplicities : α → Nat)
    (member : letter ∈ integerWordExpansion alphabet multiplicities) :
    letter ∈ alphabet := by
  obtain ⟨entry, scopeMember, repeated⟩ := List.mem_flatMap.mp member
  obtain ⟨_, rfl⟩ := List.mem_replicate.mp repeated
  exact scopeMember

theorem integer_word_nodup_count [BEq α] [LawfulBEq α] (alphabet : List α)
    (unique : alphabet.Nodup) (letter : α) :
    alphabet.count letter = if letter ∈ alphabet then 1 else 0 := by
  induction alphabet with
  | nil => simp
  | cons first tail induction =>
    obtain ⟨absent, remaining⟩ := List.nodup_cons.mp unique
    by_cases same : letter = first
    · subst letter
      rw [List.count_cons_self, List.count_eq_zero.mpr absent]
      simp
    · rw [List.count_cons_of_ne (Ne.symm same), induction remaining]
      simp [same]

theorem integer_word_expansion_count [BEq α] [LawfulBEq α] (alphabet : List α)
    (multiplicities : α → Nat) (letter : α) :
    (integerWordExpansion alphabet multiplicities).count letter =
      alphabet.count letter * multiplicities letter := by
  induction alphabet with
  | nil => simp [integerWordExpansion]
  | cons first tail induction =>
    change (List.replicate (multiplicities first) first ++
      integerWordExpansion tail multiplicities).count letter = _
    rw [List.count_append, induction, List.count_replicate]
    by_cases same : letter = first
    · subst letter
      simp [List.count_cons_self, Nat.add_mul, Nat.add_comm]
    · rw [List.count_cons_of_ne (Ne.symm same)]
      simp [Ne.symm same]

theorem integer_word_expansion_zero (alphabet : List α) :
    integerWordExpansion alphabet (fun _ => 0) = [] := by
  induction alphabet <;> simp_all [integerWordExpansion]

theorem integer_word_expansion_permutation [BEq α] [LawfulBEq α] (alphabet word : List α)
    (unique : alphabet.Nodup) (scope : ∀ letter ∈ word, letter ∈ alphabet) :
    word.Perm (integerWordExpansion alphabet (fun letter => word.count letter)) := by
  rw [List.perm_iff_count]
  intro letter
  rw [integer_word_expansion_count, integer_word_nodup_count alphabet unique]
  by_cases member : letter ∈ alphabet
  · simp [member]
  · have absent : letter ∉ word := fun occurs => member (scope letter occurs)
    simp [member, List.count_eq_zero.mpr absent]

#print axioms integer_word_erase_duplicates_unique
#print axioms integer_word_expansion_scope
#print axioms integer_word_nodup_count
#print axioms integer_word_expansion_count
#print axioms integer_word_expansion_zero
#print axioms integer_word_expansion_permutation

end Cairn.Equations
