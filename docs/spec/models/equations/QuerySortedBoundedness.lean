import QuerySortedConvergence

namespace Cairn.Equations

theorem native_sorted_steps_transitive (first : NativeSortedSteps left firstCount middle)
    (second : NativeSortedSteps middle secondCount right) :
    NativeSortedSteps left (firstCount + secondCount) right := by
  induction first with
  | reflexive => simpa using second
  | step rewrite _ induction =>
    simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using
      NativeSortedSteps.step rewrite (induction second)

theorem native_sorted_steps_context (context : NativeQueryTerm → NativeQueryTerm)
    (preserves : ∀ {left right}, NativeSortedRewrite left right →
      NativeSortedRewrite (context left) (context right))
    (steps : NativeSortedSteps left count right) :
    NativeSortedSteps (context left) count (context right) := by
  induction steps with
  | reflexive => exact .reflexive
  | step rewrite _ induction => exact .step (preserves rewrite) induction

private theorem normal_context_argument (context : NativeQueryTerm → NativeQueryTerm)
    (preserves : ∀ {left right}, NativeSortedRewrite left right →
      NativeSortedRewrite (context left) (context right))
    (normal : NativeSortedNormal (context argument)) : NativeSortedNormal argument := by
  intro result rewrite
  exact normal _ (preserves rewrite)

private def ChildrenNormal : NativeQueryTerm → Prop
  | .unary _ argument | .list argument => NativeSortedNormal argument
  | .binary _ left right | .naturalAdd left right | .cons left right =>
    NativeSortedNormal left ∧ NativeSortedNormal right
  | .kdf first second third =>
    NativeSortedNormal first ∧ NativeSortedNormal second ∧ NativeSortedNormal third
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .queryVariable _ _
  | .naturalOne | .roleA | .roleB | .nil => True

private theorem ready_without_root_is_normal (ready : ChildrenNormal term)
    (noRoot : ∀ result, ¬ NativeSortedPrimitiveRewrite term result) :
    NativeSortedNormal term := by
  intro result rewrite
  cases rewrite with
  | primitive step => exact noRoot _ step
  | unary step => exact ready _ step
  | binaryLeft step => exact ready.1 _ step
  | binaryRight step => exact ready.2 _ step
  | kdfFirst step => exact ready.1 _ step
  | kdfSecond step => exact ready.2.1 _ step
  | kdfThird step => exact ready.2.2 _ step
  | naturalLeft step => exact ready.1 _ step
  | naturalRight step => exact ready.2 _ step
  | list step => exact ready _ step
  | consLeft step => exact ready.1 _ step
  | consRight step => exact ready.2 _ step

private theorem ready_root_result_is_normal (ready : ChildrenNormal left)
    (rewrite : NativeSortedPrimitiveRewrite left right) : NativeSortedNormal right := by
  cases rewrite with
  | flipA | flipB =>
    intro result step
    cases step with
    | primitive impossible => cases impossible
  | @fst first second _ _ =>
    exact normal_context_argument (fun argument => .binary .pair argument second)
      (fun step => .binaryLeft step) ready
  | @snd first second _ _ =>
    exact normal_context_argument (fun argument => .binary .pair first argument)
      (fun step => .binaryRight step) ready
  | @sdec payload firstKey secondKey _ _ _ =>
    exact normal_context_argument (fun argument => .binary .senc argument firstKey)
      (fun step => .binaryLeft step) ready.1
  | @kdec payload firstKey secondKey _ _ _ =>
    exact normal_context_argument (fun argument => .binary .kem argument (.unary .pk firstKey))
      (fun step => .binaryLeft step) ready.1

private theorem ready_normalizes_in_one_step (ready : ChildrenNormal term) :
    ∃ count result, count ≤ 1 ∧ NativeSortedSteps term count result ∧
      NativeSortedNormal result := by
  classical
  by_cases root : ∃ result, NativeSortedPrimitiveRewrite term result
  · obtain ⟨result, rewrite⟩ := root
    exact ⟨1, result, by omega, .step (.primitive rewrite) .reflexive,
      ready_root_result_is_normal ready rewrite⟩
  · exact ⟨0, term, by omega, .reflexive,
      ready_without_root_is_normal ready (fun result rewrite => root ⟨result, rewrite⟩)⟩

-- Count source contexts, never constructors introduced by variable assignments.
def nativeQueryFunctionCount : NativeQueryTerm → Nat
  | .unary _ argument | .list argument => nativeQueryFunctionCount argument + 1
  | .binary _ left right | .naturalAdd left right | .cons left right =>
    nativeQueryFunctionCount left + nativeQueryFunctionCount right + 1
  | .kdf first second third =>
    nativeQueryFunctionCount first + nativeQueryFunctionCount second +
      nativeQueryFunctionCount third + 1
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .queryVariable _ _
  | .naturalOne | .roleA | .roleB | .nil => 0

private theorem unary_normalization (context : NativeQueryTerm → NativeQueryTerm)
    (preserves : ∀ {left right}, NativeSortedRewrite left right →
      NativeSortedRewrite (context left) (context right))
    (ready : ∀ argument, NativeSortedNormal argument → ChildrenNormal (context argument))
    (child : ∃ count result, count ≤ bound ∧ NativeSortedSteps term count result ∧
      NativeSortedNormal result) :
    ∃ count result, count ≤ bound + 1 ∧ NativeSortedSteps (context term) count result ∧
      NativeSortedNormal result := by
  obtain ⟨childCount, childResult, childBound, childSteps, childNormal⟩ := child
  obtain ⟨rootCount, result, rootBound, rootSteps, resultNormal⟩ :=
    ready_normalizes_in_one_step (ready childResult childNormal)
  exact ⟨childCount + rootCount, result, by omega,
    native_sorted_steps_transitive (native_sorted_steps_context context preserves childSteps)
      rootSteps, resultNormal⟩

private theorem binary_normalization
    (context : NativeQueryTerm → NativeQueryTerm → NativeQueryTerm)
    (preservesLeft : ∀ {left right other}, NativeSortedRewrite left right →
      NativeSortedRewrite (context left other) (context right other))
    (preservesRight : ∀ {left right other}, NativeSortedRewrite left right →
      NativeSortedRewrite (context other left) (context other right))
    (ready : ∀ left right, NativeSortedNormal left → NativeSortedNormal right →
      ChildrenNormal (context left right))
    (first : ∃ count result, count ≤ firstBound ∧ NativeSortedSteps left count result ∧
      NativeSortedNormal result)
    (second : ∃ count result, count ≤ secondBound ∧ NativeSortedSteps right count result ∧
      NativeSortedNormal result) :
    ∃ count result, count ≤ firstBound + secondBound + 1 ∧
      NativeSortedSteps (context left right) count result ∧ NativeSortedNormal result := by
  obtain ⟨leftCount, leftResult, leftBound, leftSteps, leftNormal⟩ := first
  obtain ⟨rightCount, rightResult, rightBound, rightSteps, rightNormal⟩ := second
  obtain ⟨rootCount, result, rootBound, rootSteps, resultNormal⟩ :=
    ready_normalizes_in_one_step (ready leftResult rightResult leftNormal rightNormal)
  exact ⟨leftCount + rightCount + rootCount, result, by omega,
    native_sorted_steps_transitive
      (native_sorted_steps_transitive
        (native_sorted_steps_context (fun term => context term right)
          (fun step => preservesLeft step) leftSteps)
        (native_sorted_steps_context (context leftResult)
          (fun step => preservesRight step) rightSteps)) rootSteps, resultNormal⟩

theorem native_sorted_query_substitution_bound (template : NativeQueryTerm)
    (assignment : QuerySort → Nat → NativeQueryTerm)
    (normalized : ∀ sort identifier, NativeSortedNormal (assignment sort identifier)) :
    ∃ count result, count ≤ nativeQueryFunctionCount template ∧
      NativeSortedSteps (substituteNativeQuery assignment template) count result ∧
      NativeSortedNormal result := by
  induction template with
  | queryVariable sort identifier =>
    exact ⟨0, _, Nat.zero_le _, .reflexive, normalized sort identifier⟩
  | atom | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil =>
    refine ⟨0, _, Nat.zero_le _, .reflexive, ?_⟩
    intro result step
    cases step with
    | primitive impossible => cases impossible
  | unary symbol argument induction =>
    exact unary_normalization (fun term => .unary symbol term) (fun step => .unary step)
      (fun _ normal => normal) induction
  | list argument induction =>
    exact unary_normalization NativeQueryTerm.list (fun step => .list step)
      (fun _ normal => normal) induction
  | binary symbol left right first second =>
    exact binary_normalization (NativeQueryTerm.binary symbol)
      (fun step => .binaryLeft step) (fun step => .binaryRight step)
      (fun _ _ first second => ⟨first, second⟩) first second
  | naturalAdd left right first second =>
    exact binary_normalization NativeQueryTerm.naturalAdd
      (fun step => .naturalLeft step) (fun step => .naturalRight step)
      (fun _ _ first second => ⟨first, second⟩) first second
  | cons left right first second =>
    exact binary_normalization NativeQueryTerm.cons
      (fun step => .consLeft step) (fun step => .consRight step)
      (fun _ _ first second => ⟨first, second⟩) first second
  | kdf first second third firstInduction secondInduction thirdInduction =>
    obtain ⟨firstCount, firstResult, firstBound, firstSteps, firstNormal⟩ := firstInduction
    obtain ⟨secondCount, secondResult, secondBound, secondSteps, secondNormal⟩ := secondInduction
    obtain ⟨thirdCount, thirdResult, thirdBound, thirdSteps, thirdNormal⟩ := thirdInduction
    obtain ⟨rootCount, result, rootBound, rootSteps, resultNormal⟩ :=
      ready_normalizes_in_one_step (term := .kdf firstResult secondResult thirdResult)
        ⟨firstNormal, secondNormal, thirdNormal⟩
    refine ⟨firstCount + secondCount + thirdCount + rootCount, result, ?_, ?_, resultNormal⟩
    · simp only [nativeQueryFunctionCount]
      omega
    · exact native_sorted_steps_transitive
        (native_sorted_steps_transitive
          (native_sorted_steps_transitive
            (native_sorted_steps_context
              (fun term => .kdf term (substituteNativeQuery assignment second)
                (substituteNativeQuery assignment third))
              (fun step => .kdfFirst step) firstSteps)
            (native_sorted_steps_context
              (fun term => .kdf firstResult term (substituteNativeQuery assignment third))
              (fun step => .kdfSecond step) secondSteps))
          (native_sorted_steps_context (fun term => .kdf firstResult secondResult term)
            (fun step => .kdfThird step) thirdSteps)) rootSteps

#print axioms native_sorted_steps_transitive
#print axioms native_sorted_steps_context
#print axioms native_sorted_query_substitution_bound

end Cairn.Equations
