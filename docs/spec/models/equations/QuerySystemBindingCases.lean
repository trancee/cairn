import QuerySystemBindings

namespace Cairn.Equations

private def inputVariable : NativeQueryTerm := .queryVariable .natural 0
private def residualVariable : NativeQueryTerm := .queryVariable .natural 7
private def firstBindings := [((QuerySort.natural, 0), residualVariable)]
private def secondBindings := [((QuerySort.natural, 7), NativeQueryTerm.naturalOne)]
private def seed := nativeBindingAssignment firstBindings
private def residual := nativeBindingAssignment secondBindings
private def equations : NativeEquationSystem :=
  [(inputVariable, residualVariable), (inputVariable, .naturalOne)]

example : composeNativeBindings firstBindings secondBindings =
    [((.natural, 0), .naturalOne), ((.natural, 7), .naturalOne)] := rfl

example : nativeBindingAssignment (firstBindings ++ secondBindings) .natural 0 =
    residualVariable := rfl

example : nativeBindingAssignment (composeNativeBindings firstBindings secondBindings)
    .natural 0 = .naturalOne := rfl

example : nativeBindingAssignment (composeNativeBindings secondBindings firstBindings)
    .natural 0 = residualVariable := rfl

example : nativeBindingAssignment (composeNativeBindings
    [((.message, 0), .roleA)] [((.message, 0), .roleB)]) .message 0 = .roleA := rfl

example : composeNativeBindings
    [((.natural, 0), residualVariable), ((.natural, 0), .naturalAdd .naturalOne .naturalOne)]
      secondBindings =
    [((.natural, 0), .naturalOne), ((.natural, 0), .naturalAdd .naturalOne .naturalOne),
      ((.natural, 7), .naturalOne)] := rfl

example : substituteNativeSystem seed [(inputVariable, .naturalOne)] =
    [(residualVariable, .naturalOne)] := rfl

example : NativeCompleteACSystemOn equations (nativeSystemVariables equations)
    [composeNativeAssignments seed residual] := by
  have complete : NativeCompleteACSystemOn
      (substituteNativeSystem seed [(inputVariable, .naturalOne)])
      (nativeAssignmentVariables (nativeSystemVariables equations) seed) [residual] :=
    native_system_single_binding_complete (.natural rfl) (by decide) _
  exact native_system_variable_elimination (.natural rfl) (by decide) complete

example : NativeFiniteAssignment (composeNativeAssignments seed residual) :=
  native_finite_assignment_composition
    (native_single_binding_finite .natural 0 residualVariable)
    (native_single_binding_finite .natural 7 .naturalOne)

private theorem commutative_complete (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn
      [(.naturalAdd residualVariable .naturalOne, .naturalAdd .naturalOne residualVariable)]
      variables [NativeQueryTerm.queryVariable] := by
  constructor
  · intro candidate member
    have equal := List.mem_singleton.mp member
    subst candidate
    refine ⟨native_identity_assignment_sorted, ?_⟩
    intro equation member
    have equal := List.mem_singleton.mp member
    subst equation
    exact .commutative
  · intro solution solved
    refine ⟨NativeQueryTerm.queryVariable, by simp, solution, solved.1, ?_⟩
    intro sort index _
    exact .reflexive

private def sumValue : NativeQueryTerm := .naturalAdd residualVariable .naturalOne
private def sumBinding := nativeBindingAssignment [((.natural, 0), sumValue)]
private def sumEquations : NativeEquationSystem :=
  [(inputVariable, sumValue), (inputVariable, .naturalAdd .naturalOne residualVariable)]

-- The residual system is solved by AC, not structural equality or a rewrite equation.
example : NativeCompleteACSystemOn sumEquations (nativeSystemVariables sumEquations)
    [composeNativeAssignments sumBinding NativeQueryTerm.queryVariable] :=
  native_system_variable_elimination (sort := .natural) (index := 0) (value := sumValue)
    (equations := [(inputVariable, .naturalAdd .naturalOne residualVariable)])
    (variables := nativeSystemVariables sumEquations) (.natural rfl) (by decide)
    (commutative_complete _)

private def freshVariable : NativeQueryTerm := .queryVariable .freshAtom 0
private def messageVariable : NativeQueryTerm := .queryVariable .message 7
private def freshResidual : NativeQueryTerm := .queryVariable .freshAtom 11
private def reversedEquations : NativeEquationSystem :=
  [(freshVariable, messageVariable), (messageVariable, freshResidual)]
private def reversedSeed := nativeBindingAssignment [((.message, 7), freshVariable)]
private def reversedResidual := nativeBindingAssignment [((.freshAtom, 0), freshResidual)]

example : NativeCompleteACSystemOn reversedEquations (nativeSystemVariables reversedEquations)
    [composeNativeAssignments reversedSeed reversedResidual] := by
  have complete : NativeCompleteACSystemOn
      (substituteNativeSystem reversedSeed [(messageVariable, freshResidual)])
      (nativeAssignmentVariables (nativeSystemVariables reversedEquations) reversedSeed)
      [reversedResidual] :=
    native_system_single_binding_complete .freshVariable (by decide) _
  exact native_system_reversed_variable_elimination (.message rfl) (by decide) complete

example : composeNativeAssignments reversedSeed reversedResidual .message 7 = freshResidual := rfl

example (rest : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn
      ((.queryVariable .message 0, .unary .hash (.queryVariable .message 0)) :: rest)
      variables [] :=
  native_system_occurs_complete_empty_family (by decide) (by intro equal; cases equal) rest variables

end Cairn.Equations
