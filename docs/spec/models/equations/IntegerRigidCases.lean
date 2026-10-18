import IntegerFamilyCompleteness
import IntegerFamilySoundness
import IntegerRigidFamily
import IntegerRigidCompleteness
import IntegerRigidSoundness

namespace Cairn.Equations

example :
    (integerRigidWordFamily [0, 1] [fun index => if index = 0 then 1 else -1]
      [(1, 0)]).length = 1 := by decide

example :
    integerRigidWordFamily [0, 1] [fun index => if index = 0 then 2 else -1] [(1, 0)] =
      [] := by decide

example :
    integerRigidWordFamily [0, 1] [fun index => if index = 0 then 1 else 0] [(1, 0)] =
      [] := by decide

example :
    (integerRigidWordFamily [0, 1, 2]
      [fun index => if index = 1 then -1 else 1] [(2, 0)]).length = 2 := by decide

example :
    integerRigidWordFamily [0, 1] [fun index => if index = 0 then 1 else -1]
      [(1, 0), (1, 2)] = [] := by decide

example : (integerRigidWordFamily ([] : List Nat) [] ([] : List (Nat × Nat))).length = 1 := by
  decide

example [DecidableEq α] [DecidableEq β] (alphabet : List α) (rows : List (α → Int))
    (rigid : List (α × β)) (values : α → List β) (unique : alphabet.Nodup) (defaultAtom : β)
    (nonempty : ∀ letter ∈ alphabet, values letter ≠ [])
    (rigidScope : ∀ binding ∈ rigid, binding.1 ∈ alphabet)
    (fixed : ∀ binding ∈ rigid, values binding.1 = [binding.2])
    (balanced : ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet values atom) = 0) :
    ∃ candidate ∈ integerRigidWordFamily alphabet rows rigid,
      ∃ factor : Sum β (List α) → List β,
        (∀ name, factor name ≠ []) ∧ (∀ atom, factor (Sum.inl atom) = [atom]) ∧
          ∀ letter ∈ alphabet, (values letter).Perm ((candidate letter).flatMap factor) :=
  integer_rigid_word_family_complete alphabet rows rigid values unique defaultAtom nonempty
    rigidScope fixed balanced

example [DecidableEq α] [DecidableEq β] (alphabet : List α) (rows : List (α → Int))
    (rigid : List (α × β)) (unique : alphabet.Nodup)
    (member : candidate ∈ integerRigidWordFamily alphabet rows rigid) :
    ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet candidate atom) = 0 :=
  integer_rigid_word_family_sound alphabet rows rigid unique member

example [DecidableEq α] [DecidableEq β] (alphabet : List α) (rows : List (α → Int))
    (rigid : List (α × β)) (member : candidate ∈ integerRigidWordFamily alphabet rows rigid) :
    ∀ binding ∈ rigid, candidate binding.1 = [Sum.inl binding.2] :=
  integer_rigid_word_family_constants alphabet rows rigid member

example [DecidableEq α] [DecidableEq β] (alphabet : List α) (rows : List (α → Int))
    (rigid : List (α × β)) (member : candidate ∈ integerRigidWordFamily alphabet rows rigid) :
    ∀ letter ∈ alphabet, candidate letter ≠ [] :=
  integer_rigid_word_family_nonempty alphabet rows rigid member

end Cairn.Equations
