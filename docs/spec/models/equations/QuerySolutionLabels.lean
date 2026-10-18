import QueryRawPlans
import QueryResidualRetyping

namespace Cairn.Equations

def nativeSolutionClasses (source : List NativeQueryTerm)
    (solution : QuerySort → Nat → NativeQueryTerm) : List NativeACClass :=
  source.map (fun term => nativeACClassOf (substituteNativeQuery solution term))

noncomputable def nativeSolutionLabel (source : List NativeQueryTerm)
    (solution : QuerySort → Nat → NativeQueryTerm) (term : NativeQueryTerm) : Nat := by
  classical
  exact (nativeSolutionClasses source solution).idxOf
    (nativeACClassOf (substituteNativeQuery solution term))

def nativeSolutionSourceValue (source : List NativeQueryTerm)
    (solution : QuerySort → Nat → NativeQueryTerm) (index : Nat) : NativeQueryTerm :=
  substituteNativeQuery solution (source[index]?.getD .naturalOne)

theorem native_solution_label_bound (member : term ∈ source) :
    nativeSolutionLabel source solution term < source.length := by
  classical
  have included : nativeACClassOf (substituteNativeQuery solution term) ∈
      nativeSolutionClasses source solution := List.mem_map.mpr ⟨term, member, rfl⟩
  have bound := List.idxOf_lt_length_of_mem included
  simpa only [nativeSolutionLabel, nativeSolutionClasses, List.length_map] using bound

theorem native_solution_label_ac
    (related : NativeQueryAC (substituteNativeQuery solution first)
      (substituteNativeQuery solution second)) :
    nativeSolutionLabel source solution first = nativeSolutionLabel source solution second := by
  classical
  unfold nativeSolutionLabel
  rw [native_ac_class_eq_iff.mpr related]

theorem native_solution_label_reflection (firstMember : first ∈ source) (secondMember : second ∈ source)
    (same : nativeSolutionLabel source solution first = nativeSolutionLabel source solution second) :
    NativeQueryAC (substituteNativeQuery solution first) (substituteNativeQuery solution second) := by
  classical
  apply native_ac_class_eq_iff.mp
  apply natural_residual_index_injective [] (nativeSolutionClasses source solution)
    (List.mem_map.mpr ⟨first, firstMember, rfl⟩)
    (List.mem_map.mpr ⟨second, secondMember, rfl⟩)
  simpa only [naturalResidualIndex, naturalFreshBase, Nat.zero_add, nativeSolutionLabel] using same

theorem native_solution_source_value (member : term ∈ source) :
    NativeQueryAC
      (nativeSolutionSourceValue source solution (nativeSolutionLabel source solution term))
      (substituteNativeQuery solution term) := by
  classical
  have included : nativeACClassOf (substituteNativeQuery solution term) ∈
      nativeSolutionClasses source solution := List.mem_map.mpr ⟨term, member, rfl⟩
  have read := List.getElem_idxOf (List.idxOf_lt_length_of_mem included)
  have bound := native_solution_label_bound (solution := solution) member
  apply native_ac_class_eq_iff.mp
  unfold nativeSolutionSourceValue
  rw [List.getElem?_eq_getElem bound]
  change nativeACClassOf (substituteNativeQuery solution source[nativeSolutionLabel source solution term]) =
    nativeACClassOf (substituteNativeQuery solution term)
  simpa only [nativeSolutionLabel, nativeSolutionClasses, List.getElem_map] using read

theorem native_solution_label_word (source : List NativeQueryTerm)
    (solution : QuerySort → Nat → NativeQueryTerm) :
    source.map (nativeSolutionLabel source solution) ∈ nativeRawLabelWords source.length := by
  apply (native_raw_label_words_iff _ _).mpr
  refine ⟨List.length_map _, ?_⟩
  intro index member
  obtain ⟨term, included, rfl⟩ := List.mem_map.mp member
  exact native_solution_label_bound included

theorem native_rigid_substitution_head
    (rigid : nativeRawRigidNode term = true) :
    nativeQueryHead (substituteNativeQuery solution term) = nativeQueryHead term := by
  cases term <;> simp_all [nativeRawRigidNode, substituteNativeQuery, nativeQueryHead]

theorem native_rigid_substitution_children
    (rigid : nativeRawRigidNode term = true) :
    nativeFreeChildren (substituteNativeQuery solution term) =
      (nativeQueryChildren term).map (substituteNativeQuery solution) := by
  cases term <;> simp_all [nativeRawRigidNode, substituteNativeQuery,
    nativeFreeChildren, nativeQueryChildren]

theorem native_children_ac_map_eq (related : NativeChildrenAC first second)
    (respects : ∀ left right, NativeQueryAC left right → mapping left = mapping right) :
    first.map mapping = second.map mapping := by
  induction first generalizing second with
  | nil => cases second <;> simp_all [NativeChildrenAC]
  | cons item rest induction =>
    cases second with
    | nil => exact related.elim
    | cons next remaining =>
      simp only [List.map, respects item next related.1, induction related.2]

theorem native_solution_plan_consistent (solved : NativeRawACSystemUnifier equations solution) :
    NativeRawPlanConsistent equations (nativeSolutionLabel (nativeSystemSubterms equations) solution) := by
  classical
  constructor
  · intro equation member
    exact native_solution_label_ac (solved equation member)
  · intro first firstMember second secondMember firstRigid secondRigid same
    have related := native_solution_label_reflection firstMember secondMember same
    refine ⟨(native_rigid_substitution_head firstRigid).symm.trans
      ((native_query_ac_head related).trans (native_rigid_substitution_head secondRigid)), ?_⟩
    have children := native_query_ac_free_children related
    rw [native_rigid_substitution_children firstRigid,
      native_rigid_substitution_children secondRigid] at children
    have mapped := native_children_ac_map_eq children
      (mapping := fun term => (nativeSolutionClasses (nativeSystemSubterms equations) solution).idxOf
        (nativeACClassOf term))
      (fun _ _ equivalent => congrArg
        (List.idxOf · (nativeSolutionClasses (nativeSystemSubterms equations) solution))
        (native_ac_class_eq_iff.mpr equivalent))
    unfold nativeSolutionLabel
    simpa only [List.map_map, Function.comp_def] using mapped

#print axioms native_solution_label_bound
#print axioms native_solution_label_ac
#print axioms native_solution_label_reflection
#print axioms native_solution_source_value
#print axioms native_solution_label_word
#print axioms native_rigid_substitution_head
#print axioms native_rigid_substitution_children
#print axioms native_children_ac_map_eq
#print axioms native_solution_plan_consistent

end Cairn.Equations
