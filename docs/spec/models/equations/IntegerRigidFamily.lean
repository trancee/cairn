import IntegerWordFamily

namespace Cairn.Equations

def integerWordRigidChoices (constants : List β) (generator : List α) :
    List (List (Sum β (List α))) :=
  [] :: [Sum.inr generator] :: constants.map (fun atom => [Sum.inl atom])

def integerWordRigidAssignments [DecidableEq α] (constants : List β) :
    List (List α) → List (List α → List (Sum β (List α)))
  | [] => [fun _ => []]
  | generator :: rest =>
    (integerWordRigidAssignments constants rest).flatMap (fun previous =>
      (integerWordRigidChoices constants generator).map
        (fun chosen name => if name = generator then chosen else previous name))

def integerRigidWordFamily [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β)) :
    List (α → List (Sum β (List α))) :=
  let basis := (integerMatrixWordBasis alphabet rows).eraseDups
  ((integerWordRigidAssignments (rigid.map Prod.snd) basis).map
    (fun choice letter => integerWordMixture basis choice letter)).filter (fun candidate =>
      alphabet.all (fun letter => !(candidate letter).isEmpty) &&
        rigid.all (fun binding => decide (candidate binding.1 = [Sum.inl binding.2])))

theorem integer_rigid_word_family_nonempty [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β))
    (member : candidate ∈ integerRigidWordFamily alphabet rows rigid) :
    ∀ letter ∈ alphabet, candidate letter ≠ [] := by
  have allowed := List.all_eq_true.mp (Bool.and_eq_true_iff.mp (List.mem_filter.mp member).2).1
  intro letter occurs empty
  have check := allowed letter occurs
  simp [empty] at check

theorem integer_rigid_word_family_constants [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β))
    (member : candidate ∈ integerRigidWordFamily alphabet rows rigid) :
    ∀ binding ∈ rigid, candidate binding.1 = [Sum.inl binding.2] := by
  have allowed := List.all_eq_true.mp (Bool.and_eq_true_iff.mp (List.mem_filter.mp member).2).2
  intro binding occurs
  exact of_decide_eq_true (allowed binding occurs)

#print axioms integer_rigid_word_family_nonempty
#print axioms integer_rigid_word_family_constants

end Cairn.Equations
