import QueryGeneralCompleteness

namespace Cairn.Equations

example (equations : NativeEquationSystem) :
    NativeCompleteACSystemOn equations (nativeSystemVariables equations)
      ((nativeSortedACSystemBindingFamily equations).map nativeBindingAssignment) :=
  native_sorted_ac_system_family_complete equations

example (equations : NativeEquationSystem) (solution : QuerySort → Nat → NativeQueryTerm)
    (solved : NativeACSystemUnifier equations solution) :
    ∃ bindings ∈ nativeSortedACSystemBindingFamily equations,
      ∃ factor, NativeSortedAssignment factor ∧
        NativeAssignmentACOn (nativeSystemVariables equations) solution
          (composeNativeAssignments (nativeBindingAssignment bindings) factor) := by
  obtain ⟨candidate, included, factor, sorted, realizes⟩ :=
    (native_sorted_ac_system_family_complete equations).2 solution solved
  obtain ⟨bindings, member, rfl⟩ := List.mem_map.mp included
  exact ⟨bindings, member, factor, sorted, realizes⟩

example (term : NativeQueryTerm) :
    ∃ bindings ∈ nativeSortedACSystemBindingFamily [(term, term)],
      NativeACInstanceOn (nativeSystemVariables [(term, term)])
        (nativeBindingAssignment bindings) NativeQueryTerm.queryVariable := by
  have solved : NativeACSystemUnifier [(term, term)] NativeQueryTerm.queryVariable := by
    refine ⟨native_identity_assignment_sorted, ?_⟩
    intro equation member
    have same : equation = (term, term) := by simpa using member
    subst equation
    exact .reflexive
  obtain ⟨candidate, included, factor⟩ :=
    (native_sorted_ac_system_family_complete [(term, term)]).2 _ solved
  obtain ⟨bindings, member, rfl⟩ := List.mem_map.mp included
  exact ⟨bindings, member, factor⟩

private def controlledFramedSystem (term : NativeQueryTerm) : NativeEquationSystem :=
  let kind := NativeQueryTerm.kdf
    (.binary .pair (.naturalAdd (.queryVariable .freshAtom 3) .naturalOne) term)
    (.unary .hash term) .roleA
  let framing := NativeQueryTerm.list (.cons (.nodeAtom 0) .nil)
  [(kind, kind), (framing, framing)]

example (term : NativeQueryTerm) :
    ∃ bindings ∈ nativeSortedACSystemBindingFamily (controlledFramedSystem term),
      NativeSortedAssignment (nativeBindingAssignment bindings) := by
  have solved : NativeACSystemUnifier (controlledFramedSystem term) NativeQueryTerm.queryVariable := by
    refine ⟨native_identity_assignment_sorted, ?_⟩
    intro equation member
    simp [controlledFramedSystem] at member
    rcases member with rfl | rfl <;> exact .reflexive
  obtain ⟨candidate, included, _⟩ :=
    (native_sorted_ac_system_family_complete (controlledFramedSystem term)).2 _ solved
  obtain ⟨bindings, member, rfl⟩ := List.mem_map.mp included
  exact ⟨bindings, member, (native_sorted_ac_system_family_sound _ member).1⟩

example (member : bindings ∈ nativeSortedACSystemBindingFamily equations)
    (bindingMember : binding ∈ bindings) (occurs : key ∈ nativeQueryVariables binding.2) :
    key.2 ∉ (nativeSystemVariables equations).map Prod.snd :=
  native_sorted_ac_system_family_fresh member bindingMember occurs

private def expectFamilyEmpty (name : String) (equations : NativeEquationSystem)
    (expected : Bool) : IO Unit := do
  if (nativeSortedACSystemBindingFamily equations).isEmpty != expected then
    throw (IO.userError s!"unexpected sorted AC family emptiness: {name}")

#eval expectFamilyEmpty "empty system" [] false
#eval expectFamilyEmpty "literal one" [(.queryVariable .natural 0, .naturalOne)] false
#eval expectFamilyEmpty "Message/Node incompatibility"
  [(.queryVariable .message 0, .queryVariable .node 0)] true
#eval expectFamilyEmpty "Fresh/Public incompatibility"
  [(.queryVariable .freshAtom 0, .queryVariable .publicAtom 0)] true
#eval expectFamilyEmpty "free head clash" [(.roleA, .roleB)] true
#eval expectFamilyEmpty "free framing identity" [(.list .roleA, .list .roleA)] false
#eval expectFamilyEmpty "framing is not a message"
  [(.queryVariable .message 0, .list .roleA)] true
#eval expectFamilyEmpty "proper occurs cycle"
  [(.queryVariable .message 0, .unary .hash (.queryVariable .message 0))] true
#eval expectFamilyEmpty "one is not an empty semigroup value"
  [(.naturalAdd (.queryVariable .natural 0) .naturalOne, .naturalOne)] true
#eval expectFamilyEmpty "AC is not the six-rule theory"
  [(.unary .flip .roleA, .roleB)] true

#eval show IO Unit from do
  let family := nativeSortedACSystemBindingFamily
    [(.queryVariable .natural 0, .naturalAtom 0)]
  unless family.any (fun bindings =>
      nativeBindingAssignment bindings .natural 0 == NativeQueryTerm.naturalAtom 0) do
    throw (IO.userError "a frozen natural atom was confused with its same-index variable")

#eval show IO Unit from do
  let family := nativeSortedACSystemBindingFamily
    [(.queryVariable .message 7, .queryVariable .freshAtom 2)]
  unless family.any (fun bindings =>
      match nativeBindingAssignment bindings .message 7 with
      | .queryVariable .freshAtom index =>
        index > 7 && nativeBindingAssignment bindings .freshAtom 2 ==
          NativeQueryTerm.queryVariable .freshAtom index
      | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .naturalOne | .naturalAdd _ _ |
          .queryVariable .publicAtom _ | .queryVariable .natural _ | .queryVariable .message _ |
          .queryVariable .node _ | .roleA | .roleB | .unary _ _ | .binary _ _ _ | .kdf _ _ _ |
          .list _ | .cons _ _ | .nil => false) do
    throw (IO.userError "Message/Fresh refinement lost shared fresh residuals")

end Cairn.Equations
