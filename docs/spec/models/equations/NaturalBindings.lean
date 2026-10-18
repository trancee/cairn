import NaturalSystemFamily

namespace Cairn.Equations

def naturalOnlySubstitution (values : Nat → NaturalTerm) : QuerySubstitution := {
  publicAtoms := fun index => 2 * index
  freshAtoms := fun index => 2 * index
  messages := fun index => .atom .messageAtom (2 * index)
  naturals := values
  nodes := fun index => 2 * index
}

theorem natural_bindings_encode (indices : List Nat) (basis : List (List NaturalColumn))
    (candidate : NaturalColumn → List (Sum Nat (List NaturalColumn))) (values : Nat → NaturalTerm)
    (decodes : ∀ index ∈ indices,
      naturalTermFromAtomCodes
        ((candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis)) =
          some (values index)) :
    naturalSystemCandidateBindings indices basis candidate =
      some (indices.map (fun index => ((QuerySort.natural, index),
        encodeNativeNatural (values index)))) := by
  have build (remaining : List Nat)
      (valid : ∀ index ∈ remaining,
        naturalTermFromAtomCodes
          ((candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis)) =
            some (values index)) :
      remaining.mapM (fun index =>
        (naturalTermFromAtomCodes
          ((candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis))).map
          (fun term => ((QuerySort.natural, index), encodeNativeNatural term))) =
        some (remaining.map (fun index =>
          ((QuerySort.natural, index), encodeNativeNatural (values index)))) := by
    induction remaining with
    | nil => rfl
    | cons index rest induction =>
      have first := valid index (by simp)
      have tail := induction (fun entry member => valid entry (List.mem_cons_of_mem _ member))
      simp [List.mapM_cons, first, tail]
  exact build indices decodes

theorem natural_bindings_realization (indices : List Nat) (basis : List (List NaturalColumn))
    (candidate : NaturalColumn → List (Sum Nat (List NaturalColumn)))
    (nonempty : ∀ index ∈ indices, candidate (.queryVariable index) ≠ []) :
    ∃ typed : QuerySubstitution, ∃ bindings,
      naturalSystemCandidateBindings indices basis candidate = some bindings ∧
      nativeBindingAssignment bindings =
        restrictNativeAssignment (indices.map (fun index => (QuerySort.natural, index)))
          (nativeQueryAssignment typed) ∧
      ∀ index ∈ indices, naturalAtomCodes (typed.naturals index) =
        (candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis) := by
  classical
  have existsTerm (index : Nat) (member : index ∈ indices) :
      ∃ term, naturalTermFromAtomCodes
        ((candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis)) = some term :=
    natural_codes_decode_exists _ (by simpa using nonempty index member)
  let values (index : Nat) :=
    if member : index ∈ indices then Classical.choose (existsTerm index member)
    else NaturalTerm.variable (2 * index)
  let typed := naturalOnlySubstitution values
  have decodes (index : Nat) (member : index ∈ indices) :
      naturalTermFromAtomCodes
        ((candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis)) =
          some (values index) := by
    simp only [values, dite_eq_left member]
    exact Classical.choose_spec (existsTerm index member)
  refine ⟨typed, indices.map (fun index =>
    ((QuerySort.natural, index), encodeNativeNatural (values index))),
    natural_bindings_encode indices basis candidate values decodes, ?_, ?_⟩
  · have same : indices.map (fun index =>
        ((QuerySort.natural, index), encodeNativeNatural (values index))) =
        (indices.map (fun index => (QuerySort.natural, index))).map (fun key =>
          (key, nativeQueryAssignment typed key.1 key.2)) := by
      simp [List.map_map, typed, naturalOnlySubstitution, nativeQueryAssignment]
    rw [same, native_bindings_restriction]
  · intro index member
    exact natural_codes_decode_exact _ (decodes index member)

#print axioms natural_bindings_encode
#print axioms natural_bindings_realization

end Cairn.Equations
