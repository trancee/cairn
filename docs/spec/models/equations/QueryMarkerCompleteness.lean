import QuerySolutionFactors
import QueryRenderingFactors

namespace Cairn.Equations

theorem native_solution_marker_dependency
    (realizes : NativeSolutionClassRealization (nativeSystemSubterms equations) solution assignment residuals)
    (parentMember : parent ∈ nativeSystemSubterms equations)
    (childMember : child ∈ nativeQueryChildren parent)
    (occurs : next ∈ nativeNaturalRigidIndices
      (assignment .natural (nativeSolutionLabel (nativeSystemSubterms equations) solution child))) :
    nativeQueryFunctionCount
        (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution) next) <
      nativeQueryFunctionCount
        (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution)
          (nativeSolutionLabel (nativeSystemSubterms equations) solution parent)) := by
  have sourceChild := native_system_subterms_children parentMember childMember
  have classValue := NativeQueryAC.transitive
    (realizes _ (native_solution_label_bound sourceChild))
    (native_solution_source_value sourceChild)
  have weight := native_natural_rigid_weight
    (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution))
    residuals occurs
  rw [native_query_ac_preserves_count classValue] at weight
  have parentWeight := native_query_ac_preserves_count
    (native_solution_decoder (solution := solution) parentMember)
  have decrease := native_source_child_substitution_count solution childMember
  omega

theorem native_solution_marker_complete (equations : NativeEquationSystem)
    (solution : QuerySort → Nat → NativeQueryTerm) (bindings : NativeBindingList)
    (included : bindings ∈ nativeNaturalSystemBindingFamily
      (nativeRawNaturalSystem equations (nativeSolutionLabel (nativeSystemSubterms equations) solution)))
    (residuals : Nat → NativeQueryTerm)
    (realizes : NativeSolutionClassRealization (nativeSystemSubterms equations) solution
      (nativeBindingAssignment bindings) residuals)
    (available : List Nat) (marker : Nat)
    (member : marker ∈ nativeRawMarkers (nativeSystemSubterms equations)
      (nativeSolutionLabel (nativeSystemSubterms equations) solution))
    (ready : ∀ next ∈ nativeRawMarkers (nativeSystemSubterms equations)
        (nativeSolutionLabel (nativeSystemSubterms equations) solution),
      nativeQueryFunctionCount
          (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution) next) ≤
        nativeQueryFunctionCount
          (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution) marker) →
      next ∈ available) :
    ∃ value, nativeRawRenderMarker (nativeSystemSubterms equations)
        (nativeSolutionLabel (nativeSystemSubterms equations) solution)
        (nativeBindingAssignment bindings) available marker = some value ∧
      NativeQueryAC
        (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution) marker)
        (substituteNativeQuery (nativeRawResidualFactor residuals) value) := by
  let source := nativeSystemSubterms equations
  let label := nativeSolutionLabel source solution
  let assignment := nativeBindingAssignment bindings
  let rigid := nativeClassDecoder (nativeSolutionAtomTable source solution)
  let factor := nativeRawResidualFactor residuals
  let smaller := available.filter (fun index => index != marker)
  let render := nativeRawRenderMarker source label assignment smaller
  change (∀ next ∈ nativeRawMarkers source label,
    nativeQueryFunctionCount (rigid next) ≤ nativeQueryFunctionCount (rigid marker) →
      next ∈ available) at ready
  have present := ready marker member (Nat.le_refl _)
  obtain ⟨parent, selected⟩ := native_raw_representative_exists member
  have parentMember := native_raw_representative_member selected
  have properties := native_raw_representative_label selected
  change nativeRawRigidNode parent = true ∧ label parent = marker at properties
  have parentValue := native_solution_decoder (solution := solution) parentMember
  change NativeQueryAC (rigid (label parent)) (substituteNativeQuery solution parent) at parentValue
  rw [properties.2] at parentValue
  have children (child : NativeQueryTerm) (childMember : child ∈ nativeQueryChildren parent) :
      ∃ value, nativeRenderNatural render (assignment .natural (label child)) = some value ∧
        NativeQueryAC (substituteNativeQuery factor value) (substituteNativeQuery solution child) := by
    have sourceChild := native_system_subterms_children parentMember childMember
    have dependencies (next : Nat)
        (occurs : next ∈ nativeNaturalRigidIndices (assignment .natural (label child))) :
        ∃ value, render next = some value ∧
          NativeQueryAC (rigid next) (substituteNativeQuery factor value) := by
      have supported := native_raw_candidate_marker_scope included
        (native_solution_label_bound sourceChild) occurs
      have lower := native_solution_marker_dependency realizes parentMember childMember occurs
      change nativeQueryFunctionCount (rigid next) < nativeQueryFunctionCount (rigid (label parent)) at lower
      rw [properties.2] at lower
      apply native_solution_marker_complete equations solution bindings included residuals realizes
        smaller next supported
      intro position positionMember bound
      change nativeQueryFunctionCount (rigid position) ≤ nativeQueryFunctionCount (rigid next) at bound
      have inOriginal := ready position positionMember (by omega)
      have distinct : position ≠ marker := by
        intro same
        subst position
        omega
      exact List.mem_filter.mpr ⟨inOriginal, by simpa using distinct⟩
    obtain ⟨value, result⟩ := native_render_natural_exists
      ((native_natural_system_family_sound _ included).1 .natural (label child))
      (fun next occurs => by
        obtain ⟨value, result, _⟩ := dependencies next occurs
        exact ⟨value, result⟩)
    have factored := native_render_natural_factor rigid residuals factor (fun _ => rfl)
      (fun next occurs whole rendered => by
        obtain ⟨other, otherResult, equivalent⟩ := dependencies next occurs
        have same := Option.some.inj (otherResult.symm.trans rendered)
        exact same ▸ equivalent) result
    exact ⟨value, result, .transitive (.symmetric factored)
      (.transitive (realizes _ (native_solution_label_bound sourceChild))
        (native_solution_source_value sourceChild))⟩
  let childValue := fun child =>
    (nativeRenderNatural render (assignment .natural (label child))).getD .naturalOne
  have childDefinitions : ∀ child ∈ nativeQueryChildren parent,
      nativeRenderNatural render (assignment .natural (label child)) = some (childValue child) := by
    intro child member
    obtain ⟨value, result, _⟩ := children child member
    simp [childValue, result]
  have childResults := native_mapM_exact (nativeQueryChildren parent)
    (fun child => nativeRenderNatural render (assignment .natural (label child))) childValue childDefinitions
  let value := nativeRebuildQueryNode childValue parent
  refine ⟨value, ?_, ?_⟩
  · change nativeRawRenderMarker source label assignment available marker = some value
    rw [nativeRawRenderMarker]
    split
    next =>
      rw [selected]
      change ((nativeQueryChildren parent).mapM
        (fun child => nativeRenderNatural render (assignment .natural (label child)))).bind
          (nativeBuildQueryHead (nativeQueryHead parent)) = some value
      rw [childResults]
      exact native_build_query_node childValue parent
    next absent => exact (absent present).elim
  · apply NativeQueryAC.transitive parentValue
    apply NativeQueryAC.symmetric
    change NativeQueryAC (substituteNativeQuery factor (nativeRebuildQueryNode childValue parent))
      (substituteNativeQuery solution parent)
    rw [native_rigid_rebuild_substitution properties.1,
      ← native_rigid_source_rebuild properties.1 solution]
    apply native_rebuild_query_node_ac
    intro child member
    obtain ⟨whole, result, equivalent⟩ := children child member
    have same : childValue child = whole := by simp [childValue, result]
    rw [same]
    exact equivalent
termination_by nativeQueryFunctionCount
  (nativeClassDecoder (nativeSolutionAtomTable (nativeSystemSubterms equations) solution) marker)
decreasing_by
  change nativeQueryFunctionCount (rigid next) < nativeQueryFunctionCount (rigid marker)
  simpa only [properties.2] using lower

#print axioms native_solution_marker_dependency
#print axioms native_solution_marker_complete

end Cairn.Equations
