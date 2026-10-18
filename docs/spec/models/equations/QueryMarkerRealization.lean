import QueryMarkerRendering
import QuerySourceRealization

namespace Cairn.Equations

-- Totalization is used only with hypotheses witnessing successful rendering.
def nativeRawMarkerValue (source : List NativeQueryTerm) (label : NativeQueryTerm → Nat)
    (assignment : QuerySort → Nat → NativeQueryTerm) (available : List Nat)
    (marker : Nat) : NativeQueryTerm :=
  (nativeRawRenderMarker source label assignment available marker).getD .naturalOne

def nativeRawClassValue (source : List NativeQueryTerm) (label : NativeQueryTerm → Nat)
    (assignment : QuerySort → Nat → NativeQueryTerm) (available : List Nat)
    (index : Nat) : NativeQueryTerm :=
  nativeNaturalInterpret (nativeRawMarkerValue source label assignment available)
    (fun residual => .queryVariable .message residual) (assignment .natural index)

theorem native_raw_partial_marker_value
    (defined : ∀ marker ∈ available,
      ∃ value, nativeRawRenderMarker source label assignment available marker = some value)
    (subset : ∀ marker ∈ smaller, marker ∈ available)
    (rendered : nativeRawRenderMarker source label assignment smaller marker = some value) :
    nativeRawMarkerValue source label assignment available marker = value := by
  obtain ⟨whole, wholeRendered⟩ :=
    defined marker (subset marker (native_raw_marker_render_member rendered))
  unfold nativeRawMarkerValue
  rw [wholeRendered]
  exact native_raw_marker_render_unique source label assignment available smaller
    marker whole value wholeRendered rendered

theorem native_raw_render_class_value
    (rendered : nativeRenderNatural (nativeRawRenderMarker source label assignment available)
      (assignment .natural index) = some value) :
    nativeRawClassValue source label assignment available index = value := by
  exact native_render_natural_interpretation
    (fun marker whole present => by simp [nativeRawMarkerValue, present]) rendered

theorem native_raw_marker_shape
    (defined : ∀ marker ∈ available,
      ∃ value, nativeRawRenderMarker source label assignment available marker = some value)
    (rendered : nativeRawRenderMarker source label assignment available marker = some value) :
    ∃ term, nativeRawRepresentative source label marker = some term ∧
      value = nativeRebuildQueryNode
        (fun child => nativeRawClassValue source label assignment available (label child)) term := by
  rw [nativeRawRenderMarker] at rendered
  split at rendered
  next =>
    cases selected : nativeRawRepresentative source label marker with
    | none => simp [selected] at rendered
    | some term =>
      cases children : (nativeQueryChildren term).mapM (fun child =>
          nativeRenderNatural
            (nativeRawRenderMarker source label assignment
              (available.filter (fun index => index != marker)))
            (assignment .natural (label child))) with
      | none => simp [selected, children] at rendered
      | some values =>
        have exactChildren : (nativeQueryChildren term).mapM (fun child =>
            nativeRenderNatural
              (nativeRawRenderMarker source label assignment
                (available.filter (fun index => index != marker)))
              (assignment .natural (label child))) =
            some ((nativeQueryChildren term).map
              (fun child => nativeRawClassValue source label assignment available (label child))) := by
          apply native_mapM_exact
          intro child member
          obtain ⟨whole, _, childRendered⟩ := native_mapM_member children member
          have realized := native_render_natural_interpretation
            (fun index next present => native_raw_partial_marker_value defined
              (fun position occurs => (List.mem_filter.mp occurs).1) present) childRendered
          change nativeRenderNatural _ _ = some (nativeNaturalInterpret _ _ _)
          rw [realized]
          exact childRendered
        have same := Option.some.inj (children.symm.trans exactChildren)
        subst values
        have built : nativeBuildQueryHead (nativeQueryHead term)
            ((nativeQueryChildren term).map
              (fun child => nativeRawClassValue source label assignment available (label child))) =
            some value := by
          simpa [selected, children] using rendered
        rw [native_build_query_node] at built
        exact ⟨term, rfl, (Option.some.inj built).symm⟩
  next => simp at rendered

#print axioms native_raw_partial_marker_value
#print axioms native_raw_render_class_value
#print axioms native_raw_marker_shape

end Cairn.Equations
