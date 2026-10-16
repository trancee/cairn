import QueryCompleteness

namespace Cairn.Equations

private def identify : QuerySubstitution where
  publicAtoms index := 2 * index
  freshAtoms index := 2 * index
  messages index := if index = 9 then .roleA else .atom .messageAtom (2 * index)
  naturals
    | 0 => .variable 2
    | index + 1 => .variable (2 * (index + 1))
  nodes index := 2 * index

-- X = Y has a complete singleton; the irrelevant message binding is excluded.
private theorem identify_most_general :
    NativeMostGeneralACUnifier (.queryVariable .natural 0) (.queryVariable .natural 1)
      (nativeQueryAssignment identify) := by
  constructor
  · exact ⟨native_typed_assignment_sorted identify, .reflexive⟩
  · intro solution solved
    refine ⟨solution, solved.1, ?_⟩
    intro sort index member
    simp only [nativeQueryVariables, List.mem_append, List.mem_singleton, Prod.mk.injEq] at member
    rcases member with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · exact solved.2
    · exact .reflexive

example : NativeCompleteACUnifiers (.queryVariable .natural 0) (.queryVariable .natural 1)
    [nativeQueryAssignment identify] :=
  native_singleton_complete_iff.mpr identify_most_general

example : QueryMostGeneralACUnifier
    (fun assignment => NaturalAC (substituteQueryNatural assignment (.variable 0))
      (substituteQueryNatural assignment (.variable 2)))
    [(.natural, 0), (.natural, 1)] identify :=
  (native_natural_most_general_iff (.variable 0) (.variable 2) identify).mp identify_most_general

example : QueryCompleteACUnifiers
    (fun assignment => MessageAC
      (substituteQueryMessage assignment (.natural (.variable 0)))
      (substituteQueryMessage assignment (.natural (.variable 2))))
    [(.natural, 0), (.natural, 1)] [identify] := by
  apply (native_message_complete_unifiers_iff
    (.natural (.variable 0)) (.natural (.variable 2)) [identify]).mp
  exact native_singleton_complete_iff.mpr identify_most_general

private def unconstrained : QuerySubstitution :=
  { identify with messages := fun index => .atom .messageAtom (2 * index) }

private theorem unconstrained_solution :
    NativeACUnifier (.queryVariable .natural 0) (.queryVariable .natural 1)
      (nativeQueryAssignment unconstrained) :=
  ⟨native_typed_assignment_sorted unconstrained, .reflexive⟩

example : NativeACInstanceOn [(.natural, 0), (.natural, 1)]
    (nativeQueryAssignment identify) (nativeQueryAssignment unconstrained) :=
  identify_most_general.2 _ unconstrained_solution

-- Adding a variable absent from the input would wrongly reject this MGU.
example : ¬ NativeACInstanceOn [(.natural, 0), (.natural, 1), (.message, 9)]
    (nativeQueryAssignment identify) (nativeQueryAssignment unconstrained) := by
  rintro ⟨factor, _, equivalent⟩
  have leaf := native_query_ac_leaf (equivalent .message 9 (by simp))
  change some (NativeQueryTerm.queryVariable .message 9) = some NativeQueryTerm.roleA at leaf
  cases leaf

private def ground : QuerySubstitution :=
  { identify with naturals := fun _ => .one }

private theorem ground_solution :
    NativeACUnifier (.queryVariable .natural 0) (.queryVariable .natural 1)
      (nativeQueryAssignment ground) :=
  ⟨native_typed_assignment_sorted ground, .reflexive⟩

private theorem ground_not_cover :
    ¬ NativeACInstanceOn [(.natural, 0), (.natural, 1)]
      (nativeQueryAssignment ground) (nativeQueryAssignment identify) := by
  rintro ⟨factor, _, equivalent⟩
  have leaf := native_query_ac_leaf (equivalent .natural 0 (by simp))
  change some (NativeQueryTerm.queryVariable .natural 1) = some NativeQueryTerm.naturalOne at leaf
  cases leaf

-- A sound family is not necessarily complete: both variables fixed to one fail.
example : (∀ candidate ∈ [nativeQueryAssignment ground],
    NativeACUnifier (.queryVariable .natural 0) (.queryVariable .natural 1) candidate) := by
  intro candidate member
  simp only [List.mem_singleton] at member
  rw [member]
  exact ground_solution

example : ¬ NativeCompleteACUnifiers (.queryVariable .natural 0) (.queryVariable .natural 1)
    [nativeQueryAssignment ground] := by
  intro complete
  have general := native_singleton_complete_iff.mp complete
  exact ground_not_cover (general.2 _ identify_most_general.1)

example : ¬ QueryMostGeneralACUnifier
    (fun assignment => NaturalAC (substituteQueryNatural assignment (.variable 0))
      (substituteQueryNatural assignment (.variable 2)))
    [(.natural, 0), (.natural, 1)] ground := by
  intro general
  have transported := (native_natural_most_general_iff (.variable 0) (.variable 2) ground).mpr general
  exact ground_not_cover (transported.2 _ identify_most_general.1)

example : ¬ NativeCompleteACUnifiers (.queryVariable .natural 0) (.queryVariable .natural 1) [] := by
  intro complete
  obtain ⟨candidate, member, _⟩ := complete.2 _ identify_most_general.1
  cases member

-- Finite-AST solution controls, not correctness proofs of a native occurs check.
example : ¬ ∃ assignment, NativeACUnifier (.queryVariable .message 0)
    (.unary .hash (.queryVariable .message 0)) assignment := by
  rintro ⟨assignment, solved⟩
  have count := native_query_ac_preserves_count solved.2
  simp [substituteNativeQuery, nativeQueryFunctionCount] at count

example : ¬ ∃ assignment, NativeACUnifier .naturalOne
    (.naturalAdd .naturalOne (.queryVariable .natural 0)) assignment := by
  rintro ⟨assignment, solved⟩
  have count := native_query_ac_preserves_count solved.2
  simp [substituteNativeQuery, nativeQueryFunctionCount] at count

end Cairn.Equations
