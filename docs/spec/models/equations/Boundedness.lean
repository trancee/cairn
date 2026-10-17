import Coherence

namespace Cairn.Equations

inductive MatchingSteps : MessageTerm → Nat → MessageTerm → Prop where
  | reflexive : MatchingSteps term 0 term
  | step : MatchingRewrite first second → MatchingSteps second count third →
      MatchingSteps first (count + 1) third

def Normal (term : MessageTerm) : Prop :=
  ∀ result, ¬ MatchingRewrite term result

theorem matching_steps_transitive (first : MatchingSteps left firstCount middle)
    (second : MatchingSteps middle secondCount right) :
    MatchingSteps left (firstCount + secondCount) right := by
  induction first with
  | reflexive => simpa using second
  | step rewrite _ induction =>
    simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using
      MatchingSteps.step rewrite (induction second)

theorem matching_steps_context (context : MessageTerm → MessageTerm)
    (preserves : ∀ {left right}, MatchingRewrite left right →
      MatchingRewrite (context left) (context right))
    (steps : MatchingSteps left count right) :
    MatchingSteps (context left) count (context right) := by
  induction steps with
  | reflexive => exact .reflexive
  | step rewrite _ induction => exact .step (preserves rewrite) induction

private theorem normal_context_argument (context : MessageTerm → MessageTerm)
    (preserves : ∀ {left right}, MatchingRewrite left right →
      MatchingRewrite (context left) (context right))
    (normal : Normal (context argument)) : Normal argument := by
  intro result rewrite
  exact normal _ (preserves rewrite)

private theorem normal_atom : Normal (.atom sort identifier) := by
  intro result rewrite
  cases rewrite with
  | primitive step => cases step

private theorem normal_natural : Normal (.natural term) := by
  intro result rewrite
  cases rewrite with
  | primitive step => cases step

private theorem normal_roleA : Normal .roleA := by
  intro result rewrite
  cases rewrite with
  | primitive step => cases step

private theorem normal_roleB : Normal .roleB := by
  intro result rewrite
  cases rewrite with
  | primitive step => cases step

private def ChildrenNormal : MessageTerm → Prop
  | .atom _ _ | .natural _ | .roleA | .roleB => True
  | .unary _ argument => Normal argument
  | .binary _ left right => Normal left ∧ Normal right
  | .kdf first second third => Normal first ∧ Normal second ∧ Normal third

private theorem ready_without_root_is_normal (ready : ChildrenNormal term)
    (noRoot : ∀ result, ¬ MatchingPrimitiveRewrite term result) : Normal term := by
  intro result rewrite
  cases rewrite with
  | primitive step => exact noRoot _ step
  | unary step => exact ready _ step
  | binaryLeft step => exact ready.1 _ step
  | binaryRight step => exact ready.2 _ step
  | kdfFirst step => exact ready.1 _ step
  | kdfSecond step => exact ready.2.1 _ step
  | kdfThird step => exact ready.2.2 _ step

private theorem ready_root_result_is_normal (ready : ChildrenNormal left)
    (rewrite : MatchingPrimitiveRewrite left right) : Normal right := by
  cases rewrite with
  | flipA => exact normal_roleB
  | flipB => exact normal_roleA
  | @fst left right =>
    exact normal_context_argument (fun argument => .binary .pair argument right)
      (fun step => .binaryLeft step) ready
  | @snd left right =>
    exact normal_context_argument (fun argument => .binary .pair left argument)
      (fun step => .binaryRight step) ready
  | @sdec firstKey secondKey payload equivalent =>
    exact normal_context_argument (fun argument => .binary .senc argument firstKey)
      (fun step => .binaryLeft step) ready.1
  | @kdec firstKey secondKey payload equivalent =>
    exact normal_context_argument (fun argument => .binary .kem argument (.unary .pk firstKey))
      (fun step => .binaryLeft step) ready.1

private theorem ready_normalizes_in_one_step (ready : ChildrenNormal term) :
    ∃ count result, count ≤ 1 ∧ MatchingSteps term count result ∧ Normal result := by
  classical
  by_cases root : ∃ result, MatchingPrimitiveRewrite term result
  · obtain ⟨result, rewrite⟩ := root
    exact ⟨1, result, by omega, .step (.primitive rewrite) .reflexive,
      ready_root_result_is_normal ready rewrite⟩
  · exact ⟨0, term, by omega, .reflexive,
      ready_without_root_is_normal ready (fun result rewrite => root ⟨result, rewrite⟩)⟩

inductive MessageTemplate where
  | messageVariable (identifier : Nat)
  | atom (sort : AtomSort) (identifier : Nat)
  | natural (term : NaturalTerm)
  | roleA
  | roleB
  | unary (symbol : UnarySymbol) (argument : MessageTemplate)
  | binary (symbol : BinarySymbol) (left right : MessageTemplate)
  | kdf (first second third : MessageTemplate)

def instantiateNatural (assignment : Nat → NaturalTerm) : NaturalTerm → NaturalTerm
  | .one => .one
  | .variable identifier => assignment identifier
  | .add left right => .add (instantiateNatural assignment left) (instantiateNatural assignment right)

def instantiateTemplate (messageAssignment : Nat → MessageTerm)
    (naturalAssignment : Nat → NaturalTerm) : MessageTemplate → MessageTerm
  | .messageVariable identifier => messageAssignment identifier
  | .atom sort identifier => .atom sort identifier
  | .natural term => .natural (instantiateNatural naturalAssignment term)
  | .roleA => .roleA
  | .roleB => .roleB
  | .unary symbol argument =>
    .unary symbol (instantiateTemplate messageAssignment naturalAssignment argument)
  | .binary symbol left right =>
    .binary symbol (instantiateTemplate messageAssignment naturalAssignment left)
      (instantiateTemplate messageAssignment naturalAssignment right)
  | .kdf first second third =>
    .kdf (instantiateTemplate messageAssignment naturalAssignment first)
      (instantiateTemplate messageAssignment naturalAssignment second)
      (instantiateTemplate messageAssignment naturalAssignment third)

def templateFunctionCount : MessageTemplate → Nat
  | .messageVariable _ | .atom _ _ | .natural _ | .roleA | .roleB => 0
  | .unary _ argument => templateFunctionCount argument + 1
  | .binary _ left right => templateFunctionCount left + templateFunctionCount right + 1
  | .kdf first second third =>
    templateFunctionCount first + templateFunctionCount second + templateFunctionCount third + 1

theorem normalized_substitution_bound (template : MessageTemplate)
    (messageAssignment : Nat → MessageTerm) (naturalAssignment : Nat → NaturalTerm)
    (normalized : ∀ identifier, Normal (messageAssignment identifier)) :
    ∃ count result, count ≤ templateFunctionCount template ∧
      MatchingSteps (instantiateTemplate messageAssignment naturalAssignment template) count result ∧
      Normal result := by
  induction template with
  | messageVariable identifier =>
    exact ⟨0, _, by simp [templateFunctionCount], .reflexive, normalized _⟩
  | atom => exact ⟨0, _, by simp [templateFunctionCount], .reflexive, normal_atom⟩
  | natural => exact ⟨0, _, by simp [templateFunctionCount], .reflexive, normal_natural⟩
  | roleA => exact ⟨0, _, by simp [templateFunctionCount], .reflexive, normal_roleA⟩
  | roleB => exact ⟨0, _, by simp [templateFunctionCount], .reflexive, normal_roleB⟩
  | unary symbol argument induction =>
    obtain ⟨argumentCount, argumentResult, argumentBound, argumentSteps, argumentNormal⟩ := induction
    obtain ⟨rootCount, result, rootBound, rootSteps, resultNormal⟩ :=
      ready_normalizes_in_one_step (term := .unary symbol argumentResult) argumentNormal
    refine ⟨argumentCount + rootCount, result, ?_, ?_, resultNormal⟩
    · simp only [templateFunctionCount]
      omega
    · exact matching_steps_transitive
        (matching_steps_context (fun term => .unary symbol term) (fun step => .unary step)
          argumentSteps) rootSteps
  | binary symbol left right first second =>
    obtain ⟨leftCount, leftResult, leftBound, leftSteps, leftNormal⟩ := first
    obtain ⟨rightCount, rightResult, rightBound, rightSteps, rightNormal⟩ := second
    obtain ⟨rootCount, result, rootBound, rootSteps, resultNormal⟩ :=
      ready_normalizes_in_one_step (term := .binary symbol leftResult rightResult)
        ⟨leftNormal, rightNormal⟩
    refine ⟨leftCount + rightCount + rootCount, result, ?_, ?_, resultNormal⟩
    · simp only [templateFunctionCount]
      omega
    · exact matching_steps_transitive
        (matching_steps_transitive
          (matching_steps_context
            (fun term => .binary symbol term
              (instantiateTemplate messageAssignment naturalAssignment right))
            (fun step => .binaryLeft step) leftSteps)
          (matching_steps_context (fun term => .binary symbol leftResult term)
            (fun step => .binaryRight step) rightSteps)) rootSteps
  | kdf first second third firstInduction secondInduction thirdInduction =>
    obtain ⟨firstCount, firstResult, firstBound, firstSteps, firstNormal⟩ := firstInduction
    obtain ⟨secondCount, secondResult, secondBound, secondSteps, secondNormal⟩ := secondInduction
    obtain ⟨thirdCount, thirdResult, thirdBound, thirdSteps, thirdNormal⟩ := thirdInduction
    obtain ⟨rootCount, result, rootBound, rootSteps, resultNormal⟩ :=
      ready_normalizes_in_one_step (term := .kdf firstResult secondResult thirdResult)
        ⟨firstNormal, secondNormal, thirdNormal⟩
    refine ⟨firstCount + secondCount + thirdCount + rootCount, result, ?_, ?_, resultNormal⟩
    · simp only [templateFunctionCount]
      omega
    · exact matching_steps_transitive
        (matching_steps_transitive
          (matching_steps_transitive
            (matching_steps_context
              (fun term => .kdf term
                (instantiateTemplate messageAssignment naturalAssignment second)
                (instantiateTemplate messageAssignment naturalAssignment third))
              (fun step => .kdfFirst step) firstSteps)
            (matching_steps_context
              (fun term => .kdf firstResult term
                (instantiateTemplate messageAssignment naturalAssignment third))
              (fun step => .kdfSecond step) secondSteps))
          (matching_steps_context (fun term => .kdf firstResult secondResult term)
            (fun step => .kdfThird step) thirdSteps)) rootSteps

#print axioms matching_steps_transitive
#print axioms matching_steps_context
#print axioms normalized_substitution_bound

end Cairn.Equations
