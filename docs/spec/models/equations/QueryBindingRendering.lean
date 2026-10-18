import QueryRawGeneration

namespace Cairn.Equations

theorem native_binding_mapM_lookup (scope : List NativeVariableKey)
    (values : NativeVariableKey → Option NativeQueryTerm)
    (rendered : scope.mapM (fun key => do
      let value ← values key
      return (key, value)) = some bindings)
    (member : key ∈ scope) :
    values key = some (nativeBindingAssignment bindings key.1 key.2) := by
  induction scope generalizing bindings with
  | nil => simp at member
  | cons first rest induction =>
    cases head : values first with
    | none =>
      simp only [List.mapM_cons, head] at rendered
      change (none : Option (List (NativeVariableKey × NativeQueryTerm))) = some bindings at rendered
      cases rendered
    | some value =>
      cases tail : rest.mapM (fun key => do
          let value ← values key
          return (key, value)) with
      | none =>
        simp only [List.mapM_cons, head, tail] at rendered
        change (none : Option (List (NativeVariableKey × NativeQueryTerm))) = some bindings at rendered
        cases rendered
      | some remaining =>
        simp only [List.mapM_cons, head, tail] at rendered
        change some ((first, value) :: remaining) = some bindings at rendered
        have same : (first, value) :: remaining = bindings := by
          exact Option.some.inj rendered
        subst bindings
        by_cases equal : first = key
        · subst first
          simpa only [nativeBindingAssignment, ite_true] using head
        · have restMember : key ∈ rest := (List.mem_cons.mp member).resolve_left (Ne.symm equal)
          simpa only [nativeBindingAssignment, ite_eq_right equal] using induction tail restMember

#print axioms native_binding_mapM_lookup

end Cairn.Equations
