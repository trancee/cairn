import QueryRawGeneration
import QueryMarkerRealization

namespace Cairn.Equations

theorem native_raw_auxiliary_interpretation
    (solved : NativeACSystemUnifier (encodeNativeNaturalSystem equations) assignment)
    (member : equation ∈ equations) (rigid residuals : Nat → NativeQueryTerm) :
    NativeQueryAC
      (nativeNaturalInterpret rigid residuals
        (substituteNativeQuery assignment (encodeNativeNatural equation.1)))
      (nativeNaturalInterpret rigid residuals
        (substituteNativeQuery assignment (encodeNativeNatural equation.2))) :=
  native_natural_interpret_ac rigid residuals
    (solved.2 _ (List.mem_map.mpr ⟨equation, member, rfl⟩))

theorem native_raw_render_bindings_sound (equations : NativeEquationSystem)
    (label : NativeQueryTerm → Nat)
    (bounded : ∀ term ∈ nativeSystemSubterms equations,
      label term < (nativeSystemSubterms equations).length)
    (consistent : NativeRawPlanConsistent equations label)
    (solved : NativeACSystemUnifier (encodeNativeNaturalSystem (nativeRawNaturalSystem equations label))
      (nativeBindingAssignment auxiliary))
    (rendered : nativeRawRenderBindings equations label auxiliary = some bindings) :
    NativeRawACSystemUnifier equations (nativeBindingAssignment bindings) := by
  let source := nativeSystemSubterms equations
  let assignment := nativeBindingAssignment auxiliary
  let markers := nativeRawMarkers source label
  let render := nativeRawRenderMarker source label assignment markers
  let value := nativeRawClassValue source label assignment markers
  let rigidValue := nativeRawMarkerValue source label assignment markers
  change (do
    let _ ← markers.mapM render
    let _ ← (List.range source.length).mapM
      (fun index => nativeRenderNatural render (assignment .natural index))
    (nativeSystemVariables equations).mapM (fun key => do
      let whole ← nativeRenderNatural render (assignment .natural (label (.queryVariable key.1 key.2)))
      return (key, whole))) = some bindings at rendered
  cases markerResult : markers.mapM render with
  | none => simp [markerResult] at rendered
  | some markerValues =>
    cases classResult : (List.range source.length).mapM
        (fun index => nativeRenderNatural render (assignment .natural index)) with
    | none => simp [markerResult, classResult] at rendered
    | some classValues =>
      simp only [markerResult, classResult] at rendered
      have allMarkers (marker : Nat) (member : marker ∈ markers) :
          ∃ whole, render marker = some whole := by
        obtain ⟨whole, _, result⟩ := native_mapM_member markerResult member
        exact ⟨whole, result⟩
      have allClasses (index : Nat) (member : index < source.length) :
          ∃ whole, nativeRenderNatural render (assignment .natural index) = some whole := by
        obtain ⟨whole, _, result⟩ :=
          native_mapM_member classResult (List.mem_range.mpr member)
        exact ⟨whole, result⟩
      have bindingsEqual : bindings = (nativeSystemVariables equations).map
          (fun key => (key, value (label (.queryVariable key.1 key.2)))) := by
        apply Option.some.inj
        apply Eq.trans rendered.symm
        apply native_mapM_exact
        intro key member
        obtain ⟨whole, result⟩ := allClasses _ (bounded _ (native_system_variable_subterm member))
        have realized : value (label (.queryVariable key.1 key.2)) = whole :=
          native_raw_render_class_value result
        simp only [result]
        change some (key, whole) = some (key, value (label (.queryVariable key.1 key.2)))
        rw [realized]
      have variableValues (sort index) (member : (sort, index) ∈ nativeSystemVariables equations) :
          nativeBindingAssignment bindings sort index = value (label (.queryVariable sort index)) := by
        rw [bindingsEqual]
        have restriction := congrFun (congrFun
          (native_bindings_restriction (nativeSystemVariables equations)
            (fun sort index => value (label (.queryVariable sort index)))) sort) index
        exact restriction.trans (ite_eq_left member)
      have rigid (term : NativeQueryTerm) (member : term ∈ source)
          (fixed : nativeRawRigidNode term = true) :
          NativeQueryAC (value (label term))
            (nativeRebuildQueryNode (fun child => value (label child)) term) := by
        have present : label term ∈ markers :=
          List.mem_eraseDups.mpr (List.mem_map.mpr
            ⟨term, List.mem_filter.mpr ⟨member, fixed⟩, rfl⟩)
        obtain ⟨whole, result⟩ := allMarkers _ present
        obtain ⟨representative, selected, shape⟩ := native_raw_marker_shape allMarkers result
        have properties := native_raw_representative_label selected
        have agreement := consistent.2 term member representative
          (native_raw_representative_member selected) fixed properties.1 properties.2.symm
        have childAgreement :
            (nativeQueryChildren term).map (fun child => value (label child)) =
              (nativeQueryChildren representative).map (fun child => value (label child)) := by
          simpa only [List.map_map, Function.comp_def] using congrArg (List.map value) agreement.2
        have rebuilt := native_rebuild_query_node_equal term representative agreement.1 childAgreement
        have auxiliaryMember := native_raw_node_equation_member member
          (native_raw_rigid_equation (label := label) fixed)
        have interpreted := native_raw_auxiliary_interpretation solved auxiliaryMember rigidValue
          (fun index => .queryVariable .message index)
        have frozen : (2 * label term + 1) / 2 = label term := by omega
        have relation : NativeQueryAC (value (label term)) (rigidValue (label term)) := by
          simpa [value, nativeRawClassValue, encodeNativeNatural, substituteNativeQuery,
            nativeNaturalInterpret, frozen] using interpreted
        have markerValue : rigidValue (label term) = whole := by
          change (render (label term)).getD .naturalOne = whole
          rw [result]
          rfl
        rw [markerValue, shape, ← rebuilt] at relation
        exact relation
      have addition (left right : NativeQueryTerm) (member : .naturalAdd left right ∈ source) :
          NativeQueryAC (value (label (.naturalAdd left right)))
            (.naturalAdd (value (label left)) (value (label right))) := by
        have auxiliaryMember := native_raw_node_equation_member member
          (show nativeRawNodeEquation label (.naturalAdd left right) = some _ from rfl)
        have interpreted := native_raw_auxiliary_interpretation solved auxiliaryMember rigidValue
          (fun index => .queryVariable .message index)
        simpa [value, nativeRawClassValue, encodeNativeNatural, substituteNativeQuery,
          nativeNaturalInterpret] using interpreted
      have variables (sort index) (member : .queryVariable sort index ∈ source) :
          NativeQueryAC (nativeBindingAssignment bindings sort index)
            (value (label (.queryVariable sort index))) := by
        rw [variableValues sort index (native_system_variable_subterm_iff.mp member)]
        exact .reflexive
      intro equation member
      have roots := native_system_subterms_roots member
      have first := native_source_term_realization source (fun term => value (label term))
        (nativeBindingAssignment bindings)
        (fun _ occurs _ child => native_system_subterms_children occurs child)
        variables rigid addition roots.1
      have second := native_source_term_realization source (fun term => value (label term))
        (nativeBindingAssignment bindings)
        (fun _ occurs _ child => native_system_subterms_children occurs child)
        variables rigid addition roots.2
      rw [← consistent.1 equation member] at second
      exact .transitive first (.symmetric second)

theorem native_raw_ac_system_family_sound (equations : NativeEquationSystem)
    (member : bindings ∈ nativeRawACSystemBindingFamily equations) :
    NativeRawACSystemUnifier equations (nativeBindingAssignment bindings) := by
  obtain ⟨labels, included, generated⟩ := List.mem_flatMap.mp member
  dsimp only [nativeRawACSystemBindingFamily] at generated
  split at generated
  next consistent =>
    obtain ⟨auxiliary, auxiliaryMember, rendered⟩ := List.mem_filterMap.mp generated
    exact native_raw_render_bindings_sound equations _
      (fun _ occurs => native_raw_label_bound included occurs) consistent
      (native_natural_system_family_sound _ auxiliaryMember) rendered
  next => simp at generated

#print axioms native_raw_auxiliary_interpretation
#print axioms native_raw_render_bindings_sound
#print axioms native_raw_ac_system_family_sound

end Cairn.Equations
