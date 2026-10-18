import IntegerMixtureAlgebra

namespace Cairn.Equations

theorem integer_word_mixture_component [BEq α] [LawfulBEq α]
    (basis : List (List α)) (values : List α → List β)
    (member : generator ∈ basis) (occurs : letter ∈ generator) :
    ∃ rest, (integerWordMixture basis values letter).Perm (values generator ++ rest) := by
  induction basis with
  | nil => simp at member
  | cons first tail induction =>
    rcases List.mem_cons.mp member with rfl | remaining
    · have positive := List.count_pos_iff.mpr occurs
      cases count : generator.count letter with
      | zero => simp [count] at positive
      | succ times =>
        rw [integer_word_mixture_cons, count, List.replicate_succ, List.flatten_cons,
          List.append_assoc]
        exact ⟨_, .refl _⟩
    · obtain ⟨rest, extracted⟩ := induction remaining
      refine ⟨(List.replicate (first.count letter) (values first)).flatten ++ rest, ?_⟩
      rw [integer_word_mixture_cons]
      exact ((List.Perm.refl _).append extracted).trans
        (List.perm_append_comm_assoc _ _ _)

theorem integer_word_mixture_rigid_component [BEq α] [LawfulBEq α]
    (basis : List (List α)) (values : List α → List β)
    (member : generator ∈ basis) (occurs : letter ∈ generator)
    (fixed : integerWordMixture basis values letter = [atom])
    (nonempty : values generator ≠ []) :
    values generator = [atom] := by
  obtain ⟨rest, extracted⟩ := integer_word_mixture_component basis values member occurs
  rw [fixed] at extracted
  cases contents : values generator with
  | nil => exact (nonempty contents).elim
  | cons first tail =>
    have equal : [atom] = (first :: tail) ++ rest := by
      simpa only [contents] using extracted.singleton_eq
    obtain ⟨headEqual, tailEqual⟩ := List.cons.inj equal
    have empty : tail = [] := (List.append_eq_nil_iff.mp tailEqual.symm).1
    simp [empty, headEqual]

#print axioms integer_word_mixture_component
#print axioms integer_word_mixture_rigid_component

end Cairn.Equations
