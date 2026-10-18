import NaturalBindings

namespace Cairn.Equations

def naturalAtomImage (assignment : QuerySubstitution) (code : Nat) : List Nat :=
  if code = 0 then [0]
  else if (code - 1) % 2 = 0 then naturalAtomCodes (assignment.naturals ((code - 1) / 2))
  else [code]

theorem natural_substitution_atom_codes (assignment : QuerySubstitution) (term : NaturalTerm) :
    naturalAtomCodes (substituteQueryNatural assignment term) =
      (naturalAtomCodes term).flatMap (naturalAtomImage assignment) := by
  induction term with
  | one => simp [naturalAtomCodes, substituteQueryNatural, naturalAtomImage]
  | «variable» index =>
    by_cases even : index % 2 = 0 <;>
      simp [substituteQueryNatural, naturalAtomCodes, naturalAtomImage, even]
  | add left right first second =>
    simp [substituteQueryNatural, naturalAtomCodes, List.flatMap_append, first, second]

theorem natural_atom_image_rigid (assignment : QuerySubstitution) (code : Nat)
    (even : code % 2 = 0) : naturalAtomImage assignment code = [code] := by
  cases code with
  | zero => simp [naturalAtomImage]
  | succ label =>
    have odd : label % 2 ≠ 0 := by omega
    simp [naturalAtomImage, odd]

theorem natural_atom_image_variable (assignment : QuerySubstitution) (index : Nat) :
    naturalAtomImage assignment (2 * index + 1) = naturalAtomCodes (assignment.naturals index) := by
  simp [naturalAtomImage]

theorem natural_residual_factor_realization (indices : List Nat) (basis : List (List NaturalColumn))
    (factor : Sum Nat (List NaturalColumn) → List Nat) (nonempty : ∀ name, factor name ≠ []) :
    ∃ typed : QuerySubstitution, ∀ generator ∈ basis,
      naturalAtomCodes (typed.naturals (naturalResidualIndex indices basis generator)) =
        factor (.inr generator) := by
  classical
  have existsTerm (generator : List NaturalColumn) :
      ∃ term, naturalTermFromAtomCodes (factor (.inr generator)) = some term :=
    natural_codes_decode_exists _ (nonempty _)
  let terms (generator : List NaturalColumn) := Classical.choose (existsTerm generator)
  let values (index : Nat) :=
    match basis.find? (fun generator => naturalResidualIndex indices basis generator == index) with
    | none => NaturalTerm.variable (2 * index)
    | some generator => terms generator
  refine ⟨naturalOnlySubstitution values, ?_⟩
  intro generator member
  cases found : basis.find?
      (fun entry => naturalResidualIndex indices basis entry ==
        naturalResidualIndex indices basis generator) with
  | none =>
    have absent := List.find?_eq_none.mp found generator member
    simp at absent
  | some selected =>
    have selectedMember := List.mem_of_find?_eq_some found
    have checked := List.find?_some
      (p := fun entry => naturalResidualIndex indices basis entry ==
        naturalResidualIndex indices basis generator) found
    have equal := natural_residual_index_injective indices basis selectedMember member
      (eq_of_beq checked)
    subst selected
    simp only [naturalOnlySubstitution, values, found]
    exact natural_codes_decode_exact _ (Classical.choose_spec (existsTerm generator))

#print axioms natural_substitution_atom_codes
#print axioms natural_atom_image_rigid
#print axioms natural_atom_image_variable
#print axioms natural_residual_factor_realization

end Cairn.Equations
