import QueryRawGeneration

namespace Cairn.Equations

theorem native_raw_child_labels_congr
    (agree : ∀ term ∈ nativeSystemSubterms equations, first term = second term)
    (member : parent ∈ nativeSystemSubterms equations) :
    (nativeQueryChildren parent).map first = (nativeQueryChildren parent).map second := by
  apply List.map_congr_left
  intro child occurs
  exact agree child (native_system_subterms_children member occurs)

theorem native_raw_natural_system_congr
    (agree : ∀ term ∈ nativeSystemSubterms equations, first term = second term) :
    nativeRawNaturalSystem equations first = nativeRawNaturalSystem equations second := by
  unfold nativeRawNaturalSystem
  congr 1
  apply native_filterMap_congr
  intro term member
  have own := agree term member
  have children : ∀ child ∈ nativeQueryChildren term, first child = second child :=
    fun _ occurs => agree _ (native_system_subterms_children member occurs)
  cases term <;> simp_all [nativeRawNodeEquation, nativeQueryChildren]

theorem native_raw_plan_consistent_congr
    (agree : ∀ term ∈ nativeSystemSubterms equations, first term = second term)
    (consistent : NativeRawPlanConsistent equations first) :
    NativeRawPlanConsistent equations second := by
  constructor
  · intro equation member
    have roots := native_system_subterms_roots member
    rw [← agree _ roots.1, ← agree _ roots.2]
    exact consistent.1 equation member
  · intro left leftMember right rightMember leftRigid rightRigid same
    rw [← agree _ leftMember, ← agree _ rightMember] at same
    have related := consistent.2 left leftMember right rightMember leftRigid rightRigid same
    refine ⟨related.1, ?_⟩
    rw [← native_raw_child_labels_congr agree leftMember,
      ← native_raw_child_labels_congr agree rightMember]
    exact related.2

theorem native_raw_markers_congr (source : List NativeQueryTerm)
    (agree : ∀ term ∈ source, first term = second term) :
    nativeRawMarkers source first = nativeRawMarkers source second := by
  unfold nativeRawMarkers
  congr 1
  apply List.map_congr_left
  intro term member
  exact agree term (List.mem_filter.mp member).1

theorem native_raw_representative_congr (source : List NativeQueryTerm)
    (agree : ∀ term ∈ source, first term = second term) (marker : Nat) :
    nativeRawRepresentative source first marker = nativeRawRepresentative source second marker := by
  apply native_find_congr
  intro term member
  rw [agree term member]

theorem native_raw_marker_congr (equations : NativeEquationSystem)
    (first second : NativeQueryTerm → Nat)
    (agree : ∀ term ∈ nativeSystemSubterms equations, first term = second term)
    (assignment : QuerySort → Nat → NativeQueryTerm) (available : List Nat) (marker : Nat) :
    nativeRawRenderMarker (nativeSystemSubterms equations) first assignment available marker =
      nativeRawRenderMarker (nativeSystemSubterms equations) second assignment available marker := by
  rw [nativeRawRenderMarker, nativeRawRenderMarker]
  split
  next =>
    rw [native_raw_representative_congr _ agree marker]
    cases selected : nativeRawRepresentative (nativeSystemSubterms equations) second marker with
    | none => rfl
    | some parent =>
      have parentMember := List.mem_of_find?_eq_some selected
      have renderEqual :
          nativeRawRenderMarker (nativeSystemSubterms equations) first assignment
              (available.filter (fun position => position != marker)) =
            nativeRawRenderMarker (nativeSystemSubterms equations) second assignment
              (available.filter (fun position => position != marker)) := by
        funext next
        exact native_raw_marker_congr equations first second agree assignment
          (available.filter (fun position => position != marker)) next
      have children :
          (nativeQueryChildren parent).mapM (fun child => nativeRenderNatural
            (nativeRawRenderMarker (nativeSystemSubterms equations) first assignment
              (available.filter (fun position => position != marker)))
            (assignment .natural (first child))) =
          (nativeQueryChildren parent).mapM (fun child => nativeRenderNatural
            (nativeRawRenderMarker (nativeSystemSubterms equations) second assignment
              (available.filter (fun position => position != marker)))
            (assignment .natural (second child))) := by
        apply native_mapM_congr
        intro child member
        rw [renderEqual, agree child (native_system_subterms_children parentMember member)]
      exact congrArg (fun results : Option (List NativeQueryTerm) =>
        results.bind (nativeBuildQueryHead (nativeQueryHead parent))) children
  next => rfl
termination_by available.length
decreasing_by simpa using native_marker_removal_shorter (by assumption)

theorem native_raw_render_bindings_congr
    (agree : ∀ term ∈ nativeSystemSubterms equations, first term = second term)
    (bindings : NativeBindingList) :
    nativeRawRenderBindings equations first bindings = nativeRawRenderBindings equations second bindings := by
  let source := nativeSystemSubterms equations
  let assignment := nativeBindingAssignment bindings
  let markers := nativeRawMarkers source second
  let render := nativeRawRenderMarker source second assignment markers
  have renderEqual : nativeRawRenderMarker source first assignment markers = render := by
    funext marker
    exact native_raw_marker_congr equations first second agree assignment markers marker
  have bindingEqual :
      (nativeSystemVariables equations).mapM (fun key => do
        let value ← nativeRenderNatural render (assignment .natural (first (.queryVariable key.1 key.2)))
        return (key, value)) =
      (nativeSystemVariables equations).mapM (fun key => do
        let value ← nativeRenderNatural render (assignment .natural (second (.queryVariable key.1 key.2)))
        return (key, value)) := by
    apply native_mapM_congr
    intro key member
    rw [agree _ (native_system_variable_subterm member)]
  unfold nativeRawRenderBindings
  dsimp only
  rw [native_raw_markers_congr _ agree, renderEqual, bindingEqual]

#print axioms native_raw_child_labels_congr
#print axioms native_raw_natural_system_congr
#print axioms native_raw_plan_consistent_congr
#print axioms native_raw_markers_congr
#print axioms native_raw_representative_congr
#print axioms native_raw_marker_congr
#print axioms native_raw_render_bindings_congr

end Cairn.Equations
