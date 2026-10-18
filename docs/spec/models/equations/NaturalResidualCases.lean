import NaturalResiduals

namespace Cairn.Equations

example : naturalResidualIndex [0, 8] [11, 22] 22 = 10 := by decide

example [BEq α] (forbidden : List Nat) (basis : List α) (generator : α)
    (member : original ∈ forbidden) : naturalResidualIndex forbidden basis generator ≠ original :=
  natural_residual_index_fresh forbidden basis generator member

example [BEq α] [LawfulBEq α] (forbidden : List Nat) (basis : List α)
    (firstMember : first ∈ basis) (secondMember : second ∈ basis)
    (same : naturalResidualIndex forbidden basis first = naturalResidualIndex forbidden basis second) :
    first = second :=
  natural_residual_index_injective forbidden basis firstMember secondMember same

example [BEq α] [LawfulBEq α] (forbidden : List Nat) (basis : List α) (member : generator ∈ basis) :
    naturalFreshBase forbidden ≤ naturalResidualIndex forbidden basis generator ∧
      naturalResidualIndex forbidden basis generator < naturalFreshBase forbidden + basis.length :=
  natural_residual_index_range forbidden basis member

example : naturalResidualIndex [] ([4, 4, 7] : List Nat) 4 = 0 := by decide

example : naturalResidualIndex [0] ([4, 4, 7] : List Nat) 7 = 3 := by decide

end Cairn.Equations
