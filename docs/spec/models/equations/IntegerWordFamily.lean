import IntegerMatrixFactors

namespace Cairn.Equations

def integerWordSelections : List α → List (List α)
  | [] => [[]]
  | first :: rest =>
    let choices := integerWordSelections rest
    choices ++ choices.map (fun selected => first :: selected)

def integerMatrixWordFamily [DecidableEq α] (alphabet : List α) (rows : List (α → Int)) :
    List (α → List (List α)) :=
  ((integerWordSelections (integerMatrixWordBasis alphabet rows).eraseDups).map
    (fun selected letter => integerWordMixture selected (fun generator => [generator]) letter)).filter
      (fun candidate => alphabet.all (fun letter => !(candidate letter).isEmpty))

theorem integer_word_selection_scope (basis : List α) (selected : List α)
    (member : selected ∈ integerWordSelections basis) :
    ∀ generator ∈ selected, generator ∈ basis := by
  induction basis generalizing selected with
  | nil =>
    have equal : selected = [] := List.mem_singleton.mp member
    subst selected
    simp
  | cons first rest induction =>
    rcases List.mem_append.mp member with remaining | added
    · intro generator occurs
      exact List.mem_cons_of_mem _ (induction selected remaining generator occurs)
    · obtain ⟨previous, previousMember, rfl⟩ := List.mem_map.mp added
      intro generator occurs
      rcases List.mem_cons.mp occurs with rfl | occurs
      · exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (induction previous previousMember generator occurs)

theorem integer_word_selection_filter (basis : List α) (predicate : α → Bool) :
    basis.filter predicate ∈ integerWordSelections basis := by
  induction basis with
  | nil => simp [integerWordSelections]
  | cons first rest induction =>
    cases choice : predicate first with
    | false =>
      simpa [List.filter_cons, choice, integerWordSelections] using
        List.mem_append_left
          ((integerWordSelections rest).map (fun selected => first :: selected)) induction
    | true =>
      have included : first :: rest.filter predicate ∈ integerWordSelections (first :: rest) :=
        List.mem_append_right (integerWordSelections rest)
          (List.mem_map.mpr ⟨rest.filter predicate, induction, rfl⟩)
      simpa [List.filter_cons, choice] using included

theorem integer_matrix_word_family_nonempty [DecidableEq α] (alphabet : List α)
    (rows : List (α → Int)) (member : candidate ∈ integerMatrixWordFamily alphabet rows) :
    ∀ letter ∈ alphabet, candidate letter ≠ [] := by
  have allowed := List.all_eq_true.mp (List.mem_filter.mp member).2
  intro letter occurs empty
  have check := allowed letter occurs
  simp [empty] at check

#print axioms integer_word_selection_scope
#print axioms integer_word_selection_filter
#print axioms integer_matrix_word_family_nonempty

end Cairn.Equations
