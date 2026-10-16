import QueryCompleteness

namespace Cairn.Equations

deriving instance DecidableEq for QuerySort

def NativeAssignmentSupportedOn (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∀ sort index, (sort, index) ∉ variables →
    assignment sort index = .queryVariable sort index

def restrictNativeAssignment (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) : QuerySort → Nat → NativeQueryTerm :=
  fun sort index =>
    if (sort, index) ∈ variables then assignment sort index else .queryVariable sort index

-- This finite mathematical representation uses simultaneous, first-binding lookup.
def nativeBindingAssignment :
    List ((QuerySort × Nat) × NativeQueryTerm) → QuerySort → Nat → NativeQueryTerm
  | [], sort, index => .queryVariable sort index
  | (key, value) :: rest, sort, index =>
    if key = (sort, index) then value else nativeBindingAssignment rest sort index

def NativeFiniteAssignment (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∃ bindings, nativeBindingAssignment bindings = assignment

theorem native_substitution_eq_on
    (equal : ∀ sort index, (sort, index) ∈ nativeQueryVariables term →
      first sort index = second sort index) :
    substituteNativeQuery first term = substituteNativeQuery second term := by
  induction term with
  | queryVariable sort index => exact equal sort index (by simp [nativeQueryVariables])
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil => rfl
  | naturalAdd _ _ left right =>
    simp only [substituteNativeQuery]
    congr 1
    · exact left (fun sort index member => equal sort index (List.mem_append_left _ member))
    · exact right (fun sort index member => equal sort index (List.mem_append_right _ member))
  | unary symbol _ child => exact congrArg (NativeQueryTerm.unary symbol) (child equal)
  | binary _ _ _ left right =>
    simp only [substituteNativeQuery]
    congr 1
    · exact left (fun sort index member => equal sort index (List.mem_append_left _ member))
    · exact right (fun sort index member => equal sort index (List.mem_append_right _ member))
  | kdf _ _ _ first second third =>
    simp only [substituteNativeQuery]
    congr 1
    · exact first (fun sort index member =>
        equal sort index (List.mem_append_left _ (List.mem_append_left _ member)))
    · exact second (fun sort index member =>
        equal sort index (List.mem_append_left _ (List.mem_append_right _ member)))
    · exact third (fun sort index member => equal sort index (List.mem_append_right _ member))
  | list _ child => exact congrArg NativeQueryTerm.list (child equal)
  | cons _ _ first rest =>
    simp only [substituteNativeQuery]
    congr 1
    · exact first (fun sort index member => equal sort index (List.mem_append_left _ member))
    · exact rest (fun sort index member => equal sort index (List.mem_append_right _ member))

theorem native_restriction_supported (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeAssignmentSupportedOn variables (restrictNativeAssignment variables assignment) := by
  intro sort index outside
  simp [restrictNativeAssignment, outside]

theorem native_restriction_sorted (variables : List (QuerySort × Nat))
    (sorted : NativeSortedAssignment assignment) :
    NativeSortedAssignment (restrictNativeAssignment variables assignment) := by
  intro sort index
  unfold restrictNativeAssignment
  split
  · exact sorted sort index
  · cases sort
    · exact .publicVariable
    · exact .freshVariable
    · exact .message rfl
    · exact .natural rfl
    · exact .nodeVariable

theorem native_restriction_substitution
    (contains : ∀ sort index, (sort, index) ∈ nativeQueryVariables term →
      (sort, index) ∈ variables) :
    substituteNativeQuery (restrictNativeAssignment variables assignment) term =
      substituteNativeQuery assignment term := by
  apply native_substitution_eq_on
  intro sort index member
  simp [restrictNativeAssignment, contains sort index member]

theorem native_bindings_restriction (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    nativeBindingAssignment (variables.map (fun key =>
      (key, assignment key.1 key.2))) =
        restrictNativeAssignment variables assignment := by
  induction variables with
  | nil => rfl
  | cons key variables induction =>
    funext sort index
    simp only [List.map, nativeBindingAssignment, restrictNativeAssignment, List.mem_cons]
    by_cases equal : key = (sort, index)
    · subst key
      simp
    · simp only [equal, Ne.symm equal, false_or, ite_false]
      exact congrFun (congrFun induction sort) index

theorem native_bindings_supported (bindings : List ((QuerySort × Nat) × NativeQueryTerm)) :
    NativeAssignmentSupportedOn (bindings.map Prod.fst) (nativeBindingAssignment bindings) := by
  induction bindings with
  | nil => intro _ _ _; rfl
  | cons binding rest induction =>
    obtain ⟨key, value⟩ := binding
    intro sort index outside
    simp only [List.map, List.mem_cons, not_or] at outside
    simp only [nativeBindingAssignment, ite_eq_right (Ne.symm outside.1)]
    exact induction sort index outside.2

theorem native_restriction_finite (variables : List (QuerySort × Nat))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeFiniteAssignment (restrictNativeAssignment variables assignment) :=
  ⟨variables.map (fun key => (key, assignment key.1 key.2)),
    native_bindings_restriction variables assignment⟩

#print axioms native_substitution_eq_on
#print axioms native_restriction_supported
#print axioms native_restriction_sorted
#print axioms native_restriction_substitution
#print axioms native_bindings_restriction
#print axioms native_bindings_supported
#print axioms native_restriction_finite

end Cairn.Equations
