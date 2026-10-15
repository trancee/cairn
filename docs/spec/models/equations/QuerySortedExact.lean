import QuerySortedBoundedness

namespace Cairn.Equations

theorem native_sorted_primitive_image (step : NativeSortedPrimitiveRewrite left right) :
    ∃ source target, MatchingPrimitiveRewrite source target ∧
      encodeNativeMessage source = left ∧ encodeNativeMessage target = right := by
  cases step with
  | flipA => exact ⟨_, _, .flipA, rfl, rfl⟩
  | flipB => exact ⟨_, _, .flipB, rfl, rfl⟩
  | fst first second =>
    obtain ⟨firstTerm, firstDecoded⟩ := first
    obtain ⟨secondTerm, secondDecoded⟩ := second
    have firstEncoding := native_message_recognition _ firstDecoded
    have secondEncoding := native_message_recognition _ secondDecoded
    exact ⟨.unary .fst (.binary .pair firstTerm secondTerm), firstTerm, .fst,
      by simp only [encodeNativeMessage, firstEncoding, secondEncoding],
      firstEncoding⟩
  | snd first second =>
    obtain ⟨firstTerm, firstDecoded⟩ := first
    obtain ⟨secondTerm, secondDecoded⟩ := second
    have firstEncoding := native_message_recognition _ firstDecoded
    have secondEncoding := native_message_recognition _ secondDecoded
    exact ⟨.unary .snd (.binary .pair firstTerm secondTerm), secondTerm, .snd,
      by simp only [encodeNativeMessage, firstEncoding, secondEncoding],
      secondEncoding⟩
  | sdec payload first equivalent =>
    obtain ⟨payloadTerm, payloadDecoded⟩ := payload
    obtain ⟨firstTerm, firstDecoded⟩ := first
    obtain ⟨secondTerm, secondDecoded, keys⟩ := native_ac_message_image equivalent firstDecoded
    have payloadEncoding := native_message_recognition _ payloadDecoded
    have firstEncoding := native_message_recognition _ firstDecoded
    have secondEncoding := native_message_recognition _ secondDecoded
    exact ⟨_, _, .sdec keys,
      by simp only [encodeNativeMessage, payloadEncoding, firstEncoding, secondEncoding],
      payloadEncoding⟩
  | kdec payload first equivalent =>
    obtain ⟨payloadTerm, payloadDecoded⟩ := payload
    obtain ⟨firstTerm, firstDecoded⟩ := first
    obtain ⟨secondTerm, secondDecoded, keys⟩ := native_ac_message_image equivalent firstDecoded
    have payloadEncoding := native_message_recognition _ payloadDecoded
    have firstEncoding := native_message_recognition _ firstDecoded
    have secondEncoding := native_message_recognition _ secondDecoded
    exact ⟨_, _, .kdec keys,
      by simp only [encodeNativeMessage, payloadEncoding, firstEncoding, secondEncoding],
      payloadEncoding⟩

private theorem natural_has_no_sorted_rewrite (step : NativeSortedRewrite left right)
    (decoded : decodeNativeNatural left = some term) : False := by
  have messageDecoded : decodeNativeMessage left = some (.natural term) := by
    rw [← native_natural_recognition left decoded]
    exact native_message_round_trip (.natural term)
  obtain ⟨_, rewrite, _⟩ := native_sorted_rewrite_decode step messageDecoded
  obtain ⟨_, matching, _⟩ := modulo_ac_matching_coherence rewrite
  cases matching with
  | primitive impossible => cases impossible

theorem native_sorted_rewrite_matching_decode (step : NativeSortedRewrite left right)
    (decoded : decodeNativeMessage left = some term) :
    ∃ result, MatchingRewrite term result ∧ decodeNativeMessage right = some result := by
  induction step generalizing term with
  | primitive root =>
    obtain ⟨source, target, matching, sourceEncoding, targetEncoding⟩ :=
      native_sorted_primitive_image root
    rw [← sourceEncoding, native_message_round_trip] at decoded
    have equality := Option.some.inj decoded
    subst term
    exact ⟨target, .primitive matching,
      by rw [← targetEncoding]; exact native_message_round_trip _⟩
  | @unary left right symbol step induction =>
    cases child : decodeNativeMessage left <;> simp [decodeNativeMessage, child] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction child
    exact ⟨_, .unary rewrite, by simp [decodeNativeMessage, resultDecoded]⟩
  | @binaryLeft left right symbol other step induction =>
    cases first : decodeNativeMessage left <;> cases second : decodeNativeMessage other <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction first
    exact ⟨_, .binaryLeft rewrite, by simp [decodeNativeMessage, resultDecoded, second]⟩
  | @binaryRight left right symbol other step induction =>
    cases first : decodeNativeMessage other <;> cases second : decodeNativeMessage left <;>
      simp [decodeNativeMessage, first, second] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction second
    exact ⟨_, .binaryRight rewrite, by simp [decodeNativeMessage, first, resultDecoded]⟩
  | @kdfFirst left right second third step induction =>
    cases firstValue : decodeNativeMessage left <;>
      cases secondValue : decodeNativeMessage second <;>
      cases thirdValue : decodeNativeMessage third <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction firstValue
    exact ⟨_, .kdfFirst rewrite, by simp [decodeNativeMessage, resultDecoded, secondValue, thirdValue]⟩
  | @kdfSecond left right first third step induction =>
    cases firstValue : decodeNativeMessage first <;>
      cases secondValue : decodeNativeMessage left <;>
      cases thirdValue : decodeNativeMessage third <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction secondValue
    exact ⟨_, .kdfSecond rewrite, by simp [decodeNativeMessage, firstValue, resultDecoded, thirdValue]⟩
  | @kdfThird left right first second step induction =>
    cases firstValue : decodeNativeMessage first <;>
      cases secondValue : decodeNativeMessage second <;>
      cases thirdValue : decodeNativeMessage left <;>
      simp [decodeNativeMessage, firstValue, secondValue, thirdValue] at decoded
    subst term
    obtain ⟨result, rewrite, resultDecoded⟩ := induction thirdValue
    exact ⟨_, .kdfThird rewrite, by simp [decodeNativeMessage, firstValue, secondValue, resultDecoded]⟩
  | @naturalLeft left right other step induction =>
    cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural other <;>
      simp [decodeNativeMessage, first, second] at decoded
    exact False.elim (natural_has_no_sorted_rewrite step first)
  | @naturalRight left right other step induction =>
    cases first : decodeNativeNatural other <;> cases second : decodeNativeNatural left <;>
      simp [decodeNativeMessage, first, second] at decoded
    exact False.elim (natural_has_no_sorted_rewrite step second)
  | list | consLeft | consRight => simp [decodeNativeMessage] at decoded

theorem native_sorted_steps_matching_decode (steps : NativeSortedSteps first count second)
    (decoded : decodeNativeMessage first = some term) :
    ∃ result, MatchingSteps term count result ∧ decodeNativeMessage second = some result := by
  induction steps generalizing term with
  | reflexive => exact ⟨_, .reflexive, decoded⟩
  | step rewrite _ induction =>
    obtain ⟨middle, first, middleDecoded⟩ := native_sorted_rewrite_matching_decode rewrite decoded
    obtain ⟨result, rest, resultDecoded⟩ := induction middleDecoded
    exact ⟨result, .step first rest, resultDecoded⟩

def NativeSortedJoinable (left right : NativeQueryTerm) : Prop :=
  ∃ result leftCount rightCount,
    NativeSortedSteps left leftCount result ∧ NativeSortedSteps right rightCount result

theorem native_sorted_proper_confluence_exact (first : NativeSortedSteps term firstCount left)
    (second : NativeSortedSteps term secondCount right)
    (decoded : decodeNativeMessage term = some source) : NativeSortedJoinable left right := by
  obtain ⟨leftSource, leftSteps, leftDecoded⟩ := native_sorted_steps_matching_decode first decoded
  obtain ⟨rightSource, rightSteps, rightDecoded⟩ := native_sorted_steps_matching_decode second decoded
  obtain ⟨result, leftCount, rightCount, leftJoin, rightJoin⟩ :=
    matching_confluence leftSteps rightSteps
  refine ⟨encodeNativeMessage result, leftCount, rightCount, ?_, ?_⟩
  · rw [← native_message_recognition left leftDecoded]
    exact native_sorted_steps_preservation leftJoin
  · rw [← native_message_recognition right rightDecoded]
    exact native_sorted_steps_preservation rightJoin

#print axioms native_sorted_primitive_image
#print axioms native_sorted_rewrite_matching_decode
#print axioms native_sorted_steps_matching_decode
#print axioms native_sorted_proper_confluence_exact

end Cairn.Equations
