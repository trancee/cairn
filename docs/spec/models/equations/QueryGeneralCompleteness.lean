import QueryRawRealization
import QueryRawSoundness
import QueryPlanCongruence
import QueryFreshGeneration

namespace Cairn.Equations

theorem native_raw_ac_system_family_complete (equations : NativeEquationSystem) :
    NativeRawCompleteACSystemOn equations (nativeSystemVariables equations)
      (nativeRawACSystemBindingFamily equations) := by
  refine ⟨fun _ member => native_raw_ac_system_family_sound equations member, ?_⟩
  intro solution solved
  let source := nativeSystemSubterms equations
  let desired := nativeSolutionLabel source solution
  let word := source.map desired
  let label := nativeRawLabel source word
  have agreement : ∀ term ∈ source, desired term = label term :=
    fun term member => (native_raw_label_map source desired member).symm
  have consistent := native_raw_plan_consistent_congr agreement (native_solution_plan_consistent solved)
  obtain ⟨auxiliary, included, residuals, realizes⟩ := native_solution_auxiliary_factor equations solution
  obtain ⟨bindings, rendered, factored⟩ :=
    native_solution_raw_bindings equations solution auxiliary included residuals realizes
  have auxiliaryMember : auxiliary ∈ nativeNaturalSystemBindingFamily
      (nativeRawNaturalSystem equations label) := by
    rw [← native_raw_natural_system_congr agreement]
    exact included
  have bindingResult : nativeRawRenderBindings equations label auxiliary = some bindings := by
    rw [← native_raw_render_bindings_congr agreement auxiliary]
    exact rendered
  refine ⟨bindings, ?_, nativeRawResidualFactor residuals, factored⟩
  apply List.mem_flatMap.mpr
  refine ⟨word, native_solution_label_word source solution, ?_⟩
  dsimp only
  rw [ite_eq_left consistent]
  exact List.mem_filterMap.mpr ⟨auxiliary, auxiliaryMember, bindingResult⟩

theorem native_sorted_ac_system_family_complete (equations : NativeEquationSystem) :
    NativeCompleteACSystemOn equations (nativeSystemVariables equations)
      ((nativeSortedACSystemBindingFamily equations).map nativeBindingAssignment) :=
  native_sorted_binding_family_complete equations (nativeSystemVariables equations)
    (fun _ member => member) (native_raw_ac_system_family_complete equations)

theorem native_sorted_ac_system_family_sound (equations : NativeEquationSystem)
    (member : bindings ∈ nativeSortedACSystemBindingFamily equations) :
    NativeACSystemUnifier equations (nativeBindingAssignment bindings) :=
  (native_sorted_ac_system_family_complete equations).1 _
    (List.mem_map.mpr ⟨bindings, member, rfl⟩)

theorem native_sorted_ac_system_family_fresh
    (member : bindings ∈ nativeSortedACSystemBindingFamily equations) (included : binding ∈ bindings)
    (occurs : residual ∈ nativeQueryVariables binding.2) :
    residual.2 ∉ (nativeSystemVariables equations).map Prod.snd :=
  native_sorted_binding_family_fresh member included occurs

#print axioms native_raw_ac_system_family_complete
#print axioms native_sorted_ac_system_family_complete
#print axioms native_sorted_ac_system_family_sound
#print axioms native_sorted_ac_system_family_fresh

end Cairn.Equations
