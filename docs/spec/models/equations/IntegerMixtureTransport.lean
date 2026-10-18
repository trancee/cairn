import IntegerMixtureAlgebra

namespace Cairn.Equations

private theorem bind_repeated_word (word : List β) (times : Nat) (factor : β → List γ) :
    (List.replicate times word).flatten.flatMap factor =
      (List.replicate times (word.flatMap factor)).flatten := by
  induction times with
  | zero => rfl
  | succ times induction =>
    simp [List.replicate_succ, List.flatten_cons, List.flatMap_append, induction]

theorem integer_word_mixture_bind [BEq α] (basis : List (List α)) (values : List α → List β)
    (factor : β → List γ) (letter : α) :
    (integerWordMixture basis values letter).flatMap factor =
      integerWordMixture basis (fun generator => (values generator).flatMap factor) letter := by
  induction basis with
  | nil => rfl
  | cons first rest induction =>
    simp [integer_word_mixture_cons, List.flatMap_append, bind_repeated_word, induction]

theorem integer_word_mixture_map [BEq α] (basis : List (List α)) (values : List α → List β)
    (mapping : β → γ) (letter : α) :
    (integerWordMixture basis values letter).map mapping =
      integerWordMixture basis (fun generator => (values generator).map mapping) letter := by
  simpa only [List.map_eq_flatMap] using
    integer_word_mixture_bind basis values (fun atom => [mapping atom]) letter

theorem integer_word_mixture_relevant_congr [BEq α] [LawfulBEq α]
    (basis : List (List α)) (first second : List α → List β) (letter : α)
    (agree : ∀ generator ∈ basis, letter ∈ generator → first generator = second generator) :
    integerWordMixture basis first letter = integerWordMixture basis second letter := by
  induction basis with
  | nil => rfl
  | cons generator rest induction =>
    have remaining := induction (fun entry member => agree entry (List.mem_cons_of_mem _ member))
    rw [integer_word_mixture_cons, integer_word_mixture_cons, remaining]
    by_cases occurs : letter ∈ generator
    · rw [agree generator (by simp) occurs]
    · simp [List.count_eq_zero.mpr occurs]

#print axioms integer_word_mixture_bind
#print axioms integer_word_mixture_map
#print axioms integer_word_mixture_relevant_congr

end Cairn.Equations
