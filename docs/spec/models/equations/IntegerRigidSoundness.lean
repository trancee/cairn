import IntegerRigidFamily
import IntegerMixtureSoundness

namespace Cairn.Equations

theorem integer_rigid_word_family_sound [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β)) (unique : alphabet.Nodup)
    (member : candidate ∈ integerRigidWordFamily alphabet rows rigid) :
    ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet candidate atom) = 0 := by
  letI : LawfulBEq (Sum β (List α)) := {
    eq_of_beq := by
      intro first second equal
      cases first with
      | inl first =>
        cases second with
        | inl second =>
          have underlying : (first == second) = true := equal
          exact congrArg Sum.inl (eq_of_beq underlying)
        | inr second => cases equal
      | inr first =>
        cases second with
        | inl second => cases equal
        | inr second =>
          have underlying : (first == second) = true := equal
          exact congrArg Sum.inr (eq_of_beq underlying)
    rfl := by
      intro value
      cases value with
      | inl atom =>
        change (atom == atom) = true
        simp
      | inr generator =>
        change (generator == generator) = true
        simp
  }
  obtain ⟨chosen, _, rfl⟩ := List.mem_map.mp (List.mem_filter.mp member).1
  have valid (generator : List α)
      (occurs : generator ∈ (integerMatrixWordBasis alphabet rows).eraseDups) :=
    integer_matrix_word_basis_sound alphabet rows (List.mem_eraseDups.mp occurs)
  intro atom row checked
  exact integer_word_mixture_balanced alphabet _ chosen unique
    (fun generator occurs => (valid generator occurs).2.1) row
    (fun generator occurs => (valid generator occurs).2.2 row checked) atom

#print axioms integer_rigid_word_family_sound

end Cairn.Equations
