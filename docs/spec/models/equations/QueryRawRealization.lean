import QueryMarkerCompleteness
import QueryBindingRendering

namespace Cairn.Equations

theorem native_solution_raw_bindings (equations : NativeEquationSystem)
    (solution : QuerySort → Nat → NativeQueryTerm) (auxiliary : NativeBindingList)
    (included : auxiliary ∈ nativeNaturalSystemBindingFamily
      (nativeRawNaturalSystem equations (nativeSolutionLabel (nativeSystemSubterms equations) solution)))
    (residuals : Nat → NativeQueryTerm)
    (realizes : NativeSolutionClassRealization (nativeSystemSubterms equations) solution
      (nativeBindingAssignment auxiliary) residuals) :
    ∃ bindings, nativeRawRenderBindings equations
        (nativeSolutionLabel (nativeSystemSubterms equations) solution) auxiliary = some bindings ∧
      ∀ sort index, (sort, index) ∈ nativeSystemVariables equations →
        NativeQueryAC (solution sort index)
          (substituteNativeQuery (nativeRawResidualFactor residuals)
            (nativeBindingAssignment bindings sort index)) := by
  let source := nativeSystemSubterms equations
  let label := nativeSolutionLabel source solution
  let assignment := nativeBindingAssignment auxiliary
  let markers := nativeRawMarkers source label
  let render := nativeRawRenderMarker source label assignment markers
  let rigid := nativeClassDecoder (nativeSolutionAtomTable source solution)
  let factor := nativeRawResidualFactor residuals
  have allMarkers (marker : Nat) (member : marker ∈ markers) :
      ∃ value, render marker = some value ∧
        NativeQueryAC (rigid marker) (substituteNativeQuery factor value) :=
    native_solution_marker_complete equations solution auxiliary included residuals realizes markers marker member
      (fun _ occurs _ => occurs)
  have allClasses (index : Nat) (bounded : index < source.length) :
      ∃ value, nativeRenderNatural render (assignment .natural index) = some value := by
    apply native_render_natural_exists ((native_natural_system_family_sound _ included).1 .natural index)
    intro marker occurs
    obtain ⟨value, rendered, _⟩ :=
      allMarkers marker (native_raw_candidate_marker_scope included bounded occurs)
    exact ⟨value, rendered⟩
  obtain ⟨markerValues, markerResult⟩ := native_mapM_exists markers render
    (fun marker member => by
      obtain ⟨value, rendered, _⟩ := allMarkers marker member
      exact ⟨value, rendered⟩)
  obtain ⟨classValues, classResult⟩ := native_mapM_exists (List.range source.length)
    (fun index => nativeRenderNatural render (assignment .natural index))
    (fun index member => allClasses index (List.mem_range.mp member))
  obtain ⟨bindings, bindingResult⟩ := native_mapM_exists (nativeSystemVariables equations)
    (fun key => do
      let value ← nativeRenderNatural render (assignment .natural (label (.queryVariable key.1 key.2)))
      return (key, value)) (fun key member => by
        obtain ⟨value, result⟩ := allClasses (label (.queryVariable key.1 key.2))
          (native_solution_label_bound (solution := solution) (native_system_variable_subterm member))
        refine ⟨(key, value), ?_⟩
        simp only [result]
        rfl)
  refine ⟨bindings, ?_, ?_⟩
  · change (do
      let _ ← markers.mapM render
      let _ ← (List.range source.length).mapM
        (fun index => nativeRenderNatural render (assignment .natural index))
      (nativeSystemVariables equations).mapM (fun key => do
        let value ← nativeRenderNatural render (assignment .natural (label (.queryVariable key.1 key.2)))
        return (key, value))) = some bindings
    simp only [markerResult, classResult, bindingResult]
    rfl
  · intro sort index member
    have rendered := native_binding_mapM_lookup (nativeSystemVariables equations)
      (fun key => nativeRenderNatural render (assignment .natural (label (.queryVariable key.1 key.2))))
      bindingResult member
    have factored := native_render_natural_factor rigid residuals factor (fun _ => rfl)
      (fun marker _ value rendered => by
        obtain ⟨whole, wholeResult, equivalent⟩ :=
          allMarkers marker (native_raw_marker_render_member rendered)
        have same := Option.some.inj (wholeResult.symm.trans rendered)
        exact same ▸ equivalent) rendered
    have sourceVariable := native_system_variable_subterm member
    have classValue := NativeQueryAC.transitive
      (realizes _ (native_solution_label_bound sourceVariable))
      (native_solution_source_value sourceVariable)
    exact .transitive (.symmetric classValue) factored

#print axioms native_solution_raw_bindings

end Cairn.Equations
