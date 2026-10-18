import QueryRawPlans

namespace Cairn.Equations

theorem native_raw_marker_render_unique
    (source : List NativeQueryTerm) (label : NativeQueryTerm → Nat)
    (assignment : QuerySort → Nat → NativeQueryTerm) (available larger : List Nat)
    (marker : Nat) (left right : NativeQueryTerm)
    (leftRendered : nativeRawRenderMarker source label assignment available marker = some left)
    (rightRendered : nativeRawRenderMarker source label assignment larger marker = some right) :
    left = right := by
  rw [nativeRawRenderMarker] at leftRendered
  split at leftRendered
  next present =>
    rw [nativeRawRenderMarker] at rightRendered
    split at rightRendered
    next =>
      cases representative : nativeRawRepresentative source label marker with
      | none => simp [representative] at leftRendered
      | some term =>
        cases firstChildren : (nativeQueryChildren term).mapM (fun child =>
            nativeRenderNatural
              (nativeRawRenderMarker source label assignment
                (available.filter (fun index => index != marker)))
              (assignment .natural (label child))) with
        | none => simp [representative, firstChildren] at leftRendered
        | some leftValues =>
          cases secondChildren : (nativeQueryChildren term).mapM (fun child =>
              nativeRenderNatural
                (nativeRawRenderMarker source label assignment
                  (larger.filter (fun index => index != marker)))
                (assignment .natural (label child))) with
          | none => simp [representative, secondChildren] at rightRendered
          | some rightValues =>
            have same : leftValues = rightValues := by
              apply Option.some.inj
              apply Eq.trans _ secondChildren
              apply Eq.symm
              apply native_mapM_preserve _ _ _ _ firstChildren
              intro child member value rendered
              obtain ⟨other, _, otherRendered⟩ := native_mapM_member secondChildren member
              have equal := native_render_natural_unique
                (fun index first second firstResult secondResult =>
                  native_raw_marker_render_unique source label assignment
                    (available.filter (fun position => position != marker))
                    (larger.filter (fun position => position != marker))
                    index first second firstResult secondResult)
                rendered otherRendered
              exact equal ▸ otherRendered
            subst rightValues
            have firstResult : nativeBuildQueryHead (nativeQueryHead term) leftValues = some left := by
              simpa [representative, firstChildren] using leftRendered
            have secondResult : nativeBuildQueryHead (nativeQueryHead term) leftValues = some right := by
              simpa [representative, secondChildren] using rightRendered
            exact Option.some.inj (firstResult.symm.trans secondResult)
    next => simp at rightRendered
  next => simp at leftRendered
termination_by available.length
decreasing_by exact native_marker_removal_shorter (by assumption)

theorem native_raw_marker_render_member
    (rendered : nativeRawRenderMarker source label assignment available marker = some value) :
    marker ∈ available := by
  rw [nativeRawRenderMarker] at rendered
  split at rendered
  next present => exact present
  next => simp at rendered

theorem native_raw_representative_member
    (selected : nativeRawRepresentative source label marker = some term) : term ∈ source :=
  List.mem_of_find?_eq_some selected

theorem native_raw_representative_label
    (selected : nativeRawRepresentative source label marker = some term) :
    nativeRawRigidNode term = true ∧ label term = marker := by
  have accepts : (nativeRawRigidNode term && label term == marker) = true :=
    List.find?_some (p := fun node => nativeRawRigidNode node && label node == marker) selected
  simpa using accepts

theorem native_raw_representative_exists
    (member : marker ∈ nativeRawMarkers source label) :
    ∃ term, nativeRawRepresentative source label marker = some term := by
  obtain ⟨term, included, same⟩ := List.mem_map.mp (List.mem_eraseDups.mp member)
  obtain ⟨occurs, fixed⟩ := List.mem_filter.mp included
  have witness : ∃ term ∈ source, (nativeRawRigidNode term && label term == marker) = true :=
    ⟨term, occurs, by simp [fixed, same]⟩
  change ∃ term, source.find? (fun node => nativeRawRigidNode node && label node == marker) = some term
  clear member included occurs fixed same term
  induction source with
  | nil => simp at witness
  | cons first rest induction =>
    by_cases accepts : (nativeRawRigidNode first && label first == marker) = true
    · exact ⟨first, by simp [List.find?, accepts]⟩
    · obtain ⟨term, member, accepted⟩ := witness
      have inside : term ∈ rest := by
        rcases List.mem_cons.mp member with rfl | member
        · exact (accepts accepted).elim
        · exact member
      obtain ⟨result, selected⟩ := induction ⟨term, inside, accepted⟩
      exact ⟨result, by simpa [List.find?, accepts] using selected⟩

#print axioms native_raw_marker_render_unique
#print axioms native_raw_marker_render_member
#print axioms native_raw_representative_member
#print axioms native_raw_representative_label
#print axioms native_raw_representative_exists

end Cairn.Equations
