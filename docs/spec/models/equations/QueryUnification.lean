import QueryComposition
import QueryKindSubstitution

namespace Cairn.Equations

-- Solutions of AC equality, not enumeration or equality modulo rewrite equations.
def NativeACUnifier (left right : NativeQueryTerm)
    (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  NativeSortedAssignment assignment ∧
    NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right)

theorem native_ac_unifier_composition (solution : NativeACUnifier left right first)
    (sorted : NativeSortedAssignment second) :
    NativeACUnifier left right (composeNativeAssignments first second) := by
  refine ⟨native_sorted_composition solution.1 sorted, ?_⟩
  rw [← native_substitution_composition, ← native_substitution_composition]
  exact native_ac_substitution second solution.2

theorem native_message_ac_unifier_iff (assignment : QuerySubstitution) (left right : MessageTerm) :
    NativeACUnifier (encodeNativeMessage left) (encodeNativeMessage right)
      (nativeQueryAssignment assignment) ↔
        MessageAC (substituteQueryMessage assignment left)
          (substituteQueryMessage assignment right) := by
  constructor
  · intro solution
    have equivalent := solution.2
    rw [← native_message_substitution, ← native_message_substitution] at equivalent
    exact native_message_ac_reflection equivalent
  · intro equivalent
    refine ⟨native_typed_assignment_sorted assignment, ?_⟩
    rw [← native_message_substitution, ← native_message_substitution]
    exact native_message_ac_preservation equivalent

theorem native_natural_ac_unifier_iff (assignment : QuerySubstitution) (left right : NaturalTerm) :
    NativeACUnifier (encodeNativeNatural left) (encodeNativeNatural right)
      (nativeQueryAssignment assignment) ↔
        NaturalAC (substituteQueryNatural assignment left)
          (substituteQueryNatural assignment right) := by
  constructor
  · intro solution
    have equivalent := solution.2
    rw [← native_natural_substitution, ← native_natural_substitution] at equivalent
    exact native_natural_ac_reflection equivalent
  · intro equivalent
    refine ⟨native_typed_assignment_sorted assignment, ?_⟩
    rw [← native_natural_substitution, ← native_natural_substitution]
    exact native_natural_ac_preservation equivalent

theorem native_message_ac_unifier_representation
    (solution : NativeACUnifier (encodeNativeMessage left) (encodeNativeMessage right) assignment) :
    ∃ typed : QuerySubstitution, nativeQueryAssignment typed = assignment ∧
      MessageAC (substituteQueryMessage typed left) (substituteQueryMessage typed right) := by
  obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation solution.1
  refine ⟨typed, compatible, (native_message_ac_unifier_iff typed left right).mp ?_⟩
  rw [compatible]
  exact solution

theorem native_natural_ac_unifier_representation
    (solution : NativeACUnifier (encodeNativeNatural left) (encodeNativeNatural right) assignment) :
    ∃ typed : QuerySubstitution, nativeQueryAssignment typed = assignment ∧
      NaturalAC (substituteQueryNatural typed left) (substituteQueryNatural typed right) := by
  obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation solution.1
  refine ⟨typed, compatible, (native_natural_ac_unifier_iff typed left right).mp ?_⟩
  rw [compatible]
  exact solution

theorem native_kind_ac_unifier_iff (assignment : QuerySort → Nat → NativeQueryTerm)
    (left right : NativeQueryTerm) :
    NativeACUnifier left right assignment ↔
      NativeSortedAssignment assignment ∧
        NativeQueryAC
          (substituteNativeQuery (abstractKindAssignment assignment)
            (relabelNative kindAbstraction left))
          (substituteNativeQuery (abstractKindAssignment assignment)
            (relabelNative kindAbstraction right)) := by
  constructor
  · intro solution
    refine ⟨solution.1, ?_⟩
    rw [← native_kind_substitution, ← native_kind_substitution]
    exact native_ac_relabeling kindAbstraction solution.2
  · rintro ⟨sorted, equivalent⟩
    refine ⟨sorted, native_kind_ac_reflection ?_⟩
    rw [native_kind_substitution, native_kind_substitution]
    exact equivalent

theorem native_kind_ac_unifier_representation (solution : NativeACUnifier left right assignment)
    (firstDecoded : decodeKindMessage left = some first)
    (secondDecoded : decodeKindMessage right = some second) :
    ∃ shadow : QuerySubstitution,
      abstractKindAssignment assignment = nativeQueryAssignment shadow ∧
        MessageAC (substituteQueryMessage shadow first) (substituteQueryMessage shadow second) := by
  obtain ⟨shadow, compatible⟩ := native_kind_shadow_representation solution.1
  refine ⟨shadow, compatible, (native_message_ac_unifier_iff shadow first second).mp ?_⟩
  refine ⟨native_typed_assignment_sorted shadow, ?_⟩
  rw [native_message_recognition _ firstDecoded, native_message_recognition _ secondDecoded]
  rw [← compatible]
  exact ((native_kind_ac_unifier_iff assignment left right).mp solution).2

#print axioms native_ac_unifier_composition
#print axioms native_message_ac_unifier_iff
#print axioms native_natural_ac_unifier_iff
#print axioms native_message_ac_unifier_representation
#print axioms native_natural_ac_unifier_representation
#print axioms native_kind_ac_unifier_iff
#print axioms native_kind_ac_unifier_representation

end Cairn.Equations
