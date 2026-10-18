import NaturalLinearization

namespace Cairn.Equations

example (assignment : QuerySubstitution) (left right : NaturalTerm) :
    NaturalAC (substituteQueryNatural assignment left) (substituteQueryNatural assignment right) ↔
      ∀ atom, naturalLinearCount assignment atom left = naturalLinearCount assignment atom right :=
  natural_linear_unifier_iff assignment left right

example : naturalVariableOccurrences (.add (.variable 0) (.variable 0)) = [0, 0] := rfl

example : naturalVariableOccurrences (.add (.variable 0) (.add (.variable 1) .one)) = [0] := rfl

example : naturalVariableOccurrences (.variable 2) = [1] := rfl

example : naturalRigidMultiplicity 1 (.variable 0) = 0 := rfl

example : naturalRigidMultiplicity 2 (.variable 1) = 1 := rfl

example : naturalRigidMultiplicity 0 .one = 1 := rfl

example (assignment : QuerySubstitution) (atom : Nat) :
    naturalLinearCount assignment atom (.add (.variable 0) (.variable 0)) =
      2 * naturalMultiplicity atom (assignment.naturals 0) := by
  simp [naturalLinearCount, naturalVariableOccurrences, naturalRigidMultiplicity]
  omega

example (assignment : QuerySubstitution) :
    substituteQueryNatural assignment (.variable 1) = .variable 1 := rfl

example (assignment : QuerySubstitution) (atom : Nat) :
    naturalLinearCount assignment atom (.variable 1) = if atom = 2 then 1 else 0 := rfl

example (assignment : QuerySubstitution)
    (residual : assignment.naturals 0 = .add (.variable 20) .one) :
    naturalLinearCount assignment 21 (.add (.variable 0) (.variable 0)) = 2 := by
  simp [naturalLinearCount, naturalVariableOccurrences, naturalRigidMultiplicity,
    residual, naturalMultiplicity, naturalAtomCodes]

example (assignment : QuerySubstitution)
    (first : assignment.naturals 0 = .variable 2) :
    naturalLinearCount assignment 3 (.variable 0) = 1 := by
  simp [naturalLinearCount, naturalVariableOccurrences, naturalRigidMultiplicity,
    first, naturalMultiplicity, naturalAtomCodes]

example (assignment : QuerySubstitution) :
    ¬ NaturalAC (substituteQueryNatural assignment (.add (.variable 0) (.variable 0))) .one := by
  intro equivalent
  have counts := natural_ac_multiplicity_iff.mp equivalent 0
  rw [natural_linear_count_substitution] at counts
  have literal : naturalMultiplicity 0 .one = 1 := rfl
  rw [literal] at counts
  simp [naturalLinearCount, naturalRigidMultiplicity, naturalVariableOccurrences] at counts
  omega

end Cairn.Equations
