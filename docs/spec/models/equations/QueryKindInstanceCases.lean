import QueryKindInstances

namespace Cairn.Equations

private def sample : QuerySort → Nat → NativeQueryTerm
  | .publicAtom, index => .atom .publicAtom (index + 1)
  | .freshAtom, index => .queryVariable .freshAtom (index + 3)
  | .message, index => .binary .pair (.queryVariable .freshAtom index) (.queryVariable .natural index)
  | .natural, index => .naturalAdd (.naturalAtom index) (.queryVariable .natural (index + 1))
  | .node, index => .queryVariable .node (index + 2)

private theorem sample_sorted : NativeSortedAssignment sample := by
  intro sort index
  cases sort
  · exact .publicAtom
  · exact .freshVariable
  · exact .message rfl
  · exact .natural rfl
  · exact .nodeVariable

example : abstractKindAssignment sample .natural 1 = .queryVariable .natural 7 := rfl

example : abstractKindAssignment sample .natural 0 =
    .naturalAdd (.naturalAtom 0) (.queryVariable .natural 2) := rfl

example : abstractKindAssignment sample .message 0 =
    .binary .pair (.queryVariable .natural 1) (.queryVariable .natural 0) := rfl

example : expandKindAssignment (abstractKindAssignment sample) .publicAtom 0 =
    .atom .publicAtom 1 := rfl

example : expandKindAssignment (abstractKindAssignment sample) .freshAtom 0 =
    .queryVariable .freshAtom 3 := rfl

example : expandKindAssignment (abstractKindAssignment sample) .node 0 =
    .queryVariable .node 2 := rfl

example : NativeKindAdmissibleAssignment (abstractKindAssignment sample) :=
  native_kind_admissible_iff.mpr ⟨sample, sample_sorted, rfl⟩

private def offImageShadow : QuerySort → Nat → NativeQueryTerm
  | .freshAtom, index => .atom .freshAtom index
  | sort, index => .queryVariable sort index

example : NativeSortedAssignment (expandKindAssignment offImageShadow) := by
  have identity : expandKindAssignment offImageShadow = NativeQueryTerm.queryVariable := by
    funext sort index
    have oddHalf : (2 * index + 1) / 2 = index := by omega
    cases sort <;>
      simp [expandKindAssignment, offImageShadow, kindVariableKey,
        relabelNative, kindExpansion, oddHalf]
  rw [identity]
  exact native_restriction_sorted [] sample_sorted

-- A sorted lift alone is insufficient: the shadow must also be its exact image.
example : ¬ NativeKindAdmissibleAssignment offImageShadow := by
  intro admissible
  have fixed := congrArg (fun assignment => assignment .freshAtom 0) admissible.2
  change NativeQueryTerm.queryVariable .freshAtom 0 = .atom .freshAtom 0 at fixed
  cases fixed

example : nativeQueryVariables (relabelNative kindAbstraction
    (.list (.cons (.queryVariable .node 0)
      (.kdf (.queryVariable .message 0) (.queryVariable .freshAtom 0)
        (.naturalAdd (.queryVariable .natural 0) (.atom .freshAtom 0)))))) =
      [(.node, 0), (.message, 0), (.natural, 1), (.natural, 0)] := rfl

private def freshCandidate : QuerySort → Nat → NativeQueryTerm
  | .message, _ => .queryVariable .freshAtom 0
  | sort, index => .queryVariable sort index

private def groundCandidate : QuerySort → Nat → NativeQueryTerm
  | .message, _ => .naturalOne
  | sort, index => .queryVariable sort index

private def unrestrictedFactor : QuerySort → Nat → NativeQueryTerm
  | .natural, _ => .naturalOne
  | sort, index => .queryVariable sort index

example : NativeSortedAssignment freshCandidate := by
  intro sort index
  cases sort
  · exact .publicVariable
  · exact .freshVariable
  · exact .message rfl
  · exact .natural rfl
  · exact .nodeVariable

example : NativeSortedAssignment groundCandidate := by
  intro sort index
  cases sort
  · exact .publicVariable
  · exact .freshVariable
  · exact .message rfl
  · exact .natural rfl
  · exact .nodeVariable

private theorem unrestricted_sorted : NativeSortedAssignment unrestrictedFactor := by
  intro sort index
  cases sort
  · exact .publicVariable
  · exact .freshVariable
  · exact .message rfl
  · exact .natural rfl
  · exact .nodeVariable

example : ¬ NativeKindAdmissibleAssignment unrestrictedFactor := by
  intro admissible
  have value := admissible.1 .freshAtom 0
  change NativeSortedValue .freshAtom .naturalOne at value
  cases value

example : NativeACInstanceOn [(.message, 0)]
    (abstractKindAssignment freshCandidate) (abstractKindAssignment groundCandidate) := by
  refine ⟨unrestrictedFactor, unrestricted_sorted, ?_⟩
  intro sort index member
  simp only [List.mem_singleton, Prod.mk.injEq] at member
  obtain ⟨rfl, rfl⟩ := member
  exact .reflexive

private theorem no_original_factor :
    ¬ NativeACInstanceOn [(.message, 0)] freshCandidate groundCandidate := by
  rintro ⟨factor, sorted, equivalent⟩
  have leaf := native_query_ac_leaf (equivalent .message 0 (by simp))
  change some .naturalOne = nativeQueryLeaf (factor .freshAtom 0) at leaf
  have value := sorted .freshAtom 0
  generalize binding : factor .freshAtom 0 = term at value leaf
  cases value <;> simp [nativeQueryLeaf] at leaf

example : ¬ NativeKindACInstanceOn ([ (.message, 0) ].map kindVariableKey)
    (abstractKindAssignment freshCandidate) (abstractKindAssignment groundCandidate) :=
  fun factor => no_original_factor (native_kind_ac_instance_iff.mp factor)

end Cairn.Equations
