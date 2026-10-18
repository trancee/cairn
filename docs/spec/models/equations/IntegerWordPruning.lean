import IntegerWordInclusion

namespace Cairn.Equations

def integerWordRepresentatives [DecidableEq α] : List (List α) → List (List α)
  | [] => []
  | word :: words =>
    let remaining := integerWordRepresentatives words
    if remaining.any (fun other => decide (word.Perm other)) then remaining else word :: remaining

theorem integer_word_representative_member [DecidableEq α] (basis : List (List α))
    (member : word ∈ integerWordRepresentatives basis) : word ∈ basis := by
  induction basis with
  | nil => simp [integerWordRepresentatives] at member
  | cons first rest induction =>
    simp only [integerWordRepresentatives] at member
    split at member
    · exact List.mem_cons_of_mem _ (induction member)
    · rcases List.mem_cons.mp member with rfl | member
      · exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (induction member)

theorem integer_word_representative_complete [DecidableEq α] (basis : List (List α))
    (member : word ∈ basis) :
    ∃ representative ∈ integerWordRepresentatives basis, word.Perm representative := by
  induction basis with
  | nil => simp at member
  | cons first rest induction =>
    rcases List.mem_cons.mp member with rfl | member
    · simp only [integerWordRepresentatives]
      split
      · rename_i found
        obtain ⟨representative, representativeMember, equivalent⟩ := List.any_eq_true.mp found
        exact ⟨representative, representativeMember, of_decide_eq_true equivalent⟩
      · exact ⟨word, List.mem_cons_self, .refl _⟩
    · obtain ⟨representative, representativeMember, equivalent⟩ := induction member
      refine ⟨representative, ?_, equivalent⟩
      simp only [integerWordRepresentatives]
      split
      · exact representativeMember
      · exact List.mem_cons_of_mem _ representativeMember

def integerPrimitiveWordBasis [DecidableEq α] (basis : List (List α)) : List (List α) :=
  let representatives := integerWordRepresentatives basis
  representatives.filter (fun word => decide (¬ ∃ other ∈ representatives,
    other.length < word.length ∧ integerWordContains other word = true))

theorem integer_primitive_basis_member [DecidableEq α] (basis : List (List α))
    (member : word ∈ integerPrimitiveWordBasis basis) : word ∈ basis :=
  integer_word_representative_member basis (List.mem_filter.mp member).1

theorem integer_primitive_subword [DecidableEq α] (basis : List (List α)) (word : List α)
    (member : word ∈ basis) :
    ∃ primitive ∈ integerPrimitiveWordBasis basis,
      ∃ rest, word.Perm (primitive ++ rest) := by
  obtain ⟨representative, representativeMember, equivalent⟩ :=
    integer_word_representative_complete basis member
  by_cases smaller : ∃ other ∈ integerWordRepresentatives basis,
      other.length < representative.length ∧ integerWordContains other representative = true
  · obtain ⟨other, otherMember, shorter, included⟩ := smaller
    obtain ⟨primitive, primitiveMember, rest, permutation⟩ :=
      integer_primitive_subword basis other (integer_word_representative_member basis otherMember)
    obtain ⟨remaining, contains⟩ := (integer_word_contains_iff other representative).mp included
    refine ⟨primitive, primitiveMember, rest ++ remaining, ?_⟩
    simpa only [List.append_assoc] using
      equivalent.trans (contains.trans (permutation.append_right remaining))
  · refine ⟨representative, List.mem_filter.mpr ⟨representativeMember, ?_⟩, [], ?_⟩
    · exact decide_eq_true smaller
    · simpa only [List.append_nil] using equivalent
termination_by word.length
decreasing_by
  have lengths := equivalent.length_eq
  omega

#print axioms integer_word_representative_member
#print axioms integer_word_representative_complete
#print axioms integer_primitive_basis_member
#print axioms integer_primitive_subword

end Cairn.Equations
