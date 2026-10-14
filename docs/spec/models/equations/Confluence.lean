import Boundedness

namespace Cairn.Equations

def Joinable (left right : MessageTerm) : Prop :=
  ∃ result leftCount rightCount,
    MatchingSteps left leftCount result ∧ MatchingSteps right rightCount result

private theorem joinable_reflexive (term : MessageTerm) : Joinable term term :=
  ⟨term, 0, 0, .reflexive, .reflexive⟩

private theorem joinable_symmetric (joined : Joinable left right) : Joinable right left := by
  obtain ⟨result, firstCount, secondCount, first, second⟩ := joined
  exact ⟨result, secondCount, firstCount, second, first⟩

private theorem joinable_context (context : MessageTerm → MessageTerm)
    (preserves : ∀ {left right}, MatchingRewrite left right →
      MatchingRewrite (context left) (context right))
    (joined : Joinable left right) : Joinable (context left) (context right) := by
  obtain ⟨result, firstCount, secondCount, first, second⟩ := joined
  exact ⟨context result, firstCount, secondCount,
    matching_steps_context context preserves first, matching_steps_context context preserves second⟩

private theorem primitive_result_unique (first : MatchingPrimitiveRewrite term left)
    (second : MatchingPrimitiveRewrite term right) : left = right := by
  cases first <;> cases second <;> rfl

private theorem primitive_overlap (primitive : MatchingPrimitiveRewrite term left)
    (other : MatchingRewrite term right) : Joinable left right := by
  cases other with
  | primitive second =>
    rw [primitive_result_unique primitive second]
    exact joinable_reflexive _
  | unary inside =>
    cases primitive with
    | flipA =>
      cases inside with
      | primitive impossible => cases impossible
    | flipB =>
      cases inside with
      | primitive impossible => cases impossible
    | fst =>
      cases inside with
      | primitive impossible => cases impossible
      | binaryLeft payloadStep =>
        exact ⟨_, 1, 1, .step payloadStep .reflexive, .step (.primitive .fst) .reflexive⟩
      | binaryRight discarded =>
        exact ⟨_, 0, 1, .reflexive, .step (.primitive .fst) .reflexive⟩
    | snd =>
      cases inside with
      | primitive impossible => cases impossible
      | binaryLeft discarded =>
        exact ⟨_, 0, 1, .reflexive, .step (.primitive .snd) .reflexive⟩
      | binaryRight payloadStep =>
        exact ⟨_, 1, 1, .step payloadStep .reflexive, .step (.primitive .snd) .reflexive⟩
  | binaryLeft inside =>
    cases primitive with
    | sdec keys =>
      cases inside with
      | primitive impossible => cases impossible
      | binaryLeft payloadStep =>
        exact ⟨_, 1, 1, .step payloadStep .reflexive,
          .step (.primitive (.sdec keys)) .reflexive⟩
      | binaryRight keyStep =>
        obtain ⟨newKey, copied, newKeys⟩ := matching_rewrite_ac_coherent keyStep keys
        exact ⟨_, 0, 2, .reflexive,
          .step (.binaryRight copied) (.step (.primitive (.sdec newKeys)) .reflexive)⟩
    | kdec keys =>
      cases inside with
      | primitive impossible => cases impossible
      | binaryLeft payloadStep =>
        exact ⟨_, 1, 1, .step payloadStep .reflexive,
          .step (.primitive (.kdec keys)) .reflexive⟩
      | binaryRight publicKeyStep =>
        cases publicKeyStep with
        | primitive impossible => cases impossible
        | unary keyStep =>
          obtain ⟨newKey, copied, newKeys⟩ := matching_rewrite_ac_coherent keyStep keys
          exact ⟨_, 0, 2, .reflexive,
            .step (.binaryRight copied) (.step (.primitive (.kdec newKeys)) .reflexive)⟩
  | binaryRight keyStep =>
    cases primitive with
    | sdec keys =>
      obtain ⟨newKey, copied, newKeys⟩ := matching_rewrite_ac_coherent keyStep (.symmetric keys)
      exact ⟨_, 0, 2, .reflexive, .step (.binaryLeft (.binaryRight copied))
        (.step (.primitive (.sdec (.symmetric newKeys))) .reflexive)⟩
    | kdec keys =>
      obtain ⟨newKey, copied, newKeys⟩ := matching_rewrite_ac_coherent keyStep (.symmetric keys)
      exact ⟨_, 0, 2, .reflexive, .step (.binaryLeft (.binaryRight (.unary copied)))
        (.step (.primitive (.kdec (.symmetric newKeys))) .reflexive)⟩
  | kdfFirst => cases primitive
  | kdfSecond => cases primitive
  | kdfThird => cases primitive

theorem matching_local_confluence (first : MatchingRewrite term left)
    (second : MatchingRewrite term right) : Joinable left right := by
  induction term generalizing left right with
  | atom =>
    cases first with
    | primitive impossible => cases impossible
  | natural =>
    cases first with
    | primitive impossible => cases impossible
  | roleA =>
    cases first with
    | primitive impossible => cases impossible
  | roleB =>
    cases first with
    | primitive impossible => cases impossible
  | unary symbol argument induction =>
    cases first with
    | primitive first => exact primitive_overlap first second
    | unary first =>
      cases second with
      | primitive second => exact joinable_symmetric (primitive_overlap second (.unary first))
      | unary second =>
        exact joinable_context (fun term => .unary symbol term) (fun step => .unary step)
          (induction first second)
  | binary symbol firstArgument secondArgument firstInduction secondInduction =>
    cases first with
    | primitive first => exact primitive_overlap first second
    | binaryLeft first =>
      cases second with
      | primitive second =>
        exact joinable_symmetric (primitive_overlap second (.binaryLeft first))
      | binaryLeft second =>
        exact joinable_context (fun term => .binary symbol term secondArgument)
          (fun step => .binaryLeft step) (firstInduction first second)
      | binaryRight second =>
        exact ⟨_, 1, 1, .step (.binaryRight second) .reflexive,
          .step (.binaryLeft first) .reflexive⟩
    | binaryRight first =>
      cases second with
      | primitive second =>
        exact joinable_symmetric (primitive_overlap second (.binaryRight first))
      | binaryLeft second =>
        exact ⟨_, 1, 1, .step (.binaryLeft second) .reflexive,
          .step (.binaryRight first) .reflexive⟩
      | binaryRight second =>
        exact joinable_context (fun term => .binary symbol firstArgument term)
          (fun step => .binaryRight step) (secondInduction first second)
  | kdf firstArgument secondArgument thirdArgument firstInduction secondInduction thirdInduction =>
    cases first with
    | primitive impossible => cases impossible
    | kdfFirst first =>
      cases second with
      | primitive impossible => cases impossible
      | kdfFirst second =>
        exact joinable_context (fun term => .kdf term secondArgument thirdArgument)
          (fun step => .kdfFirst step) (firstInduction first second)
      | kdfSecond second =>
        exact ⟨_, 1, 1, .step (.kdfSecond second) .reflexive, .step (.kdfFirst first) .reflexive⟩
      | kdfThird second =>
        exact ⟨_, 1, 1, .step (.kdfThird second) .reflexive, .step (.kdfFirst first) .reflexive⟩
    | kdfSecond first =>
      cases second with
      | primitive impossible => cases impossible
      | kdfFirst second =>
        exact ⟨_, 1, 1, .step (.kdfFirst second) .reflexive, .step (.kdfSecond first) .reflexive⟩
      | kdfSecond second =>
        exact joinable_context (fun term => .kdf firstArgument term thirdArgument)
          (fun step => .kdfSecond step) (secondInduction first second)
      | kdfThird second =>
        exact ⟨_, 1, 1, .step (.kdfThird second) .reflexive, .step (.kdfSecond first) .reflexive⟩
    | kdfThird first =>
      cases second with
      | primitive impossible => cases impossible
      | kdfFirst second =>
        exact ⟨_, 1, 1, .step (.kdfFirst second) .reflexive, .step (.kdfThird first) .reflexive⟩
      | kdfSecond second =>
        exact ⟨_, 1, 1, .step (.kdfSecond second) .reflexive, .step (.kdfThird first) .reflexive⟩
      | kdfThird second =>
        exact joinable_context (fun term => .kdf firstArgument secondArgument term)
          (fun step => .kdfThird step) (thirdInduction first second)

theorem matching_steps_do_not_increase_weight (steps : MatchingSteps left count right) :
    messageWeight right ≤ messageWeight left := by
  induction steps with
  | reflexive => exact Nat.le_refl _
  | step rewrite _ induction =>
    have decreasing := modulo_ac_rewrite_decreases_weight (matching_rewrite_modulo_ac rewrite)
    omega

theorem matching_confluence (first : MatchingSteps term firstCount left)
    (second : MatchingSteps term secondCount right) : Joinable left right := by
  generalize weightEquality : messageWeight term = weight
  induction weight using Nat.strongRecOn generalizing term left right firstCount secondCount with
  | ind weight induction =>
    cases first with
    | reflexive => exact ⟨_, _, 0, second, .reflexive⟩
    | @step initial firstMiddle firstCount left firstStep firstRest =>
      cases second with
      | reflexive => exact ⟨_, 0, _, .reflexive, .step firstStep firstRest⟩
      | @step initial secondMiddle secondCount right secondStep secondRest =>
        obtain ⟨peak, firstPeakCount, secondPeakCount, firstPeak, secondPeak⟩ :=
          matching_local_confluence firstStep secondStep
        have firstLower := modulo_ac_rewrite_decreases_weight (matching_rewrite_modulo_ac firstStep)
        have secondLower := modulo_ac_rewrite_decreases_weight (matching_rewrite_modulo_ac secondStep)
        obtain ⟨firstJoin, leftCount, peakFirstCount, leftJoin, peakFirstJoin⟩ :=
          induction (messageWeight firstMiddle) (by omega) firstRest firstPeak rfl
        obtain ⟨secondJoin, rightCount, peakSecondCount, rightJoin, peakSecondJoin⟩ :=
          induction (messageWeight secondMiddle) (by omega) secondRest secondPeak rfl
        have peakBound := matching_steps_do_not_increase_weight firstPeak
        obtain ⟨result, firstFinalCount, secondFinalCount, firstFinal, secondFinal⟩ :=
          induction (messageWeight peak) (by omega) peakFirstJoin peakSecondJoin rfl
        exact ⟨result, leftCount + firstFinalCount, rightCount + secondFinalCount,
          matching_steps_transitive leftJoin firstFinal, matching_steps_transitive rightJoin secondFinal⟩

#print axioms matching_local_confluence
#print axioms matching_steps_do_not_increase_weight
#print axioms matching_confluence

end Cairn.Equations
