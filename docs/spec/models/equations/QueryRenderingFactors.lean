import QueryMarkerRealization

namespace Cairn.Equations

theorem native_render_natural_factor (rigid residuals : Nat → NativeQueryTerm)
    (factor : QuerySort → Nat → NativeQueryTerm)
    (variables : ∀ index, factor .message index = residuals index)
    (markers : ∀ index ∈ nativeNaturalRigidIndices word, ∀ value, render index = some value →
      NativeQueryAC (rigid index) (substituteNativeQuery factor value))
    (rendered : nativeRenderNatural render word = some value) :
    NativeQueryAC (nativeNaturalInterpret rigid residuals word) (substituteNativeQuery factor value) := by
  induction word generalizing value with
  | naturalOne =>
    have same := Option.some.inj rendered
    subst value
    exact .reflexive
  | naturalAtom index => exact markers index (by simp [nativeNaturalRigidIndices]) value rendered
  | queryVariable sort index =>
    cases sort <;> simp only [nativeRenderNatural] at rendered
    all_goals first
      | contradiction
      | have same := Option.some.inj rendered
        subst value
        change NativeQueryAC (residuals index) (factor .message index)
        rw [variables]
        exact .reflexive
  | naturalAdd left right first second =>
    cases firstResult : nativeRenderNatural render left with
    | none => simp [nativeRenderNatural, firstResult] at rendered
    | some leftValue =>
      cases secondResult : nativeRenderNatural render right with
      | none => simp [nativeRenderNatural, firstResult, secondResult] at rendered
      | some rightValue =>
        have same : NativeQueryTerm.naturalAdd leftValue rightValue = value := by
          simpa [nativeRenderNatural, firstResult, secondResult] using rendered
        subst value
        exact .naturalAdd
          (first (fun index occurs => markers index (List.mem_append.mpr (.inl occurs))) firstResult)
          (second (fun index occurs => markers index (List.mem_append.mpr (.inr occurs))) secondResult)
  | atom | nodeAtom | roleA | roleB | unary | binary | kdf | list | cons | nil =>
    simp [nativeRenderNatural] at rendered

theorem native_rebuild_query_node_ac (term : NativeQueryTerm)
    (children : ∀ child ∈ nativeQueryChildren term, NativeQueryAC (first child) (second child)) :
    NativeQueryAC (nativeRebuildQueryNode first term) (nativeRebuildQueryNode second term) := by
  cases term with
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB | nil =>
    exact .reflexive
  | naturalAdd left right =>
    exact .naturalAdd (children left (by simp [nativeQueryChildren]))
      (children right (by simp [nativeQueryChildren]))
  | unary _ argument => exact .unary (children argument (by simp [nativeQueryChildren]))
  | binary _ left right =>
    exact .binary (children left (by simp [nativeQueryChildren]))
      (children right (by simp [nativeQueryChildren]))
  | kdf first second third =>
    exact .kdf (children first (by simp [nativeQueryChildren]))
      (children second (by simp [nativeQueryChildren]))
      (children third (by simp [nativeQueryChildren]))
  | list argument => exact .list (children argument (by simp [nativeQueryChildren]))
  | cons first second =>
    exact .cons (children first (by simp [nativeQueryChildren]))
      (children second (by simp [nativeQueryChildren]))

theorem native_rigid_rebuild_substitution (rigid : nativeRawRigidNode term = true)
    (values : NativeQueryTerm → NativeQueryTerm) (factor : QuerySort → Nat → NativeQueryTerm) :
    substituteNativeQuery factor (nativeRebuildQueryNode values term) =
      nativeRebuildQueryNode (fun child => substituteNativeQuery factor (values child)) term := by
  cases term <;> simp_all [nativeRawRigidNode, nativeRebuildQueryNode, substituteNativeQuery]

theorem native_rigid_source_rebuild (rigid : nativeRawRigidNode term = true)
    (solution : QuerySort → Nat → NativeQueryTerm) :
    nativeRebuildQueryNode (substituteNativeQuery solution) term =
      substituteNativeQuery solution term := by
  cases term <;> simp_all [nativeRawRigidNode, nativeRebuildQueryNode, substituteNativeQuery]

#print axioms native_render_natural_factor
#print axioms native_rebuild_query_node_ac
#print axioms native_rigid_rebuild_substitution
#print axioms native_rigid_source_rebuild

end Cairn.Equations
