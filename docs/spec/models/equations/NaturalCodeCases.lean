import NaturalMultiplicity

namespace Cairn.Equations

example : naturalTermFromAtomCodes [0, 5, 2] =
    some (.add .one (.add (.variable 4) (.variable 1))) := rfl

example : naturalTermFromAtomCodes [] = none := rfl

example (codes : List Nat) : naturalTermFromAtomCodes codes = none ↔ codes = [] :=
  natural_codes_decode_empty codes

example (codes : List Nat) (decoded : naturalTermFromAtomCodes codes = some term) :
    naturalAtomCodes term = codes :=
  natural_codes_decode_exact codes decoded

example (codes : List Nat) (nonempty : codes ≠ []) :
    ∃ term, naturalTermFromAtomCodes codes = some term :=
  natural_codes_decode_exists codes nonempty

example (term : NaturalTerm) :
    ∃ decoded, naturalTermFromAtomCodes (naturalAtomCodes term) = some decoded ∧
      NaturalAC decoded term := by
  obtain ⟨decoded, present⟩ :=
    natural_codes_decode_exists _ (natural_atom_codes_nonempty term)
  refine ⟨decoded, present, natural_ac_atoms_iff.mpr ?_⟩
  rw [natural_codes_decode_exact _ present]

end Cairn.Equations
