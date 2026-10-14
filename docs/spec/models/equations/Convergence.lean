import Confluence

namespace Cairn.Equations

theorem normal_ac_invariant (equivalent : MessageAC left right) (normal : Normal left) :
    Normal right := by
  intro result step
  obtain ⟨other, copied, _⟩ := matching_rewrite_ac_coherent step (.symmetric equivalent)
  exact normal other copied

theorem matching_steps_ac_coherent (steps : MatchingSteps first count second)
    (equivalent : MessageAC first third) :
    ∃ result, MatchingSteps third count result ∧ MessageAC second result := by
  induction steps generalizing third with
  | reflexive => exact ⟨_, .reflexive, equivalent⟩
  | step rewrite _ induction =>
    obtain ⟨middle, copied, middleAC⟩ := matching_rewrite_ac_coherent rewrite equivalent
    obtain ⟨result, rest, resultAC⟩ := induction middleAC
    exact ⟨result, .step copied rest, resultAC⟩

private theorem normal_steps_identity (normal : Normal left)
    (steps : MatchingSteps left count right) : left = right := by
  cases steps with
  | reflexive => rfl
  | step rewrite _ => exact False.elim (normal _ rewrite)

theorem matching_normal_forms_unique (first : MatchingSteps term firstCount left)
    (second : MatchingSteps term secondCount right)
    (leftNormal : Normal left) (rightNormal : Normal right) : left = right := by
  obtain ⟨result, _, _, firstJoin, secondJoin⟩ := matching_confluence first second
  exact (normal_steps_identity leftNormal firstJoin).trans
    (normal_steps_identity rightNormal secondJoin).symm

inductive ModuloACSteps : MessageTerm → Nat → MessageTerm → Prop where
  | reflexive : ModuloACSteps term 0 term
  | step : ModuloACRewrite first second → ModuloACSteps second count third →
      ModuloACSteps first (count + 1) third

theorem modulo_ac_steps_matching (steps : ModuloACSteps first count second) :
    ∃ result, MatchingSteps first count result ∧ MessageAC result second := by
  induction steps with
  | reflexive => exact ⟨_, .reflexive, .reflexive⟩
  | step rewrite _ induction =>
    obtain ⟨middle, matching, middleAC⟩ := modulo_ac_matching_coherence rewrite
    obtain ⟨target, rest, targetAC⟩ := induction
    obtain ⟨result, copied, resultAC⟩ := matching_steps_ac_coherent rest (.symmetric middleAC)
    exact ⟨result, .step matching copied, .transitive (.symmetric resultAC) targetAC⟩

theorem modulo_ac_confluence (first : ModuloACSteps term firstCount left)
    (second : ModuloACSteps term secondCount right) :
    ∃ leftResult rightResult leftCount rightCount,
      MatchingSteps left leftCount leftResult ∧
      MatchingSteps right rightCount rightResult ∧ MessageAC leftResult rightResult := by
  obtain ⟨firstTarget, firstSteps, firstAC⟩ := modulo_ac_steps_matching first
  obtain ⟨secondTarget, secondSteps, secondAC⟩ := modulo_ac_steps_matching second
  obtain ⟨common, leftCount, rightCount, firstJoin, secondJoin⟩ :=
    matching_confluence firstSteps secondSteps
  obtain ⟨leftResult, leftJoin, leftAC⟩ := matching_steps_ac_coherent firstJoin firstAC
  obtain ⟨rightResult, rightJoin, rightAC⟩ := matching_steps_ac_coherent secondJoin secondAC
  exact ⟨leftResult, rightResult, leftCount, rightCount, leftJoin, rightJoin,
    .transitive (.symmetric leftAC) rightAC⟩

#print axioms normal_ac_invariant
#print axioms matching_steps_ac_coherent
#print axioms matching_normal_forms_unique
#print axioms modulo_ac_steps_matching
#print axioms modulo_ac_confluence

end Cairn.Equations
