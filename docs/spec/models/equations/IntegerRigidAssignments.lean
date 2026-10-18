import IntegerRigidFamily

namespace Cairn.Equations

theorem integer_word_rigid_assignments_complete [DecidableEq α] (constants : List β)
    (basis : List (List α)) (unique : basis.Nodup) (desired : List α → List (Sum β (List α)))
    (allowed : ∀ generator ∈ basis, desired generator ∈ integerWordRigidChoices constants generator) :
    ∃ chosen ∈ integerWordRigidAssignments constants basis,
      ∀ generator ∈ basis, chosen generator = desired generator := by
  induction basis with
  | nil => exact ⟨fun _ => [], by simp [integerWordRigidAssignments], by simp⟩
  | cons generator rest induction =>
    obtain ⟨absent, remaining⟩ := List.nodup_cons.mp unique
    obtain ⟨previous, previousMember, agrees⟩ := induction remaining
      (fun entry member => allowed entry (List.mem_cons_of_mem _ member))
    let chosen (name : List α) := if name = generator then desired generator else previous name
    refine ⟨chosen, ?_, ?_⟩
    · exact List.mem_flatMap.mpr ⟨previous, previousMember,
        List.mem_map.mpr ⟨desired generator, allowed generator (by simp), rfl⟩⟩
    · intro name member
      rcases List.mem_cons.mp member with rfl | occurs
      · simp [chosen]
      · have different : name ≠ generator := by
          intro equal
          exact absent (equal ▸ occurs)
        simp [chosen, different, agrees name occurs]

#print axioms integer_word_rigid_assignments_complete

end Cairn.Equations
