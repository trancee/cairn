import Termination
import Init.Data.List.Perm

namespace Cairn.Equations

-- Code zero denotes the literal one, not an additive identity.
def naturalAtomCodes : NaturalTerm → List Nat
  | .one => [0]
  | .variable index => [index + 1]
  | .add left right => naturalAtomCodes left ++ naturalAtomCodes right

def naturalMultiplicity (atom : Nat) (term : NaturalTerm) : Nat :=
  (naturalAtomCodes term).count atom

private def naturalAtomTerm : Nat → NaturalTerm
  | 0 => .one
  | index + 1 => .variable index

private def joinNatural : Option NaturalTerm → Option NaturalTerm → Option NaturalTerm
  | none, right => right
  | some left, none => some left
  | some left, some right => some (.add left right)

private def foldNaturalAtoms : List Nat → Option NaturalTerm
  | [] => none
  | atom :: rest => joinNatural (some (naturalAtomTerm atom)) (foldNaturalAtoms rest)

def naturalTermFromAtomCodes (codes : List Nat) : Option NaturalTerm :=
  foldNaturalAtoms codes

theorem natural_codes_decode_empty (codes : List Nat) :
    naturalTermFromAtomCodes codes = none ↔ codes = [] := by
  cases codes with
  | nil => simp [naturalTermFromAtomCodes, foldNaturalAtoms]
  | cons atom rest =>
    cases folded : foldNaturalAtoms rest <;>
      simp [naturalTermFromAtomCodes, foldNaturalAtoms, joinNatural, folded]

theorem natural_codes_decode_exact (codes : List Nat)
    (decoded : naturalTermFromAtomCodes codes = some term) : naturalAtomCodes term = codes := by
  induction codes generalizing term with
  | nil => simp [naturalTermFromAtomCodes, foldNaturalAtoms] at decoded
  | cons atom rest induction =>
    cases folded : foldNaturalAtoms rest with
    | none =>
      have empty := (natural_codes_decode_empty rest).mp folded
      have equal : naturalAtomTerm atom = term := by
        simpa [naturalTermFromAtomCodes, foldNaturalAtoms, joinNatural, folded] using decoded
      rw [← equal, empty]
      cases atom <;> rfl
    | some remaining =>
      have exactTail := induction folded
      have equal : NaturalTerm.add (naturalAtomTerm atom) remaining = term := by
        simpa [naturalTermFromAtomCodes, foldNaturalAtoms, joinNatural, folded] using decoded
      rw [← equal, naturalAtomCodes, exactTail]
      cases atom <;> rfl

theorem natural_codes_decode_exists (codes : List Nat) (nonempty : codes ≠ []) :
    ∃ term, naturalTermFromAtomCodes codes = some term := by
  cases decoded : naturalTermFromAtomCodes codes with
  | none => exact (nonempty ((natural_codes_decode_empty codes).mp decoded)).elim
  | some term => exact ⟨term, rfl⟩

private def OptionalNaturalAC : Option NaturalTerm → Option NaturalTerm → Prop
  | none, none => True
  | some left, some right => NaturalAC left right
  | none, some _ | some _, none => False

private theorem optional_reflexive (term : Option NaturalTerm) :
    OptionalNaturalAC term term := by
  cases term with
  | none => trivial
  | some term => exact .reflexive

private theorem optional_symmetric (equivalent : OptionalNaturalAC left right) :
    OptionalNaturalAC right left := by
  cases left <;> cases right <;> simp_all [OptionalNaturalAC]
  exact .symmetric equivalent

private theorem optional_transitive (first : OptionalNaturalAC left middle)
    (second : OptionalNaturalAC middle right) : OptionalNaturalAC left right := by
  cases left <;> cases middle <;> cases right <;> simp_all [OptionalNaturalAC]
  exact .transitive first second

private theorem join_congruence (first : OptionalNaturalAC firstLeft firstRight)
    (second : OptionalNaturalAC secondLeft secondRight) :
    OptionalNaturalAC (joinNatural firstLeft secondLeft) (joinNatural firstRight secondRight) := by
  cases firstLeft <;> cases firstRight <;> cases secondLeft <;> cases secondRight <;>
    simp_all [OptionalNaturalAC, joinNatural]
  exact .transitive (.addLeft first) (.addRight second)

private theorem join_associative (first second third : Option NaturalTerm) :
    OptionalNaturalAC (joinNatural (joinNatural first second) third)
      (joinNatural first (joinNatural second third)) := by
  cases first <;> cases second <;> cases third <;> simp [joinNatural, OptionalNaturalAC]
  all_goals first | exact .reflexive | exact .associative

private theorem join_commutative (left right : Option NaturalTerm) :
    OptionalNaturalAC (joinNatural left right) (joinNatural right left) := by
  cases left <;> cases right <;> simp [joinNatural, OptionalNaturalAC]
  all_goals first | exact .reflexive | exact .commutative

private theorem fold_append (left right : List Nat) :
    OptionalNaturalAC (foldNaturalAtoms (left ++ right))
      (joinNatural (foldNaturalAtoms left) (foldNaturalAtoms right)) := by
  induction left with
  | nil => exact optional_reflexive _
  | cons atom rest induction =>
    simp only [List.cons_append, foldNaturalAtoms]
    exact optional_transitive (join_congruence (optional_reflexive _) induction)
      (optional_symmetric (join_associative _ _ _))

private theorem fold_permutation (permutation : left.Perm right) :
    OptionalNaturalAC (foldNaturalAtoms left) (foldNaturalAtoms right) := by
  induction permutation with
  | nil => trivial
  | cons _ _ induction => exact join_congruence (optional_reflexive _) induction
  | swap first second rest =>
    exact optional_transitive (optional_symmetric (join_associative _ _ _))
      (optional_transitive (join_congruence (join_commutative _ _) (optional_reflexive _))
        (join_associative _ _ _))
  | trans _ _ first second => exact optional_transitive first second

private theorem fold_round_trip (term : NaturalTerm) :
    OptionalNaturalAC (foldNaturalAtoms (naturalAtomCodes term)) (some term) := by
  induction term with
  | one => exact .reflexive
  | «variable» index => exact .reflexive
  | add left right first second =>
    exact optional_transitive (fold_append _ _) (join_congruence first second)

theorem natural_atom_codes_nonempty (term : NaturalTerm) : naturalAtomCodes term ≠ [] := by
  induction term <;> simp_all [naturalAtomCodes]

theorem natural_ac_atoms_iff :
    NaturalAC left right ↔ (naturalAtomCodes left).Perm (naturalAtomCodes right) := by
  constructor
  · intro equivalent
    induction equivalent with
    | reflexive => exact .refl _
    | symmetric _ induction => exact induction.symm
    | transitive _ _ first second => exact first.trans second
    | associative => simp [naturalAtomCodes, List.append_assoc]
    | commutative => exact List.perm_append_comm
    | addLeft _ induction => exact induction.append (.refl _)
    | addRight _ induction => exact (List.Perm.refl _).append induction
  · intro permutation
    exact optional_transitive (optional_symmetric (fold_round_trip _))
      (optional_transitive (fold_permutation permutation) (fold_round_trip _))

theorem natural_ac_multiplicity_iff :
    NaturalAC left right ↔ ∀ atom, naturalMultiplicity atom left = naturalMultiplicity atom right := by
  rw [natural_ac_atoms_iff, List.perm_iff_count]
  rfl

theorem natural_multiplicity_add (atom : Nat) (left right : NaturalTerm) :
    naturalMultiplicity atom (.add left right) =
      naturalMultiplicity atom left + naturalMultiplicity atom right := by
  simp [naturalMultiplicity, naturalAtomCodes, List.count_append]

#print axioms natural_atom_codes_nonempty
#print axioms natural_ac_atoms_iff
#print axioms natural_ac_multiplicity_iff
#print axioms natural_multiplicity_add
#print axioms natural_codes_decode_empty
#print axioms natural_codes_decode_exact
#print axioms natural_codes_decode_exists

end Cairn.Equations
