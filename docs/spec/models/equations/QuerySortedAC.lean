import QuerySortedGlobal

namespace Cairn.Equations

theorem native_query_ac_preserves_count (equivalent : NativeQueryAC left right) :
    nativeQueryFunctionCount left = nativeQueryFunctionCount right := by
  induction equivalent <;> simp_all only [nativeQueryFunctionCount] <;> omega

private def SortedTransport (left right : NativeQueryTerm) : Prop :=
  ∀ {target}, NativeSortedRewrite left target →
    ∃ result, NativeSortedRewrite right result ∧ NativeQueryAC target result

private theorem transport_primitive (step : NativeSortedPrimitiveRewrite left target)
    (equivalent : NativeQueryAC left right) :
    ∃ result, NativeSortedRewrite right result ∧ NativeQueryAC target result := by
  obtain ⟨source, _, _, encoding, _⟩ := native_sorted_primitive_image step
  have decoded : decodeNativeMessage left = some source := by
    rw [← encoding]
    exact native_message_round_trip _
  exact native_sorted_ac_coherent (.primitive step) decoded equivalent

private theorem transport_transitive (first : SortedTransport left middle)
    (second : SortedTransport middle right) : SortedTransport left right := by
  intro target step
  obtain ⟨_, firstStep, firstAC⟩ := first step
  obtain ⟨_, secondStep, secondAC⟩ := second firstStep
  exact ⟨_, secondStep, .transitive firstAC secondAC⟩

private theorem transport_unary (equivalent : NativeQueryAC left right)
    (transport : SortedTransport left right) :
    SortedTransport (.unary symbol left) (.unary symbol right) := by
  intro target step
  cases step with
  | primitive root => exact transport_primitive root (.unary equivalent)
  | unary inside =>
    obtain ⟨_, copied, resultAC⟩ := transport inside
    exact ⟨_, .unary copied, .unary resultAC⟩

private theorem transport_binary (firstAC : NativeQueryAC firstLeft firstRight)
    (secondAC : NativeQueryAC secondLeft secondRight)
    (first : SortedTransport firstLeft firstRight)
    (second : SortedTransport secondLeft secondRight) :
    SortedTransport (.binary symbol firstLeft secondLeft) (.binary symbol firstRight secondRight) := by
  intro target step
  cases step with
  | primitive root => exact transport_primitive root (.binary firstAC secondAC)
  | binaryLeft inside =>
    obtain ⟨_, copied, resultAC⟩ := first inside
    exact ⟨_, .binaryLeft copied, .binary resultAC secondAC⟩
  | binaryRight inside =>
    obtain ⟨_, copied, resultAC⟩ := second inside
    exact ⟨_, .binaryRight copied, .binary firstAC resultAC⟩

private theorem transport_kdf (firstAC : NativeQueryAC firstLeft firstRight)
    (secondAC : NativeQueryAC secondLeft secondRight)
    (thirdAC : NativeQueryAC thirdLeft thirdRight)
    (first : SortedTransport firstLeft firstRight)
    (second : SortedTransport secondLeft secondRight)
    (third : SortedTransport thirdLeft thirdRight) :
    SortedTransport (.kdf firstLeft secondLeft thirdLeft)
      (.kdf firstRight secondRight thirdRight) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | kdfFirst inside =>
    obtain ⟨_, copied, resultAC⟩ := first inside
    exact ⟨_, .kdfFirst copied, .kdf resultAC secondAC thirdAC⟩
  | kdfSecond inside =>
    obtain ⟨_, copied, resultAC⟩ := second inside
    exact ⟨_, .kdfSecond copied, .kdf firstAC resultAC thirdAC⟩
  | kdfThird inside =>
    obtain ⟨_, copied, resultAC⟩ := third inside
    exact ⟨_, .kdfThird copied, .kdf firstAC secondAC resultAC⟩

private theorem transport_natural (firstAC : NativeQueryAC firstLeft firstRight)
    (secondAC : NativeQueryAC secondLeft secondRight)
    (first : SortedTransport firstLeft firstRight)
    (second : SortedTransport secondLeft secondRight) :
    SortedTransport (.naturalAdd firstLeft secondLeft) (.naturalAdd firstRight secondRight) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | naturalLeft inside =>
    obtain ⟨_, copied, resultAC⟩ := first inside
    exact ⟨_, .naturalLeft copied, .naturalAdd resultAC secondAC⟩
  | naturalRight inside =>
    obtain ⟨_, copied, resultAC⟩ := second inside
    exact ⟨_, .naturalRight copied, .naturalAdd firstAC resultAC⟩

private theorem transport_list (transport : SortedTransport left right) :
    SortedTransport (.list left) (.list right) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | list inside =>
    obtain ⟨_, copied, resultAC⟩ := transport inside
    exact ⟨_, .list copied, .list resultAC⟩

private theorem transport_cons (firstAC : NativeQueryAC firstLeft firstRight)
    (secondAC : NativeQueryAC secondLeft secondRight)
    (first : SortedTransport firstLeft firstRight)
    (second : SortedTransport secondLeft secondRight) :
    SortedTransport (.cons firstLeft secondLeft) (.cons firstRight secondRight) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | consLeft inside =>
    obtain ⟨_, copied, resultAC⟩ := first inside
    exact ⟨_, .consLeft copied, .cons resultAC secondAC⟩
  | consRight inside =>
    obtain ⟨_, copied, resultAC⟩ := second inside
    exact ⟨_, .consRight copied, .cons firstAC resultAC⟩

private theorem transport_associative :
    SortedTransport (.naturalAdd (.naturalAdd first second) third)
      (.naturalAdd first (.naturalAdd second third)) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | naturalLeft inside =>
    cases inside with
    | primitive impossible => cases impossible
    | naturalLeft rewrite => exact ⟨_, .naturalLeft rewrite, .associative⟩
    | naturalRight rewrite => exact ⟨_, .naturalRight (.naturalLeft rewrite), .associative⟩
  | naturalRight rewrite => exact ⟨_, .naturalRight (.naturalRight rewrite), .associative⟩

private theorem transport_associative_reverse :
    SortedTransport (.naturalAdd first (.naturalAdd second third))
      (.naturalAdd (.naturalAdd first second) third) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | naturalLeft rewrite => exact ⟨_, .naturalLeft (.naturalLeft rewrite), .symmetric .associative⟩
  | naturalRight inside =>
    cases inside with
    | primitive impossible => cases impossible
    | naturalLeft rewrite =>
      exact ⟨_, .naturalLeft (.naturalRight rewrite), .symmetric .associative⟩
    | naturalRight rewrite => exact ⟨_, .naturalRight rewrite, .symmetric .associative⟩

private theorem transport_commutative :
    SortedTransport (.naturalAdd left right) (.naturalAdd right left) := by
  intro target step
  cases step with
  | primitive impossible => cases impossible
  | naturalLeft rewrite => exact ⟨_, .naturalRight rewrite, .commutative⟩
  | naturalRight rewrite => exact ⟨_, .naturalLeft rewrite, .commutative⟩

-- Symmetry needs both directions even when the induction conclusion is forward.
private theorem transport_both (equivalent : NativeQueryAC left right) :
    SortedTransport left right ∧ SortedTransport right left := by
  induction equivalent with
  | reflexive =>
    exact ⟨fun step => ⟨_, step, .reflexive⟩, fun step => ⟨_, step, .reflexive⟩⟩
  | symmetric _ induction => exact ⟨induction.2, induction.1⟩
  | transitive _ _ first second =>
    exact ⟨transport_transitive first.1 second.1, transport_transitive second.2 first.2⟩
  | associative => exact ⟨transport_associative, transport_associative_reverse⟩
  | commutative => exact ⟨transport_commutative, transport_commutative⟩
  | naturalAdd firstAC secondAC first second =>
    exact ⟨transport_natural firstAC secondAC first.1 second.1,
      transport_natural (.symmetric firstAC) (.symmetric secondAC) first.2 second.2⟩
  | unary equivalent induction =>
    exact ⟨transport_unary equivalent induction.1,
      transport_unary (.symmetric equivalent) induction.2⟩
  | binary firstAC secondAC first second =>
    exact ⟨transport_binary firstAC secondAC first.1 second.1,
      transport_binary (.symmetric firstAC) (.symmetric secondAC) first.2 second.2⟩
  | kdf firstAC secondAC thirdAC first second third =>
    exact ⟨transport_kdf firstAC secondAC thirdAC first.1 second.1 third.1,
      transport_kdf (.symmetric firstAC) (.symmetric secondAC) (.symmetric thirdAC)
        first.2 second.2 third.2⟩
  | list _ induction => exact ⟨transport_list induction.1, transport_list induction.2⟩
  | cons firstAC secondAC first second =>
    exact ⟨transport_cons firstAC secondAC first.1 second.1,
      transport_cons (.symmetric firstAC) (.symmetric secondAC) first.2 second.2⟩

theorem native_sorted_query_ac_coherent (step : NativeSortedRewrite first second)
    (equivalent : NativeQueryAC first third) :
    ∃ result, NativeSortedRewrite third result ∧ NativeQueryAC second result :=
  (transport_both equivalent).1 step

#print axioms native_query_ac_preserves_count
#print axioms native_sorted_query_ac_coherent

end Cairn.Equations
