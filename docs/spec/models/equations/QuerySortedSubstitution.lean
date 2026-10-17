import QuerySortedQuotient

namespace Cairn.Equations

inductive NativeSortedValue : QuerySort → NativeQueryTerm → Prop where
  | publicAtom : NativeSortedValue .publicAtom (.atom .publicAtom index)
  | publicVariable : NativeSortedValue .publicAtom (.queryVariable .publicAtom index)
  | freshAtom : NativeSortedValue .freshAtom (.atom .freshAtom index)
  | freshVariable : NativeSortedValue .freshAtom (.queryVariable .freshAtom index)
  | message : decodeNativeMessage term = some message → NativeSortedValue .message term
  | natural : decodeNativeNatural term = some natural → NativeSortedValue .natural term
  | nodeAtom : NativeSortedValue .node (.nodeAtom index)
  | nodeVariable : NativeSortedValue .node (.queryVariable .node index)

def NativeSortedAssignment (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∀ sort index, NativeSortedValue sort (assignment sort index)

theorem native_typed_assignment_sorted (assignment : QuerySubstitution) :
    NativeSortedAssignment (nativeQueryAssignment assignment) := by
  intro sort index
  cases sort with
  | publicAtom =>
    simp only [nativeQueryAssignment, encodeNativeMessage, atomQuerySort]
    split
    · exact .publicVariable
    · exact .publicAtom
  | freshAtom =>
    simp only [nativeQueryAssignment, encodeNativeMessage, atomQuerySort]
    split
    · exact .freshVariable
    · exact .freshAtom
  | message => exact .message (native_message_round_trip _)
  | natural => exact .natural (native_natural_round_trip _)
  | node =>
    simp only [nativeQueryAssignment]
    split
    · exact .nodeVariable
    · exact .nodeAtom

private theorem public_encoding (value : NativeSortedValue .publicAtom term) :
    ∃ label, encodeNativeMessage (.atom .publicAtom label) = term := by
  cases value with
  | publicAtom => exact ⟨_, native_message_recognition _ rfl⟩
  | publicVariable => exact ⟨_, native_message_recognition _ rfl⟩

private theorem fresh_encoding (value : NativeSortedValue .freshAtom term) :
    ∃ label, encodeNativeMessage (.atom .freshAtom label) = term := by
  cases value with
  | freshAtom => exact ⟨_, native_message_recognition _ rfl⟩
  | freshVariable => exact ⟨_, native_message_recognition _ rfl⟩

private theorem message_encoding (value : NativeSortedValue .message term) :
    ∃ message, encodeNativeMessage message = term := by
  cases value with
  | message decoded => exact ⟨_, native_message_recognition _ decoded⟩

private theorem natural_encoding (value : NativeSortedValue .natural term) :
    ∃ natural, encodeNativeNatural natural = term := by
  cases value with
  | natural decoded => exact ⟨_, native_natural_recognition _ decoded⟩

private theorem node_encoding (value : NativeSortedValue .node term) :
    ∃ label, (if label % 2 = 0 then NativeQueryTerm.queryVariable .node (label / 2)
      else .nodeAtom (label / 2)) = term := by
  cases value with
  | @nodeAtom index =>
    refine ⟨2 * index + 1, ?_⟩
    simp [show (2 * index + 1) / 2 = index by omega]
  | @nodeVariable index =>
    refine ⟨2 * index, ?_⟩
    simp

theorem native_sorted_assignment_representation (sorted : NativeSortedAssignment assignment) :
    ∃ typed : QuerySubstitution, nativeQueryAssignment typed = assignment := by
  classical
  refine ⟨{
    publicAtoms := fun index => Classical.choose (public_encoding (sorted .publicAtom index))
    freshAtoms := fun index => Classical.choose (fresh_encoding (sorted .freshAtom index))
    messages := fun index => Classical.choose (message_encoding (sorted .message index))
    naturals := fun index => Classical.choose (natural_encoding (sorted .natural index))
    nodes := fun index => Classical.choose (node_encoding (sorted .node index))
  }, ?_⟩
  funext sort index
  cases sort with
  | publicAtom => exact Classical.choose_spec (public_encoding (sorted .publicAtom index))
  | freshAtom => exact Classical.choose_spec (fresh_encoding (sorted .freshAtom index))
  | message => exact Classical.choose_spec (message_encoding (sorted .message index))
  | natural => exact Classical.choose_spec (natural_encoding (sorted .natural index))
  | node => exact Classical.choose_spec (node_encoding (sorted .node index))

theorem native_sorted_proper_substitution (sorted : NativeSortedAssignment assignment)
    (proper : NativeProperMessage term) :
    NativeProperMessage (substituteNativeQuery assignment term) := by
  obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation sorted
  obtain ⟨message, decoded⟩ := proper
  rw [← compatible, ← native_message_recognition term decoded]
  exact ⟨_, native_message_substitution_image typed message⟩

private theorem primitive_substitution (sorted : NativeSortedAssignment assignment)
    (step : NativeSortedPrimitiveRewrite left right) :
    NativeSortedPrimitiveRewrite (substituteNativeQuery assignment left)
      (substituteNativeQuery assignment right) := by
  cases step with
  | flipA => exact .flipA
  | flipB => exact .flipB
  | fst first second =>
    exact .fst (native_sorted_proper_substitution sorted first)
      (native_sorted_proper_substitution sorted second)
  | snd first second =>
    exact .snd (native_sorted_proper_substitution sorted first)
      (native_sorted_proper_substitution sorted second)
  | sdec payload key equivalent =>
    exact .sdec (native_sorted_proper_substitution sorted payload)
      (native_sorted_proper_substitution sorted key) (native_ac_substitution assignment equivalent)
  | kdec payload key equivalent =>
    exact .kdec (native_sorted_proper_substitution sorted payload)
      (native_sorted_proper_substitution sorted key) (native_ac_substitution assignment equivalent)

theorem native_sorted_rewrite_substitution (sorted : NativeSortedAssignment assignment)
    (step : NativeSortedRewrite left right) :
    NativeSortedRewrite (substituteNativeQuery assignment left)
      (substituteNativeQuery assignment right) := by
  induction step with
  | primitive root => exact .primitive (primitive_substitution sorted root)
  | unary _ induction => exact .unary induction
  | binaryLeft _ induction => exact .binaryLeft induction
  | binaryRight _ induction => exact .binaryRight induction
  | kdfFirst _ induction => exact .kdfFirst induction
  | kdfSecond _ induction => exact .kdfSecond induction
  | kdfThird _ induction => exact .kdfThird induction
  | naturalLeft _ induction => exact .naturalLeft induction
  | naturalRight _ induction => exact .naturalRight induction
  | list _ induction => exact .list induction
  | consLeft _ induction => exact .consLeft induction
  | consRight _ induction => exact .consRight induction

theorem native_sorted_steps_substitution (sorted : NativeSortedAssignment assignment)
    (steps : NativeSortedSteps left count right) :
    NativeSortedSteps (substituteNativeQuery assignment left) count
      (substituteNativeQuery assignment right) := by
  induction steps with
  | reflexive => exact .reflexive
  | step rewrite _ induction =>
    exact .step (native_sorted_rewrite_substitution sorted rewrite) induction

theorem native_sorted_modulo_ac_substitution (sorted : NativeSortedAssignment assignment)
    (step : NativeSortedModuloACRewrite left right) :
    NativeSortedModuloACRewrite (substituteNativeQuery assignment left)
      (substituteNativeQuery assignment right) := by
  obtain ⟨_, _, beforeAC, rewrite, afterAC⟩ := step
  exact ⟨_, _, native_ac_substitution assignment beforeAC,
    native_sorted_rewrite_substitution sorted rewrite, native_ac_substitution assignment afterAC⟩

theorem native_sorted_modulo_ac_steps_substitution (sorted : NativeSortedAssignment assignment)
    (steps : NativeSortedModuloACSteps left count right) :
    NativeSortedModuloACSteps (substituteNativeQuery assignment left) count
      (substituteNativeQuery assignment right) := by
  induction steps with
  | reflexive => exact .reflexive
  | step rewrite _ induction =>
    exact .step (native_sorted_modulo_ac_substitution sorted rewrite) induction

#print axioms native_typed_assignment_sorted
#print axioms native_sorted_assignment_representation
#print axioms native_sorted_proper_substitution
#print axioms native_sorted_rewrite_substitution
#print axioms native_sorted_steps_substitution
#print axioms native_sorted_modulo_ac_substitution
#print axioms native_sorted_modulo_ac_steps_substitution

end Cairn.Equations
