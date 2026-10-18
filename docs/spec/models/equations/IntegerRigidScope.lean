import IntegerRigidSoundness
import IntegerMixtureTransport

namespace Cairn.Equations

def IntegerRigidNameSupported (constants : List β) (basis : List (List α)) :
    Sum β (List α) → Prop
  | .inl atom => atom ∈ constants
  | .inr residual => residual ∈ basis

theorem integer_word_rigid_assignments_scope [DecidableEq α] (constants : List β)
    (basis : List (List α))
    (member : chosen ∈ integerWordRigidAssignments constants basis)
    (generator : List α) (name : Sum β (List α)) (occurs : name ∈ chosen generator) :
    IntegerRigidNameSupported constants basis name := by
  induction basis generalizing chosen with
  | nil =>
    have equal := List.mem_singleton.mp member
    subst chosen
    simp at occurs
  | cons first rest induction =>
    obtain ⟨previous, previousMember, selected⟩ := List.mem_flatMap.mp member
    obtain ⟨choice, choiceMember, rfl⟩ := List.mem_map.mp selected
    by_cases same : generator = first
    · simp only [same, ite_true] at occurs
      rcases List.mem_cons.mp choiceMember with rfl | choiceMember
      · simp at occurs
      · rcases List.mem_cons.mp choiceMember with rfl | choiceMember
        · have equal := List.mem_singleton.mp occurs
          subst name
          simp [IntegerRigidNameSupported]
        · obtain ⟨atom, atomMember, rfl⟩ := List.mem_map.mp choiceMember
          have equal := List.mem_singleton.mp occurs
          subst name
          exact atomMember
    · simp only [ite_eq_right same] at occurs
      have prior := induction previousMember occurs
      cases name with
      | inl => exact prior
      | inr => exact List.mem_cons_of_mem _ prior

theorem integer_rigid_word_family_name_scope [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β))
    (member : candidate ∈ integerRigidWordFamily alphabet rows rigid)
    (letter : α) (name : Sum β (List α)) (occurs : name ∈ candidate letter) :
    IntegerRigidNameSupported (rigid.map Prod.snd)
      (integerMatrixWordBasis alphabet rows).eraseDups name := by
  obtain ⟨chosen, chosenMember, rfl⟩ := List.mem_map.mp (List.mem_filter.mp member).1
  obtain ⟨word, generated, contained⟩ := List.mem_flatten.mp occurs
  obtain ⟨generator, _, repeated⟩ := List.mem_flatMap.mp generated
  obtain ⟨_, equal⟩ := List.mem_replicate.mp repeated
  subst word
  exact integer_word_rigid_assignments_scope _ _ chosenMember generator name contained

theorem integer_rigid_word_family_map_sound [DecidableEq α] [DecidableEq β]
    [BEq γ] [LawfulBEq γ]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β))
    (unique : alphabet.Nodup) (member : candidate ∈ integerRigidWordFamily alphabet rows rigid)
    (mapping : Sum β (List α) → γ) :
    ∀ atom row, row ∈ rows →
      integerWordSum row
        (integerWordTranspose alphabet (fun letter => (candidate letter).map mapping) atom) = 0 := by
  obtain ⟨chosen, _, rfl⟩ := List.mem_map.mp (List.mem_filter.mp member).1
  have mapped :
      (fun letter => (integerWordMixture
        (integerMatrixWordBasis alphabet rows).eraseDups chosen letter).map mapping) =
      integerWordMixture (integerMatrixWordBasis alphabet rows).eraseDups
        (fun generator => (chosen generator).map mapping) := by
    funext letter
    exact integer_word_mixture_map _ _ _ _
  rw [mapped]
  intro atom row checked
  have valid (generator : List α)
      (occurs : generator ∈ (integerMatrixWordBasis alphabet rows).eraseDups) :=
    integer_matrix_word_basis_sound alphabet rows (List.mem_eraseDups.mp occurs)
  exact integer_word_mixture_balanced alphabet _ _ unique
    (fun generator occurs => (valid generator occurs).2.1) row
    (fun generator occurs => (valid generator occurs).2.2 row checked) atom

#print axioms integer_word_rigid_assignments_scope
#print axioms integer_rigid_word_family_name_scope
#print axioms integer_rigid_word_family_map_sound

end Cairn.Equations
