import IntegerWordMixture

namespace Cairn.Equations

theorem integer_word_mixture_cons [BEq α] (generator : List α) (rest : List (List α))
    (values : List α → List β) (letter : α) :
    integerWordMixture (generator :: rest) values letter =
      (List.replicate (generator.count letter) (values generator)).flatten ++
        integerWordMixture rest values letter := by
  simp [integerWordMixture, List.flatMap_cons, List.flatten_append]

theorem integer_word_mixture_congr [BEq α] (basis : List (List α))
    (first second : List α → List β) (letter : α)
    (agree : ∀ generator ∈ basis, first generator = second generator) :
    integerWordMixture basis first letter = integerWordMixture basis second letter := by
  induction basis with
  | nil => rfl
  | cons generator rest induction =>
    rw [integer_word_mixture_cons, integer_word_mixture_cons,
      agree generator (by simp), induction (fun entry member =>
        agree entry (List.mem_cons_of_mem _ member))]

theorem integer_word_mixture_filter_nonempty [BEq α] (basis : List (List α))
    (values : List α → List β) (letter : α) :
    integerWordMixture basis values letter =
      integerWordMixture (basis.filter (fun generator => !(values generator).isEmpty)) values
        letter := by
  induction basis with
  | nil => rfl
  | cons generator rest induction =>
    cases contents : values generator with
    | nil => simp [contents, integer_word_mixture_cons, induction]
    | cons first tail => simp [contents, integer_word_mixture_cons, induction]

theorem integer_word_mixture_bind_singletons [BEq α] (basis : List (List α))
    (factor : List α → List β) (letter : α) :
    (integerWordMixture basis (fun generator => [generator]) letter).flatMap factor =
      integerWordMixture basis factor letter := by
  induction basis with
  | nil => rfl
  | cons generator rest induction =>
    simp [integer_word_mixture_cons, List.flatMap_append, List.flatMap_replicate, induction]

#print axioms integer_word_mixture_cons
#print axioms integer_word_mixture_congr
#print axioms integer_word_mixture_filter_nonempty
#print axioms integer_word_mixture_bind_singletons

end Cairn.Equations
