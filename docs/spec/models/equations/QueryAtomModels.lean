import QuerySolutionLabels

namespace Cairn.Equations

noncomputable def nativeAtomModelCodes (table : List NativeACClass) (term : NativeQueryTerm) :
    List Nat := by
  classical
  exact (nativeACAtomWord term).map (fun atom => 2 * table.idxOf atom + 2)

theorem native_atom_model_codes_nonempty (table : List NativeACClass) (term : NativeQueryTerm) :
    nativeAtomModelCodes table term ≠ [] := by
  classical
  intro empty
  have absent : nativeACAtomWord term = [] := by
    cases word : nativeACAtomWord term with
    | nil => rfl
    | cons first rest => simp [nativeAtomModelCodes, word] at empty
  exact native_ac_atom_word_nonempty term absent

noncomputable def nativeAtomModelTerm (table : List NativeACClass) (term : NativeQueryTerm) :
    NaturalTerm :=
  Classical.choose (natural_codes_decode_exists (nativeAtomModelCodes table term)
    (native_atom_model_codes_nonempty table term))

theorem native_atom_model_codes (table : List NativeACClass) (term : NativeQueryTerm) :
    naturalAtomCodes (nativeAtomModelTerm table term) = nativeAtomModelCodes table term :=
  natural_codes_decode_exact _ (Classical.choose_spec
    (natural_codes_decode_exists (nativeAtomModelCodes table term)
      (native_atom_model_codes_nonempty table term)))

theorem native_atom_model_ac (table : List NativeACClass) (related : NativeQueryAC first second) :
    NaturalAC (nativeAtomModelTerm table first) (nativeAtomModelTerm table second) := by
  classical
  apply natural_ac_atoms_iff.mpr
  rw [native_atom_model_codes, native_atom_model_codes]
  exact (native_ac_atom_word_preservation related).map _

theorem native_atom_model_add (table : List NativeACClass) (first second : NativeQueryTerm) :
    NaturalAC (nativeAtomModelTerm table (.naturalAdd first second))
      (.add (nativeAtomModelTerm table first) (nativeAtomModelTerm table second)) := by
  classical
  apply natural_ac_atoms_iff.mpr
  simp only [naturalAtomCodes, native_atom_model_codes, nativeAtomModelCodes,
    nativeACAtomWord, List.map_append]
  exact .refl _

def nativeNaturalCodeClass (rigid variables : Nat → NativeQueryTerm) : Nat → NativeACClass
  | 0 => nativeACClassOf .naturalOne
  | label + 1 =>
    nativeACClassOf (nativeNaturalInterpret rigid variables (encodeNativeNatural (.variable label)))

theorem native_natural_code_word (rigid variables : Nat → NativeQueryTerm) (term : NaturalTerm) :
    nativeACWordValue ((naturalAtomCodes term).map (nativeNaturalCodeClass rigid variables)) =
      some (nativeACClassOf (nativeNaturalInterpret rigid variables (encodeNativeNatural term))) := by
  induction term with
  | one => rfl
  | «variable» label => rfl
  | add _ _ first second =>
    rw [naturalAtomCodes, List.map_append, native_ac_word_append, first, second]
    rfl

theorem native_natural_code_rigid (rigid variables : Nat → NativeQueryTerm) (index : Nat) :
    nativeNaturalCodeClass rigid variables (2 * index + 2) = nativeACClassOf (rigid index) := by
  change nativeACClassOf
    (nativeNaturalInterpret rigid variables (encodeNativeNatural (.variable (2 * index + 1)))) = _
  have divided : (2 * index + 1) / 2 = index := by omega
  simp [encodeNativeNatural, nativeNaturalInterpret, divided]

noncomputable def nativeClassDecoder (table : List NativeACClass) (index : Nat) : NativeQueryTerm :=
  Classical.choose (Quotient.exists_rep (table[index]?.getD (nativeACClassOf .naturalOne)))

theorem native_class_decoder [BEq NativeACClass] [LawfulBEq NativeACClass]
    (table : List NativeACClass) (member : atom ∈ table) :
    nativeACClassOf (nativeClassDecoder table (table.idxOf atom)) = atom := by
  classical
  have realized := Classical.choose_spec
    (Quotient.exists_rep (table[table.idxOf atom]?.getD (nativeACClassOf .naturalOne)))
  change nativeACClassOf (nativeClassDecoder table (table.idxOf atom)) =
    table[table.idxOf atom]?.getD (nativeACClassOf .naturalOne) at realized
  rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem member)] at realized
  simpa only [Option.getD_some, List.getElem_idxOf (List.idxOf_lt_length_of_mem member)] using realized

theorem native_atom_model_interpretation (table : List NativeACClass) (term : NativeQueryTerm)
    (covered : ∀ atom ∈ nativeACAtomWord term, atom ∈ table)
    (variables : Nat → NativeQueryTerm) :
    NativeQueryAC
      (nativeNaturalInterpret (nativeClassDecoder table) variables
        (encodeNativeNatural (nativeAtomModelTerm table term))) term := by
  classical
  have realized := native_natural_code_word (nativeClassDecoder table) variables
    (nativeAtomModelTerm table term)
  rw [native_atom_model_codes] at realized
  have mapped :
      (nativeAtomModelCodes table term).map (nativeNaturalCodeClass (nativeClassDecoder table) variables) =
        nativeACAtomWord term := by
    unfold nativeAtomModelCodes
    rw [List.map_map]
    calc
      _ = (nativeACAtomWord term).map id := by
        apply List.map_congr_left
        intro atom member
        exact (native_natural_code_rigid _ _ _).trans (native_class_decoder table (covered atom member))
      _ = _ := List.map_id' _
  rw [mapped, native_ac_atom_word_value] at realized
  exact native_ac_class_eq_iff.mp (Option.some.inj realized).symm

#print axioms native_atom_model_codes_nonempty
#print axioms native_atom_model_codes
#print axioms native_atom_model_ac
#print axioms native_atom_model_add
#print axioms native_natural_code_word
#print axioms native_natural_code_rigid
#print axioms native_class_decoder
#print axioms native_atom_model_interpretation

end Cairn.Equations
