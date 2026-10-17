import QuerySortedExact

namespace Cairn.Equations

theorem native_sorted_rewrite_decreases_count (step : NativeSortedRewrite left right) :
    nativeQueryFunctionCount right < nativeQueryFunctionCount left := by
  induction step
  case primitive root =>
    cases root <;> simp only [nativeQueryFunctionCount] <;> omega
  all_goals simp_all only [nativeQueryFunctionCount]; omega

theorem native_sorted_termination :
    WellFounded (fun right left : NativeQueryTerm => NativeSortedRewrite left right) := by
  apply Subrelation.wf (r := (measure nativeQueryFunctionCount).rel) _
    (measure nativeQueryFunctionCount).wf
  intro right left step
  exact native_sorted_rewrite_decreases_count step

private theorem joined_symmetric (joined : NativeSortedJoinable left right) :
    NativeSortedJoinable right left := by
  obtain ⟨result, firstCount, secondCount, first, second⟩ := joined
  exact ⟨result, secondCount, firstCount, second, first⟩

private theorem joined_context (context : NativeQueryTerm → NativeQueryTerm)
    (preserves : ∀ {left right}, NativeSortedRewrite left right →
      NativeSortedRewrite (context left) (context right))
    (joined : NativeSortedJoinable left right) :
    NativeSortedJoinable (context left) (context right) := by
  obtain ⟨result, firstCount, secondCount, first, second⟩ := joined
  exact ⟨context result, firstCount, secondCount,
    native_sorted_steps_context context preserves first,
    native_sorted_steps_context context preserves second⟩

private theorem primitive_peak (primitive : NativeSortedPrimitiveRewrite term left)
    (other : NativeSortedRewrite term right) : NativeSortedJoinable left right := by
  obtain ⟨source, _, _, encoding, _⟩ := native_sorted_primitive_image primitive
  have decoded : decodeNativeMessage term = some source := by
    rw [← encoding]
    exact native_message_round_trip _
  exact native_sorted_proper_confluence_exact
    (.step (.primitive primitive) .reflexive) (.step other .reflexive) decoded

theorem native_sorted_local_confluence (first : NativeSortedRewrite term left)
    (second : NativeSortedRewrite term right) : NativeSortedJoinable left right := by
  induction first generalizing right with
  | primitive first => exact primitive_peak first second
  | @unary argument result symbol first induction =>
    cases second with
    | primitive root => exact joined_symmetric (primitive_peak root (.unary first))
    | unary second =>
      exact joined_context (fun term => .unary symbol term) (fun step => .unary step)
        (induction second)
  | @binaryLeft argument result symbol other first induction =>
    cases second with
    | primitive root => exact joined_symmetric (primitive_peak root (.binaryLeft first))
    | binaryLeft second =>
      exact joined_context (fun term => .binary symbol term other) (fun step => .binaryLeft step)
        (induction second)
    | binaryRight second =>
      exact ⟨_, 1, 1, .step (.binaryRight second) .reflexive,
        .step (.binaryLeft first) .reflexive⟩
  | @binaryRight argument result symbol other first induction =>
    cases second with
    | primitive root => exact joined_symmetric (primitive_peak root (.binaryRight first))
    | binaryLeft second =>
      exact ⟨_, 1, 1, .step (.binaryLeft second) .reflexive,
        .step (.binaryRight first) .reflexive⟩
    | binaryRight second =>
      exact joined_context (fun term => .binary symbol other term) (fun step => .binaryRight step)
        (induction second)
  | @kdfFirst argument result other third first induction =>
    cases second with
    | primitive impossible => cases impossible
    | kdfFirst second =>
      exact joined_context (fun term => .kdf term other third) (fun step => .kdfFirst step)
        (induction second)
    | kdfSecond second =>
      exact ⟨_, 1, 1, .step (.kdfSecond second) .reflexive, .step (.kdfFirst first) .reflexive⟩
    | kdfThird second =>
      exact ⟨_, 1, 1, .step (.kdfThird second) .reflexive, .step (.kdfFirst first) .reflexive⟩
  | @kdfSecond argument result other third first induction =>
    cases second with
    | primitive impossible => cases impossible
    | kdfFirst second =>
      exact ⟨_, 1, 1, .step (.kdfFirst second) .reflexive, .step (.kdfSecond first) .reflexive⟩
    | kdfSecond second =>
      exact joined_context (fun term => .kdf other term third) (fun step => .kdfSecond step)
        (induction second)
    | kdfThird second =>
      exact ⟨_, 1, 1, .step (.kdfThird second) .reflexive, .step (.kdfSecond first) .reflexive⟩
  | @kdfThird argument result other middle first induction =>
    cases second with
    | primitive impossible => cases impossible
    | kdfFirst second =>
      exact ⟨_, 1, 1, .step (.kdfFirst second) .reflexive, .step (.kdfThird first) .reflexive⟩
    | kdfSecond second =>
      exact ⟨_, 1, 1, .step (.kdfSecond second) .reflexive, .step (.kdfThird first) .reflexive⟩
    | kdfThird second =>
      exact joined_context (fun term => .kdf other middle term) (fun step => .kdfThird step)
        (induction second)
  | @naturalLeft argument result other first induction =>
    cases second with
    | primitive impossible => cases impossible
    | naturalLeft second =>
      exact joined_context (fun term => .naturalAdd term other) (fun step => .naturalLeft step)
        (induction second)
    | naturalRight second =>
      exact ⟨_, 1, 1, .step (.naturalRight second) .reflexive,
        .step (.naturalLeft first) .reflexive⟩
  | @naturalRight argument result other first induction =>
    cases second with
    | primitive impossible => cases impossible
    | naturalLeft second =>
      exact ⟨_, 1, 1, .step (.naturalLeft second) .reflexive,
        .step (.naturalRight first) .reflexive⟩
    | naturalRight second =>
      exact joined_context (fun term => .naturalAdd other term) (fun step => .naturalRight step)
        (induction second)
  | @list argument result first induction =>
    cases second with
    | primitive impossible => cases impossible
    | list second =>
      exact joined_context NativeQueryTerm.list (fun step => .list step) (induction second)
  | @consLeft argument result other first induction =>
    cases second with
    | primitive impossible => cases impossible
    | consLeft second =>
      exact joined_context (fun term => .cons term other) (fun step => .consLeft step)
        (induction second)
    | consRight second =>
      exact ⟨_, 1, 1, .step (.consRight second) .reflexive, .step (.consLeft first) .reflexive⟩
  | @consRight argument result other first induction =>
    cases second with
    | primitive impossible => cases impossible
    | consLeft second =>
      exact ⟨_, 1, 1, .step (.consLeft second) .reflexive, .step (.consRight first) .reflexive⟩
    | consRight second =>
      exact joined_context (fun term => .cons other term) (fun step => .consRight step)
        (induction second)

theorem native_sorted_steps_count_bound (steps : NativeSortedSteps left count right) :
    nativeQueryFunctionCount right ≤ nativeQueryFunctionCount left := by
  induction steps with
  | reflexive => exact Nat.le_refl _
  | step rewrite _ induction =>
    have decreasing := native_sorted_rewrite_decreases_count rewrite
    omega

theorem native_sorted_matching_confluence (first : NativeSortedSteps term firstCount left)
    (second : NativeSortedSteps term secondCount right) : NativeSortedJoinable left right := by
  generalize countEquality : nativeQueryFunctionCount term = size
  induction size using Nat.strongRecOn generalizing term left right firstCount secondCount with
  | ind size induction =>
    cases first with
    | reflexive => exact ⟨_, _, 0, second, .reflexive⟩
    | @step initial firstMiddle firstCount left firstStep firstRest =>
      cases second with
      | reflexive => exact ⟨_, 0, _, .reflexive, .step firstStep firstRest⟩
      | @step initial secondMiddle secondCount right secondStep secondRest =>
        obtain ⟨peak, _, _, firstPeak, secondPeak⟩ :=
          native_sorted_local_confluence firstStep secondStep
        have firstLower := native_sorted_rewrite_decreases_count firstStep
        have secondLower := native_sorted_rewrite_decreases_count secondStep
        obtain ⟨firstJoin, leftCount, _, leftJoin, peakFirstJoin⟩ :=
          induction (nativeQueryFunctionCount firstMiddle) (by omega) firstRest firstPeak rfl
        obtain ⟨secondJoin, rightCount, _, rightJoin, peakSecondJoin⟩ :=
          induction (nativeQueryFunctionCount secondMiddle) (by omega) secondRest secondPeak rfl
        have peakBound := native_sorted_steps_count_bound firstPeak
        obtain ⟨result, firstFinalCount, secondFinalCount, firstFinal, secondFinal⟩ :=
          induction (nativeQueryFunctionCount peak) (by omega) peakFirstJoin peakSecondJoin rfl
        exact ⟨result, leftCount + firstFinalCount, rightCount + secondFinalCount,
          native_sorted_steps_transitive leftJoin firstFinal,
          native_sorted_steps_transitive rightJoin secondFinal⟩

#print axioms native_sorted_rewrite_decreases_count
#print axioms native_sorted_termination
#print axioms native_sorted_local_confluence
#print axioms native_sorted_steps_count_bound
#print axioms native_sorted_matching_confluence

end Cairn.Equations
