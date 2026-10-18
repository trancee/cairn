import NaturalMultiplicity

namespace Cairn.Equations

example (left right : NaturalTerm) :
    NaturalAC left right ↔ ∀ atom, naturalMultiplicity atom left = naturalMultiplicity atom right :=
  natural_ac_multiplicity_iff

example : naturalAtomCodes .one = [0] := rfl

example : naturalAtomCodes (.variable 0) = [1] := rfl

example : naturalAtomCodes (.add (.variable 0) (.variable 0)) = [1, 1] := rfl

example : naturalMultiplicity 1 (.add (.variable 0) (.variable 0)) = 2 := rfl

example : naturalMultiplicity 0 (.add .one (.variable 0)) = 1 := rfl

example : naturalAtomCodes (.variable 0) ≠ naturalAtomCodes (.variable 1) := by decide

example : naturalWeight .one = naturalWeight (.variable 0) := rfl

example : ¬ NaturalAC .one (.variable 0) := by
  intro equivalent
  have count := natural_ac_multiplicity_iff.mp equivalent 0
  simp [naturalMultiplicity, naturalAtomCodes] at count

example (term : NaturalTerm) : ¬ NaturalAC (.add term .one) term := by
  intro equivalent
  have count := natural_ac_multiplicity_iff.mp equivalent 0
  rw [natural_multiplicity_add] at count
  have literal : naturalMultiplicity 0 .one = 1 := rfl
  rw [literal] at count
  omega

example (term : NaturalTerm) : naturalAtomCodes term ≠ [] := natural_atom_codes_nonempty term

example : NaturalAC (.add (.add (.variable 1) .one) (.variable 0))
    (.add (.variable 0) (.add .one (.variable 1))) := by
  apply natural_ac_multiplicity_iff.mpr
  intro atom
  simp only [natural_multiplicity_add]
  omega

example : ¬ NaturalAC (.add (.variable 0) (.variable 0))
    (.add (.variable 0) (.variable 1)) := by
  intro equivalent
  have count := natural_ac_multiplicity_iff.mp equivalent 1
  simp [naturalMultiplicity, naturalAtomCodes] at count

end Cairn.Equations
