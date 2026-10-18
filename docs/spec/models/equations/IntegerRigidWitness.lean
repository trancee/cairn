import IntegerRigidAssignments

namespace Cairn.Equations

def integerWordRigidFactorChoice [DecidableEq α] (rigid : List (α × β))
    (values : List α → List β) (generator : List α) : List (Sum β (List α)) :=
  match values generator with
  | [] => []
  | _ :: _ =>
    match rigid.find? (fun binding => decide (binding.1 ∈ generator)) with
    | none => [Sum.inr generator]
    | some binding => [Sum.inl binding.2]

def integerWordRigidPostfactor (defaultAtom : β) (values : List α → List β) :
    Sum β (List α) → List β
  | .inl atom => [atom]
  | .inr generator =>
    match values generator with
    | [] => [defaultAtom]
    | first :: rest => first :: rest

theorem integer_word_rigid_choice_allowed [DecidableEq α] (rigid : List (α × β))
    (values : List α → List β) (generator : List α) :
    integerWordRigidFactorChoice rigid values generator ∈
      integerWordRigidChoices (rigid.map Prod.snd) generator := by
  cases contents : values generator with
  | nil => simp [integerWordRigidFactorChoice, contents, integerWordRigidChoices]
  | cons first rest =>
    cases found : rigid.find? (fun binding => decide (binding.1 ∈ generator)) with
    | none => simp [integerWordRigidFactorChoice, contents, found, integerWordRigidChoices]
    | some binding =>
      have member := List.mem_of_find?_eq_some found
      simp only [integerWordRigidFactorChoice, contents, found]
      apply List.mem_cons_of_mem
      apply List.mem_cons_of_mem
      exact List.mem_map.mpr ⟨binding.2, List.mem_map.mpr ⟨binding, member, rfl⟩, rfl⟩

theorem integer_word_rigid_postfactor_nonempty (defaultAtom : β) (values : List α → List β) :
    ∀ name, integerWordRigidPostfactor defaultAtom values name ≠ [] := by
  intro name
  cases name with
  | inl atom => simp [integerWordRigidPostfactor]
  | inr generator =>
    cases contents : values generator <;> simp [integerWordRigidPostfactor, contents]

theorem integer_word_rigid_choice_instantiation [DecidableEq α] (rigid : List (α × β))
    (values : List α → List β) (generator : List α) (defaultAtom : β)
    (components : ∀ binding ∈ rigid, binding.1 ∈ generator →
      values generator ≠ [] → values generator = [binding.2]) :
    (integerWordRigidFactorChoice rigid values generator).flatMap
      (integerWordRigidPostfactor defaultAtom values) = values generator := by
  cases contents : values generator with
  | nil => simp [integerWordRigidFactorChoice, contents]
  | cons first rest =>
    cases found : rigid.find? (fun binding => decide (binding.1 ∈ generator)) with
    | none =>
      simp [integerWordRigidFactorChoice, contents, found, integerWordRigidPostfactor]
    | some binding =>
      have member := List.mem_of_find?_eq_some found
      have checked : decide (binding.1 ∈ generator) = true :=
        List.find?_some (p := fun entry : α × β => decide (entry.1 ∈ generator)) found
      have occurs : binding.1 ∈ generator := of_decide_eq_true checked
      have ground := components binding member occurs (by simp [contents])
      simpa [integerWordRigidFactorChoice, contents, found, integerWordRigidPostfactor] using
        ground.symm

theorem integer_word_rigid_choice_ground [DecidableEq α] (rigid : List (α × β))
    (values : List α → List β) (generator : List α)
    (marked : binding ∈ rigid) (occurs : binding.1 ∈ generator)
    (components : ∀ binding ∈ rigid, binding.1 ∈ generator →
      values generator ≠ [] → values generator = [binding.2]) :
    integerWordRigidFactorChoice rigid values generator = (values generator).map Sum.inl := by
  cases contents : values generator with
  | nil => simp [integerWordRigidFactorChoice, contents]
  | cons first rest =>
    cases found : rigid.find? (fun binding => decide (binding.1 ∈ generator)) with
    | none =>
      have absent := List.find?_eq_none.mp found binding marked
      exact (absent (by simpa using occurs)).elim
    | some selected =>
      have member := List.mem_of_find?_eq_some found
      have checked : decide (selected.1 ∈ generator) = true :=
        List.find?_some (p := fun entry : α × β => decide (entry.1 ∈ generator)) found
      have selectedOccurs : selected.1 ∈ generator := of_decide_eq_true checked
      have ground := components selected member selectedOccurs (by simp [contents])
      simp only [integerWordRigidFactorChoice, contents, found]
      rw [← contents, ground]
      rfl

#print axioms integer_word_rigid_choice_allowed
#print axioms integer_word_rigid_postfactor_nonempty
#print axioms integer_word_rigid_choice_instantiation
#print axioms integer_word_rigid_choice_ground

end Cairn.Equations
