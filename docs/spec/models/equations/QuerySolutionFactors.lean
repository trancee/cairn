import QuerySolutionModels
import QueryNaturalScope

namespace Cairn.Equations

def NativeSolutionClassRealization (source : List NativeQueryTerm)
    (solution assignment : QuerySort → Nat → NativeQueryTerm)
    (residuals : Nat → NativeQueryTerm) : Prop :=
  ∀ index, index < source.length →
    NativeQueryAC
      (nativeNaturalInterpret (nativeClassDecoder (nativeSolutionAtomTable source solution))
        residuals (assignment .natural index))
      (nativeSolutionSourceValue source solution index)

theorem native_solution_auxiliary_factor (equations : NativeEquationSystem)
    (solution : QuerySort → Nat → NativeQueryTerm) :
    ∃ bindings ∈ nativeNaturalSystemBindingFamily
        (nativeRawNaturalSystem equations (nativeSolutionLabel (nativeSystemSubterms equations) solution)),
      ∃ residuals : Nat → NativeQueryTerm,
        NativeSolutionClassRealization (nativeSystemSubterms equations) solution
          (nativeBindingAssignment bindings) residuals := by
  let source := nativeSystemSubterms equations
  let label := nativeSolutionLabel source solution
  let auxiliary := nativeRawNaturalSystem equations label
  let model := nativeSolutionNaturalAssignment source solution
  let rigid := nativeClassDecoder (nativeSolutionAtomTable source solution)
  obtain ⟨candidate, member, factor, _, factored⟩ :=
    (native_natural_system_family_complete auxiliary).2 (nativeQueryAssignment model)
      (native_solution_natural_model equations solution)
  obtain ⟨bindings, included, rfl⟩ := List.mem_map.mp member
  let residuals := fun index =>
    nativeNaturalInterpret rigid (fun _ => .naturalOne) (factor .natural index)
  refine ⟨bindings, included, residuals, ?_⟩
  intro index bounded
  have scope := native_raw_class_scope (label := label) bounded
  have factorization := factored .natural index scope
  change NativeQueryAC (encodeNativeNatural (model.naturals index))
    (substituteNativeQuery factor (nativeBindingAssignment bindings .natural index)) at factorization
  have transported := native_natural_interpret_ac rigid (fun _ => .naturalOne) factorization
  have sorted := (native_natural_system_family_sound auxiliary included).1 .natural index
  rw [native_natural_interpret_substitution rigid (fun _ => .naturalOne) factor sorted] at transported
  exact .transitive (.symmetric transported)
    (native_atom_model_interpretation _ _ (fun _ member =>
      native_solution_source_covered bounded member) (fun _ => .naturalOne))

def nativeRawResidualFactor (residuals : Nat → NativeQueryTerm) :
    QuerySort → Nat → NativeQueryTerm
  | .message, index => residuals index
  | .publicAtom, index => .queryVariable .publicAtom index
  | .freshAtom, index => .queryVariable .freshAtom index
  | .natural, index => .queryVariable .natural index
  | .node, index => .queryVariable .node index

#print axioms native_solution_auxiliary_factor

end Cairn.Equations
