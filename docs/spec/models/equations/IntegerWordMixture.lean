import IntegerWordExpansion

namespace Cairn.Equations

def integerWordTranspose [BEq β] (alphabet : List α) (values : α → List β)
    (atom : β) : List α :=
  integerWordExpansion alphabet (fun letter => (values letter).count atom)

def integerWordMixture [BEq α] (basis : List (List α))
    (values : List α → List β) (letter : α) : List β :=
  (basis.flatMap (fun generator =>
    List.replicate (generator.count letter) (values generator))).flatten

private theorem count_repeated_word [BEq α] [LawfulBEq α]
    (word : List α) (times : Nat) (letter : α) :
    (List.replicate times word).flatten.count letter = times * word.count letter := by
  induction times with
  | zero => simp
  | succ times induction =>
    simp [List.replicate_succ, List.flatten_cons, List.count_append, induction,
      Nat.succ_mul, Nat.add_comm]

theorem integer_word_mixture_count [BEq α] [LawfulBEq α] [BEq β] [LawfulBEq β]
    (basis : List (List α)) (values : List α → List β) (letter : α) (atom : β) :
    (integerWordMixture basis values letter).count atom =
      (integerWordExpansion basis (fun generator => (values generator).count atom)).flatten.count
        letter := by
  induction basis with
  | nil => simp [integerWordMixture, integerWordExpansion]
  | cons generator rest induction =>
    simp only [integerWordMixture, integerWordExpansion] at induction
    simp only [integerWordMixture, integerWordExpansion, List.flatMap_cons,
      List.flatten_append, List.count_append, count_repeated_word]
    rw [induction, Nat.mul_comm (generator.count letter)]

#print axioms integer_word_mixture_count

end Cairn.Equations
