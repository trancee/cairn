import IntegerRigidWitness
import IntegerMixtureComponents
import IntegerMixtureTransport

namespace Cairn.Equations

theorem integer_rigid_word_family_complete [DecidableEq α] [DecidableEq β]
    (alphabet : List α) (rows : List (α → Int)) (rigid : List (α × β)) (values : α → List β)
    (unique : alphabet.Nodup) (defaultAtom : β)
    (nonempty : ∀ letter ∈ alphabet, values letter ≠ [])
    (rigidScope : ∀ binding ∈ rigid, binding.1 ∈ alphabet)
    (fixed : ∀ binding ∈ rigid, values binding.1 = [binding.2])
    (balanced : ∀ atom row, row ∈ rows →
      integerWordSum row (integerWordTranspose alphabet values atom) = 0) :
    ∃ candidate ∈ integerRigidWordFamily alphabet rows rigid,
      ∃ factor : Sum β (List α) → List β,
        (∀ name, factor name ≠ []) ∧ (∀ atom, factor (Sum.inl atom) = [atom]) ∧
          ∀ letter ∈ alphabet, (values letter).Perm ((candidate letter).flatMap factor) := by
  obtain ⟨factors, reconstruct⟩ :=
    integer_matrix_word_factorization alphabet rows values unique balanced
  let basis := (integerMatrixWordBasis alphabet rows).eraseDups
  have components (generator : List α) (member : generator ∈ basis) :
      ∀ binding ∈ rigid, binding.1 ∈ generator →
        factors generator ≠ [] → factors generator = [binding.2] := by
    intro binding marked occurs active
    have original := reconstruct binding.1 (rigidScope binding marked)
    rw [fixed binding marked] at original
    exact integer_word_mixture_rigid_component basis factors member occurs
      original.singleton_eq.symm active
  let desired := integerWordRigidFactorChoice rigid factors
  obtain ⟨chosen, chosenMember, agrees⟩ := integer_word_rigid_assignments_complete
    (rigid.map Prod.snd) basis (integer_word_erase_duplicates_unique _) desired
    (fun generator _ => integer_word_rigid_choice_allowed rigid factors generator)
  let factor := integerWordRigidPostfactor defaultAtom factors
  let candidate := integerWordMixture basis chosen
  have instantiated (generator : List α) (member : generator ∈ basis) :
      (chosen generator).flatMap factor = factors generator := by
    rw [agrees generator member]
    exact integer_word_rigid_choice_instantiation rigid factors generator defaultAtom
      (components generator member)
  have original (letter : α) (member : letter ∈ alphabet) :
      (values letter).Perm ((candidate letter).flatMap factor) := by
    change (values letter).Perm ((integerWordMixture basis chosen letter).flatMap factor)
    rw [integer_word_mixture_bind,
      integer_word_mixture_congr basis _ factors letter instantiated]
    exact reconstruct letter member
  have candidateNonempty (letter : α) (member : letter ∈ alphabet) : candidate letter ≠ [] := by
    intro empty
    have known := original letter member
    rw [empty] at known
    exact nonempty letter member known.eq_nil
  have candidateFixed (binding : α × β) (member : binding ∈ rigid) :
      candidate binding.1 = [Sum.inl binding.2] := by
    change integerWordMixture basis chosen binding.1 = _
    rw [integer_word_mixture_relevant_congr basis chosen
      (fun generator => (factors generator).map Sum.inl) binding.1
      (fun generator occurs present => by
        rw [agrees generator occurs]
        exact integer_word_rigid_choice_ground rigid factors generator member present
          (components generator occurs)), ← integer_word_mixture_map]
    have known := reconstruct binding.1 (rigidScope binding member)
    rw [fixed binding member] at known
    rw [known.singleton_eq.symm]
    rfl
  have included : candidate ∈ integerRigidWordFamily alphabet rows rigid := by
    apply List.mem_filter.mpr
    refine ⟨List.mem_map.mpr ⟨chosen, chosenMember, rfl⟩, ?_⟩
    apply Bool.and_eq_true_iff.mpr
    constructor
    · apply List.all_eq_true.mpr
      intro letter member
      cases contents : candidate letter with
      | nil => exact (candidateNonempty letter member contents).elim
      | cons first rest => simp
    · apply List.all_eq_true.mpr
      intro binding member
      simpa only [decide_eq_true_eq] using candidateFixed binding member
  exact ⟨candidate, included, factor, integer_word_rigid_postfactor_nonempty defaultAtom factors,
    fun _ => rfl, original⟩

#print axioms integer_rigid_word_family_complete

end Cairn.Equations
