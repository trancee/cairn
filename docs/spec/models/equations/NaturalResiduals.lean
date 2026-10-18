import IntegerRigidCompleteness

namespace Cairn.Equations

def naturalFreshBase : List Nat → Nat
  | [] => 0
  | index :: rest => max (index + 1) (naturalFreshBase rest)

def naturalResidualIndex [BEq α] (forbidden : List Nat) (basis : List α) (generator : α) : Nat :=
  naturalFreshBase forbidden + basis.idxOf generator

theorem natural_fresh_base_bound (forbidden : List Nat) (member : index ∈ forbidden) :
    index < naturalFreshBase forbidden := by
  induction forbidden with
  | nil => simp at member
  | cons first rest induction =>
    rcases List.mem_cons.mp member with rfl | occurs
    · have bound := Nat.le_max_left (index + 1) (naturalFreshBase rest)
      simp only [naturalFreshBase]
      omega
    · have bound := Nat.le_max_right (first + 1) (naturalFreshBase rest)
      have previous := induction occurs
      simp only [naturalFreshBase]
      omega

theorem natural_residual_index_fresh [BEq α] (forbidden : List Nat) (basis : List α)
    (generator : α) (member : original ∈ forbidden) :
    naturalResidualIndex forbidden basis generator ≠ original := by
  have bound := natural_fresh_base_bound forbidden member
  unfold naturalResidualIndex
  omega

theorem natural_residual_index_range [BEq α] [LawfulBEq α] (forbidden : List Nat)
    (basis : List α) (member : generator ∈ basis) :
    naturalFreshBase forbidden ≤ naturalResidualIndex forbidden basis generator ∧
      naturalResidualIndex forbidden basis generator < naturalFreshBase forbidden + basis.length := by
  have bound := List.idxOf_lt_length_of_mem member
  unfold naturalResidualIndex
  omega

theorem natural_residual_index_injective [BEq α] [LawfulBEq α] (forbidden : List Nat)
    (basis : List α) (firstMember : first ∈ basis) (secondMember : second ∈ basis)
    (same : naturalResidualIndex forbidden basis first = naturalResidualIndex forbidden basis second) :
    first = second := by
  have indices : basis.idxOf first = basis.idxOf second := by
    unfold naturalResidualIndex at same
    omega
  have firstRead := List.getElem_idxOf (List.idxOf_lt_length_of_mem firstMember)
  have secondRead := List.getElem_idxOf (List.idxOf_lt_length_of_mem secondMember)
  simp only [indices] at firstRead
  exact firstRead.symm.trans secondRead

#print axioms natural_fresh_base_bound
#print axioms natural_residual_index_fresh
#print axioms natural_residual_index_range
#print axioms natural_residual_index_injective

end Cairn.Equations
