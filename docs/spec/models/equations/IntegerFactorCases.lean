import IntegerMatrixFactors

namespace Cairn.Equations

example [DecidableEq α] (alphabet word : List α) (unique : alphabet.Nodup)
    (scope : ∀ letter ∈ word, letter ∈ alphabet) :
    word.Perm (alphabet.flatMap (fun letter => List.replicate (word.count letter) letter)) :=
  integer_word_expansion_permutation alphabet word unique scope

example [DecidableEq α] [DecidableEq β] (alphabet : List α) (rows : List (α → Int))
    (values : α → List β) (unique : alphabet.Nodup)
    (balanced : ∀ atom row, row ∈ rows →
      integerWordSum row
        (alphabet.flatMap (fun letter => List.replicate ((values letter).count atom) letter)) = 0) :
    ∃ factors : List α → List β, ∀ letter ∈ alphabet,
      (values letter).Perm
        (((integerMatrixWordBasis alphabet rows).eraseDups.flatMap (fun generator =>
          List.replicate (generator.count letter) (factors generator))).flatten) :=
  integer_matrix_word_factorization alphabet rows values unique balanced

end Cairn.Equations
