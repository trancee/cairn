import QueryAtomModels

namespace Cairn.Equations

def nativeSolutionAtomTable (source : List NativeQueryTerm)
    (solution : QuerySort → Nat → NativeQueryTerm) : List NativeACClass :=
  nativeSolutionClasses source solution ++
    source.flatMap (fun term => nativeACAtomWord (substituteNativeQuery solution term))

noncomputable def nativeSolutionNaturalAssignment (source : List NativeQueryTerm)
    (solution : QuerySort → Nat → NativeQueryTerm) : QuerySubstitution where
  publicAtoms := fun index => 2 * index
  freshAtoms := fun index => 2 * index
  messages := fun index => .atom .messageAtom (2 * index)
  naturals := fun index => nativeAtomModelTerm (nativeSolutionAtomTable source solution)
    (nativeSolutionSourceValue source solution index)
  nodes := fun index => 2 * index

theorem native_solution_atom_covered (member : term ∈ source)
    (occurs : atom ∈ nativeACAtomWord (substituteNativeQuery solution term)) :
    atom ∈ nativeSolutionAtomTable source solution :=
  List.mem_append.mpr (.inr (List.mem_flatMap.mpr ⟨term, member, occurs⟩))

theorem native_solution_source_covered (bounded : index < source.length)
    (occurs : atom ∈ nativeACAtomWord (nativeSolutionSourceValue source solution index)) :
    atom ∈ nativeSolutionAtomTable source solution := by
  unfold nativeSolutionSourceValue at occurs
  rw [List.getElem?_eq_getElem bounded] at occurs
  exact native_solution_atom_covered (List.getElem_mem bounded) occurs

theorem native_solution_decoder (member : term ∈ source) :
    NativeQueryAC
      (nativeClassDecoder (nativeSolutionAtomTable source solution)
        (nativeSolutionLabel source solution term))
      (substituteNativeQuery solution term) := by
  classical
  have included : nativeACClassOf (substituteNativeQuery solution term) ∈
      nativeSolutionClasses source solution := List.mem_map.mpr ⟨term, member, rfl⟩
  have index :
      (nativeSolutionAtomTable source solution).idxOf
          (nativeACClassOf (substituteNativeQuery solution term)) =
        nativeSolutionLabel source solution term := by
    unfold nativeSolutionAtomTable
    rw [List.idxOf_append, ite_eq_left included]
    rfl
  have decoded := native_class_decoder (nativeSolutionAtomTable source solution)
    (List.mem_append.mpr (.inl included))
  rw [index] at decoded
  exact native_ac_class_eq_iff.mp decoded

theorem native_solution_model_class (member : term ∈ source) :
    NaturalAC
      ((nativeSolutionNaturalAssignment source solution).naturals (nativeSolutionLabel source solution term))
      (nativeAtomModelTerm (nativeSolutionAtomTable source solution) (substituteNativeQuery solution term)) :=
  native_atom_model_ac _ (native_solution_source_value member)

theorem native_solution_rigid_model (member : term ∈ source)
    (rigid : nativeRawRigidNode term = true) :
    NaturalAC
      ((nativeSolutionNaturalAssignment source solution).naturals (nativeSolutionLabel source solution term))
      (.variable (2 * nativeSolutionLabel source solution term + 1)) := by
  classical
  apply NaturalAC.transitive (native_solution_model_class member)
  apply natural_ac_atoms_iff.mpr
  rw [native_atom_model_codes]
  have singleton : nativeACAtomWord (substituteNativeQuery solution term) =
      [nativeACClassOf (substituteNativeQuery solution term)] := by
    cases term <;> simp_all [nativeRawRigidNode, substituteNativeQuery, nativeACAtomWord]
  have included : nativeACClassOf (substituteNativeQuery solution term) ∈
      nativeSolutionClasses source solution := List.mem_map.mpr ⟨term, member, rfl⟩
  unfold nativeAtomModelCodes nativeSolutionAtomTable
  rw [singleton, List.map_cons, List.map_nil, List.idxOf_append, ite_eq_left included]
  change [2 * nativeSolutionLabel source solution term + 2].Perm
    [2 * nativeSolutionLabel source solution term + 1 + 1]
  have arithmetic : 2 * nativeSolutionLabel source solution term + 1 + 1 =
      2 * nativeSolutionLabel source solution term + 2 := by omega
  rw [arithmetic]

theorem native_solution_add_model (member : NativeQueryTerm.naturalAdd left right ∈
    nativeSystemSubterms equations) :
    NaturalAC
      ((nativeSolutionNaturalAssignment (nativeSystemSubterms equations) solution).naturals
        (nativeSolutionLabel (nativeSystemSubterms equations) solution (.naturalAdd left right)))
      (.add
        ((nativeSolutionNaturalAssignment (nativeSystemSubterms equations) solution).naturals
          (nativeSolutionLabel (nativeSystemSubterms equations) solution left))
        ((nativeSolutionNaturalAssignment (nativeSystemSubterms equations) solution).naturals
          (nativeSolutionLabel (nativeSystemSubterms equations) solution right))) := by
  apply NaturalAC.transitive (native_solution_model_class member)
  apply NaturalAC.transitive (native_atom_model_add _ _ _)
  exact .transitive
    (.addLeft (.symmetric (native_solution_model_class
      (native_system_subterms_children member (by simp [nativeQueryChildren])))))
    (.addRight (.symmetric (native_solution_model_class
      (native_system_subterms_children member (by simp [nativeQueryChildren])))))

theorem native_solution_model_node (member : term ∈ nativeSystemSubterms equations)
    (compiled : nativeRawNodeEquation
      (nativeSolutionLabel (nativeSystemSubterms equations) solution) term = some equation) :
    NativeQueryAC
      (substituteNativeQuery
        (nativeQueryAssignment (nativeSolutionNaturalAssignment (nativeSystemSubterms equations) solution))
        (encodeNativeNatural equation.1))
      (substituteNativeQuery
        (nativeQueryAssignment (nativeSolutionNaturalAssignment (nativeSystemSubterms equations) solution))
        (encodeNativeNatural equation.2)) := by
  let source := nativeSystemSubterms equations
  let label := nativeSolutionLabel source solution
  let assignment := nativeSolutionNaturalAssignment source solution
  by_cases addition : ∃ left right, term = .naturalAdd left right
  · obtain ⟨left, right, rfl⟩ := addition
    have same := Option.some.inj compiled
    subst equation
    have related := native_natural_ac_preservation (native_solution_add_model (solution := solution) member)
    simpa [encodeNativeNatural, substituteNativeQuery, nativeQueryAssignment] using related
  · by_cases variableTerm : ∃ sort index, term = .queryVariable sort index
    · obtain ⟨sort, index, rfl⟩ := variableTerm
      simp [nativeRawNodeEquation] at compiled
    · have rigid : nativeRawRigidNode term = true := by
        cases term <;> simp_all [nativeRawRigidNode]
      rw [native_raw_rigid_equation rigid] at compiled
      have same := Option.some.inj compiled
      subst equation
      have related := native_natural_ac_preservation
        (native_solution_rigid_model (solution := solution) member rigid)
      have divided : (2 * label term + 1) / 2 = label term := by omega
      simpa [encodeNativeNatural, substituteNativeQuery, nativeQueryAssignment, divided] using related

theorem native_solution_natural_model (equations : NativeEquationSystem)
    (solution : QuerySort → Nat → NativeQueryTerm) :
    NativeACSystemUnifier
      (encodeNativeNaturalSystem
        (nativeRawNaturalSystem equations (nativeSolutionLabel (nativeSystemSubterms equations) solution)))
      (nativeQueryAssignment (nativeSolutionNaturalAssignment (nativeSystemSubterms equations) solution)) := by
  refine ⟨native_typed_assignment_sorted _, ?_⟩
  intro encoded member
  obtain ⟨equation, included, rfl⟩ := List.mem_map.mp member
  rcases List.mem_append.mp included with compiled | identity
  · obtain ⟨term, occurs, selected⟩ := List.mem_filterMap.mp compiled
    exact native_solution_model_node occurs selected
  · obtain ⟨index, _, rfl⟩ := List.mem_map.mp identity
    exact .reflexive

#print axioms native_solution_atom_covered
#print axioms native_solution_source_covered
#print axioms native_solution_decoder
#print axioms native_solution_model_class
#print axioms native_solution_rigid_model
#print axioms native_solution_add_model
#print axioms native_solution_model_node
#print axioms native_solution_natural_model

end Cairn.Equations
