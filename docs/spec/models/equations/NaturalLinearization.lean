import NaturalMultiplicity
import QuerySubstitution

namespace Cairn.Equations

-- Repeated occurrences retain their coefficient; odd labels remain rigid.
def naturalVariableOccurrences : NaturalTerm → List Nat
  | .one => []
  | .variable identifier => if identifier % 2 = 0 then [identifier / 2] else []
  | .add left right => naturalVariableOccurrences left ++ naturalVariableOccurrences right

def naturalRigidMultiplicity (atom : Nat) : NaturalTerm → Nat
  | .one => if atom = 0 then 1 else 0
  | .variable identifier =>
    if identifier % 2 = 0 then 0 else if atom = identifier + 1 then 1 else 0
  | .add left right => naturalRigidMultiplicity atom left + naturalRigidMultiplicity atom right

def naturalLinearCount (assignment : QuerySubstitution) (atom : Nat) (term : NaturalTerm) : Nat :=
  naturalRigidMultiplicity atom term +
    ((naturalVariableOccurrences term).map fun index =>
      naturalMultiplicity atom (assignment.naturals index)).sum

private theorem singleton_count (atom leaf : Nat) :
    [leaf].count atom = if atom = leaf then 1 else 0 := by
  by_cases equal : atom = leaf
  · subst atom
    simp
  · rw [List.count_cons_of_ne (Ne.symm equal), List.count_nil]
    simp [equal]

theorem natural_linear_count_substitution (assignment : QuerySubstitution)
    (atom : Nat) (term : NaturalTerm) :
    naturalMultiplicity atom (substituteQueryNatural assignment term) =
      naturalLinearCount assignment atom term := by
  induction term with
  | one =>
    simp [naturalMultiplicity, naturalAtomCodes, substituteQueryNatural,
      naturalLinearCount, naturalRigidMultiplicity, naturalVariableOccurrences,
      singleton_count]
  | «variable» identifier =>
    by_cases even : identifier % 2 = 0 <;>
      simp [substituteQueryNatural, naturalLinearCount, naturalVariableOccurrences,
        naturalRigidMultiplicity, even, naturalMultiplicity, naturalAtomCodes,
        singleton_count]
  | add left right first second =>
    simp only [substituteQueryNatural, natural_multiplicity_add, first, second,
      naturalLinearCount, naturalRigidMultiplicity, naturalVariableOccurrences,
      List.map_append, List.sum_append]
    omega

theorem natural_linear_unifier_iff (assignment : QuerySubstitution) (left right : NaturalTerm) :
    NaturalAC (substituteQueryNatural assignment left) (substituteQueryNatural assignment right) ↔
      ∀ atom, naturalLinearCount assignment atom left = naturalLinearCount assignment atom right := by
  rw [natural_ac_multiplicity_iff]
  simp only [natural_linear_count_substitution]

#print axioms natural_linear_count_substitution
#print axioms natural_linear_unifier_iff

end Cairn.Equations
