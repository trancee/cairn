import QueryValueAbstraction
import NaturalResiduals

namespace Cairn.Equations

abbrev NativeVariableKey : Type := QuerySort × Nat
abbrev NativeBindingList : Type := List (NativeVariableKey × NativeQueryTerm)

def NativeRawACSystemUnifier (equations : NativeEquationSystem)
    (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∀ equation ∈ equations, NativeQueryAC
    (substituteNativeQuery assignment equation.1) (substituteNativeQuery assignment equation.2)

def NativeRawCompleteACSystemOn (equations : NativeEquationSystem)
    (scope : List NativeVariableKey) (family : List NativeBindingList) : Prop :=
  (∀ bindings ∈ family, NativeRawACSystemUnifier equations (nativeBindingAssignment bindings)) ∧
    ∀ solution, NativeRawACSystemUnifier equations solution →
      ∃ bindings ∈ family, ∃ factor,
        NativeAssignmentACOn scope solution
          (composeNativeAssignments (nativeBindingAssignment bindings) factor)

def nativeAllQuerySorts : List QuerySort := [.publicAtom, .freshAtom, .natural, .message, .node]

def nativeResidualKeys (scope : List NativeVariableKey)
    (assignment : QuerySort → Nat → NativeQueryTerm) : List NativeVariableKey :=
  (nativeAssignmentVariables scope assignment).eraseDups

def nativeResidualRetag (forbidden : List Nat) (keys : List NativeVariableKey)
    (choices : List QuerySort) : QuerySort → Nat → NativeQueryTerm :=
  nativeBindingAssignment ((keys.zip choices).map (fun (key, chosen) =>
    (key, .queryVariable chosen (naturalResidualIndex forbidden keys key))))

def nativeRetagCandidate (scope : List NativeVariableKey) (raw : NativeBindingList)
    (choices : List QuerySort) : NativeBindingList :=
  let assignment := nativeBindingAssignment raw
  let keys := nativeResidualKeys scope assignment
  let retag := nativeResidualRetag (scope.map Prod.snd) keys choices
  scope.map (fun key => (key, substituteNativeQuery retag (assignment key.1 key.2)))

def nativeBindingsSortedCheck (bindings : NativeBindingList) : Bool :=
  bindings.all (fun binding => nativeSortedValueCheck binding.1.1 binding.2)

def nativeRetypedBindingFamily (scope : List NativeVariableKey) (raw : NativeBindingList) :
    List NativeBindingList :=
  let keys := nativeResidualKeys scope (nativeBindingAssignment raw)
  (((integerBoundedWords nativeAllQuerySorts keys.length).filter
    (fun choices => choices.length == keys.length)).map (nativeRetagCandidate scope raw)).filter
      nativeBindingsSortedCheck

def nativeSortedBindingFamily (scope : List NativeVariableKey) (raw : List NativeBindingList) :
    List NativeBindingList :=
  raw.flatMap (nativeRetypedBindingFamily scope)

theorem native_bindings_sorted_of_values (bindings : NativeBindingList)
    (values : ∀ binding ∈ bindings, NativeSortedValue binding.1.1 binding.2) :
    NativeSortedAssignment (nativeBindingAssignment bindings) := by
  induction bindings with
  | nil => exact native_identity_assignment_sorted
  | cons first rest induction =>
    intro sort index
    simp only [nativeBindingAssignment]
    split
    · rename_i equal
      have value := values first (by simp)
      simpa only [equal] using value
    · exact induction (fun binding member => values binding (List.mem_cons_of_mem _ member)) sort index

theorem native_bindings_sorted_check (accepted : nativeBindingsSortedCheck bindings = true) :
    NativeSortedAssignment (nativeBindingAssignment bindings) := by
  apply native_bindings_sorted_of_values
  intro binding member
  exact (native_sorted_value_check_iff _ _).mpr ((List.all_eq_true.mp accepted) binding member)

theorem native_binding_lookup_map (entries : List α) (domain : α → NativeVariableKey)
    (value : α → NativeQueryTerm) (target : NativeVariableKey)
    (present : ∃ entry ∈ entries, domain entry = target)
    (agree : ∀ entry ∈ entries, domain entry = target → value entry = expected) :
    nativeBindingAssignment (entries.map (fun entry => (domain entry, value entry)))
      target.1 target.2 = expected := by
  induction entries with
  | nil => simp at present
  | cons first rest induction =>
    simp only [List.map, nativeBindingAssignment]
    by_cases equal : domain first = target
    · rw [ite_eq_left equal]
      exact agree first (by simp) equal
    · rw [ite_eq_right equal]
      apply induction
      · obtain ⟨entry, member, same⟩ := present
        rcases List.mem_cons.mp member with rfl | member
        · exact (equal same).elim
        · exact ⟨entry, member, same⟩
      · exact fun entry member same => agree entry (List.mem_cons_of_mem _ member) same

theorem native_residual_retag_functional (forbidden : List Nat) (keys : List NativeVariableKey)
    (chosen : NativeVariableKey → QuerySort) :
    nativeResidualRetag forbidden keys (keys.map chosen) =
      restrictNativeAssignment keys (fun sort index =>
        .queryVariable (chosen (sort, index)) (naturalResidualIndex forbidden keys (sort, index))) := by
  have paired : keys.zip (keys.map chosen) = keys.map (fun key => (key, chosen key)) := by
    induction keys with
    | nil => rfl
    | cons _ _ induction => simp [induction]
  unfold nativeResidualRetag
  rw [paired, List.map_map]
  rw [← native_bindings_restriction keys (fun sort index =>
    NativeQueryTerm.queryVariable (chosen (sort, index))
      (naturalResidualIndex forbidden keys (sort, index)))]
  apply congrArg nativeBindingAssignment
  apply List.map_congr_left
  intro key _
  cases key
  rfl

theorem native_retag_candidate_assignment (scope : List NativeVariableKey)
    (raw : NativeBindingList) (choices : List QuerySort) :
    nativeBindingAssignment (nativeRetagCandidate scope raw choices) =
      restrictNativeAssignment scope (composeNativeAssignments (nativeBindingAssignment raw)
        (nativeResidualRetag (scope.map Prod.snd)
          (nativeResidualKeys scope (nativeBindingAssignment raw)) choices)) := by
  simpa only [nativeRetagCandidate, composeNativeAssignments] using
    (native_bindings_restriction scope
      (composeNativeAssignments (nativeBindingAssignment raw)
        (nativeResidualRetag (scope.map Prod.snd)
          (nativeResidualKeys scope (nativeBindingAssignment raw)) choices)))

theorem native_residual_keys_cover (member : (sort, index) ∈ scope)
    (occurs : (childSort, childIndex) ∈ nativeQueryVariables (assignment sort index)) :
    (childSort, childIndex) ∈ nativeResidualKeys scope assignment := by
  apply List.mem_eraseDups.mpr
  exact List.mem_flatMap.mpr ⟨(sort, index), member, occurs⟩

#print axioms native_bindings_sorted_of_values
#print axioms native_bindings_sorted_check
#print axioms native_binding_lookup_map
#print axioms native_residual_retag_functional
#print axioms native_retag_candidate_assignment
#print axioms native_residual_keys_cover

end Cairn.Equations
