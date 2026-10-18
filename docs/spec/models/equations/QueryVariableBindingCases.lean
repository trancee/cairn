import QueryVariableGeneration

namespace Cairn.Equations

example : NativeCompleteACUnifiers (.queryVariable .publicAtom 0) (.atom .publicAtom 0)
    [nativeBindingAssignment [((.publicAtom, 0), .atom .publicAtom 0)]] :=
  native_single_binding_complete_family .publicAtom (by decide)

example : NativeCompleteACUnifiers (.queryVariable .freshAtom 0) (.atom .freshAtom 0)
    [nativeBindingAssignment [((.freshAtom, 0), .atom .freshAtom 0)]] :=
  native_single_binding_complete_family .freshAtom (by decide)

example : NativeCompleteACUnifiers (.queryVariable .message 0) .roleA
    [nativeBindingAssignment [((.message, 0), .roleA)]] :=
  native_single_binding_complete_family (.message rfl) (by decide)

example : NativeCompleteACUnifiers (.queryVariable .natural 0) .naturalOne
    [nativeBindingAssignment [((.natural, 0), .naturalOne)]] :=
  native_single_binding_complete_family (.natural rfl) (by decide)

example : NativeCompleteACUnifiers (.queryVariable .node 0) (.nodeAtom 0)
    [nativeBindingAssignment [((.node, 0), .nodeAtom 0)]] :=
  native_single_binding_complete_family .nodeAtom (by decide)

-- Equal indices in different sorts are distinct keys, not an occurs cycle.
example : NativeMostGeneralACUnifier (.queryVariable .message 0) (.queryVariable .natural 0)
    (nativeBindingAssignment [((.message, 0), .queryVariable .natural 0)]) :=
  native_single_binding_most_general (.message rfl) (by decide)

private def value : NativeQueryTerm :=
  .naturalAdd (.queryVariable .natural 7) .naturalOne

private def binding := nativeBindingAssignment [((.natural, 0), value)]

example : nativeVariableBindingFamily .natural 0 ⟨value, .natural rfl⟩ =
    [[((.natural, 0), value)]] := rfl

example : NativeCompleteACUnifiers (.queryVariable .natural 0) value
    ((nativeVariableBindingFamily .natural 0 ⟨value, .natural rfl⟩).map nativeBindingAssignment) :=
  native_variable_binding_family_complete _ _ _

example : nativeVariableBindingFamily .node 0
    ⟨.queryVariable .node 0, .nodeVariable⟩ = [[]] := rfl

example : NativeCompleteACUnifiers (.queryVariable .node 0) (.queryVariable .node 0)
    ((nativeVariableBindingFamily .node 0
      ⟨.queryVariable .node 0, .nodeVariable⟩).map nativeBindingAssignment) :=
  native_variable_binding_family_complete _ _ _

example : NativeFiniteAssignment binding :=
  native_single_binding_finite .natural 0 value

example : NativeAssignmentSupportedOn [(.natural, 0)] binding :=
  native_single_binding_supported .natural 0 value

example : substituteNativeQuery binding value = value :=
  native_single_binding_fixes_value (by decide)

example : composeNativeAssignments binding binding = binding :=
  native_single_binding_idempotent (by decide)

example : NativeMostGeneralACUnifier (.queryVariable .natural 0) value binding :=
  native_single_binding_most_general (.natural rfl) (by decide)

example : NativeCompleteACUnifiers value (.queryVariable .natural 0) [binding] :=
  native_single_binding_reversed_complete_family (.natural rfl) (by decide)

private def twice : NativeQueryTerm := .naturalAdd .naturalOne .naturalOne
private def residual := nativeBindingAssignment [((.natural, 7), twice)]
private def ground :=
  nativeBindingAssignment [((.natural, 0), .naturalAdd .naturalOne twice)]
private def specific := composeNativeAssignments ground residual

private theorem specific_sorted : NativeSortedAssignment specific :=
  native_sorted_composition
    (native_single_binding_sorted_iff.mpr (.natural rfl))
    (native_single_binding_sorted_iff.mpr (.natural rfl))

private theorem specific_solves :
    NativeACUnifier (.queryVariable .natural 0) value specific := by
  refine ⟨specific_sorted, ?_⟩
  simpa [specific, ground, residual, twice, value, composeNativeAssignments,
    nativeBindingAssignment, substituteNativeQuery] using
    (NativeQueryAC.commutative (left := NativeQueryTerm.naturalOne) (right := twice))

example : NativeAssignmentAC specific (composeNativeAssignments binding specific) :=
  native_single_binding_factorization specific_solves

-- Coverage really uses AC and a residual variable, not structural equality.
example : NativeACInstanceOn [(.natural, 0), (.natural, 7)] binding specific := by
  refine ⟨residual, native_single_binding_sorted_iff.mpr (.natural rfl), ?_⟩
  intro sort index member
  simp only [List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at member
  rcases member with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
  · simpa [specific, ground, residual, binding, twice, value, composeNativeAssignments,
      nativeBindingAssignment, substituteNativeQuery] using
      (NativeQueryAC.commutative (left := NativeQueryTerm.naturalOne) (right := twice))
  · exact .reflexive

example : ¬ NativeSortedAssignment
    (nativeBindingAssignment [((.freshAtom, 0), .naturalOne)]) := by
  intro sorted
  have invalid := native_single_binding_sorted_iff.mp sorted
  cases invalid

example : ¬ NativeSortedAssignment
    (nativeBindingAssignment [((.publicAtom, 0), .roleA)]) := by
  intro sorted
  have invalid := native_single_binding_sorted_iff.mp sorted
  cases invalid

-- An incompatible orientation is not an unsatisfiable problem; reverse the binding.
example : NativeCompleteACUnifiers (.queryVariable .freshAtom 0) (.queryVariable .message 7)
    [nativeBindingAssignment [((.message, 7), .queryVariable .freshAtom 0)]] :=
  native_single_binding_reversed_complete_family (.message rfl) (by decide)

private def cyclicValue : NativeQueryTerm := .unary .hash (.queryVariable .message 0)
private def cyclicBinding := nativeBindingAssignment [((.message, 0), cyclicValue)]

example : nativeVariableBindingFamily .message 0 ⟨cyclicValue, .message rfl⟩ = [] := rfl

example : NativeCompleteACUnifiers (.queryVariable .message 0) cyclicValue
    ((nativeVariableBindingFamily .message 0
      ⟨cyclicValue, .message rfl⟩).map nativeBindingAssignment) :=
  native_variable_binding_family_complete _ _ _

example : NativeFiniteAssignment cyclicBinding :=
  native_single_binding_finite .message 0 cyclicValue

example : NativeSortedAssignment cyclicBinding :=
  native_single_binding_sorted_iff.mpr (.message rfl)

example : substituteNativeQuery cyclicBinding (.queryVariable .message 0) = cyclicValue := by
  simp [cyclicBinding, nativeBindingAssignment, substituteNativeQuery]

example : ¬ NativeACUnifier (.queryVariable .message 0) cyclicValue cyclicBinding :=
  native_ac_unifier_occurs_check (by decide) (by intro equal; cases equal)

example : composeNativeAssignments cyclicBinding cyclicBinding ≠ cyclicBinding := by
  intro equal
  have focused := congrFun (congrFun equal .message) 0
  simp [cyclicBinding, cyclicValue, composeNativeAssignments,
    nativeBindingAssignment, substituteNativeQuery] at focused

end Cairn.Equations
