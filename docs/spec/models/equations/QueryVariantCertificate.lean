import QueryVariants
import QueryNormalization
import QuerySyntacticUnification

namespace Cairn.Equations

/-! Certificates for a backend's `get variants` reply.

A reply is a family of pairs `(value, general)`. Each member is checked against the executable
normal form of its instance, and the family is checked against every variant scheme whose system
the verified syntactic unifier solves with a normal instance of the scheme value: some member must
generalize the most general unifier and that value. A scheme whose general value instance still
rewrites stays reducible in every sorted instance, so it never yields a normal form. If no scheme
is `unsupported`, the check gives Escobar-Meseguer completeness for every sorted normalized
instance. -/

abbrev NativeVariantMember : Type := NativeQueryTerm × (QuerySort → Nat → NativeQueryTerm)

-- The matcher pairs a member must solve to generalize a scheme's most general unifier.
def nativeVariantCoverPairs (term : NativeQueryTerm) (member : NativeVariantMember)
    (scheme : NativeVariantScheme) (bindings : NativeBindingList) :
    List (NativeQueryTerm × NativeQueryTerm) :=
  (nativeQueryVariables term).map (fun key => (member.2 key.1 key.2, nativeBindingAssignment bindings key.1 key.2))
    ++ [(member.1, substituteNativeQuery (nativeBindingAssignment bindings) scheme.1)]

def nativeVariantSchemeResults (term : NativeQueryTerm) :
    List (NativeVariantScheme × NativeSyntacticResult) :=
  (nativeVariantSchemes term (nativeFreshBase term)).map fun scheme =>
    (scheme, nativeSyntacticUnify nativeSyntacticFuel (nativeVariantSystem term scheme))

private theorem fold_bound : ∀ (entries : List (QuerySort × Nat)) (entry : QuerySort × Nat),
    entry ∈ entries → entry.2 < entries.foldr (fun entry bound => max (entry.2 + 1) bound) 0
  | [], _, inside => by simp at inside
  | head :: rest, entry, inside => by
    rcases List.mem_cons.1 inside with rfl | inside
    · simp only [List.foldr]
      omega
    · have := fold_bound rest entry inside
      simp only [List.foldr]
      omega

private theorem fresh_base : NativeFreshBelow term (nativeFreshBase term) :=
  fun entry inside _ => fold_bound _ entry inside

private theorem system_solved (solved : NativeACSystemUnifier scheme.2.1 assignment) :
    NativeACSystemUnifier (nativeVariantSystem term scheme) assignment := by
  refine ⟨solved.1, fun equation member => ?_⟩
  simp only [nativeVariantSystem, List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with member | rfl | rfl
  · exact solved.2 equation member
  · exact .reflexive
  · exact .reflexive

private theorem system_term (inside : entry ∈ nativeQueryVariables term) :
    entry ∈ nativeSystemVariables (nativeVariantSystem term scheme) := by
  simp [nativeVariantSystem, nativeSystemVariables, inside]

private theorem system_value (inside : entry ∈ nativeQueryVariables scheme.1) :
    entry ∈ nativeSystemVariables (nativeVariantSystem term scheme) := by
  simp [nativeVariantSystem, nativeSystemVariables, inside]

private theorem normal_equal (normal : NativeSortedNormal term) :
    nativeACEqual term (nativeSortedNormalize term) = true := by
  obtain ⟨⟨_, steps⟩, _⟩ := native_sorted_normalize_spec term
  generalize nativeSortedNormalize term = result at steps ⊢
  cases steps with
  | reflexive => exact native_ac_equal_iff.2 .reflexive
  | step first _ => exact absurd first (normal _)

/-- A member whose value is AC-equal to the executable normal form of its instance is a normal
reduct of that instance. -/
theorem native_variant_member_sound
    (equal : nativeACEqual value (nativeSortedNormalize (substituteNativeQuery general term)) = true) :
    ∃ count normal, NativeSortedSteps (substituteNativeQuery general term) count normal ∧
      NativeSortedNormal normal ∧ NativeQueryAC normal value := by
  obtain ⟨⟨count, steps⟩, normal⟩ := native_sorted_normalize_spec (substituteNativeQuery general term)
  exact ⟨count, _, steps, normal, .symmetric (native_ac_equal_iff.1 equal)⟩

/-- If every scheme is decided and each solved scheme with a normal general value instance is
generalized by some member, the family covers every sorted normalized instance of the term,
together with its normal form. -/
theorem native_variant_family_complete {family : List NativeVariantMember}
    (decided : ∀ entry ∈ nativeVariantSchemeResults term, entry.2 ≠ .unsupported)
    (covered : ∀ entry ∈ nativeVariantSchemeResults term, ∀ bindings, entry.2 = .solved bindings →
      nativeACEqual (substituteNativeQuery (nativeBindingAssignment bindings) entry.1.1)
        (nativeSortedNormalize (substituteNativeQuery (nativeBindingAssignment bindings) entry.1.1)) = true →
      ∃ member ∈ family, ∃ factor, NativeACMatcher (nativeVariantCoverPairs term member entry.1 bindings) factor)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment) :
    ∃ member ∈ family, ∃ factor, NativeSortedAssignment factor ∧
      NativeAssignmentACOn (nativeQueryVariables term) assignment (composeNativeAssignments member.2 factor) ∧
      ∃ count normalForm, NativeSortedSteps (substituteNativeQuery assignment term) count normalForm ∧
        NativeSortedNormal normalForm ∧ NativeQueryAC normalForm (substituteNativeQuery factor member.1) := by
  obtain ⟨scheme, extended, schemeMember, _, _, agree, solved, count, normalForm, steps, normal,
    equivalent⟩ := native_variant_schemes_cover sorted normalized (fresh_base (term := term))
  have entryMember : (scheme, nativeSyntacticUnify nativeSyntacticFuel (nativeVariantSystem term scheme)) ∈
      nativeVariantSchemeResults term := List.mem_map.2 ⟨scheme, schemeMember, rfl⟩
  have spec := native_syntactic_unify_spec nativeSyntacticFuel (nativeVariantSystem term scheme)
    (nativeSystemVariables (nativeVariantSystem term scheme))
  have systemSolved := system_solved (term := term) solved
  cases result : nativeSyntacticUnify nativeSyntacticFuel (nativeVariantSystem term scheme) with
  | unsupported => exact absurd result (decided _ entryMember)
  | failed =>
    rw [result] at spec
    obtain ⟨_, inside, _⟩ := spec.2 extended systemSolved
    simp at inside
  | solved bindings =>
    rw [result] at spec entryMember
    obtain ⟨_, inside, residual, residualSorted, instanceAC⟩ := spec.2 extended systemSolved
    rw [List.mem_singleton] at inside
    subst inside
    have schemeAC : NativeQueryAC (substituteNativeQuery extended scheme.1)
        (substituteNativeQuery residual (substituteNativeQuery (nativeBindingAssignment bindings) scheme.1)) := by
      rw [native_substitution_composition]
      exact native_substitution_assignment_ac_on fun sort index inside =>
        instanceAC sort index (system_value inside)
    have generalNormal : NativeSortedNormal
        (substituteNativeQuery (nativeBindingAssignment bindings) scheme.1) := fun result step =>
      native_sorted_query_normal_ac_invariant (.transitive equivalent schemeAC) normal _
        (native_sorted_rewrite_substitution residualSorted step)
    obtain ⟨member, memberInside, factor, factorSorted, pairs⟩ :=
      covered _ entryMember bindings rfl (normal_equal generalNormal)
    have keyAC : ∀ key ∈ nativeQueryVariables term, NativeQueryAC
        (substituteNativeQuery factor (member.2 key.1 key.2)) (nativeBindingAssignment bindings key.1 key.2) :=
      fun key inside => pairs _ (List.mem_append_left _ (List.mem_map.2 ⟨key, inside, rfl⟩))
    have valueAC : NativeQueryAC (substituteNativeQuery factor member.1)
        (substituteNativeQuery (nativeBindingAssignment bindings) scheme.1) :=
      pairs (member.1, _) (List.mem_append_right _ (List.mem_singleton.2 rfl))
    refine ⟨member, memberInside, composeNativeAssignments factor residual,
      native_sorted_composition factorSorted residualSorted, fun sort index inside => ?_,
      count, normalForm, steps, normal, ?_⟩
    · have same : extended sort index = assignment sort index :=
        agree sort index fun message => .inl (fresh_base (term := term) _ inside message)
      rw [← same, composeNativeAssignments, ← native_substitution_composition]
      exact .transitive (instanceAC sort index (system_term inside))
        (native_ac_substitution residual (.symmetric (keyAC (sort, index) inside)))
    · rw [← native_substitution_composition]
      exact .transitive equivalent (.transitive schemeAC (native_ac_substitution residual (.symmetric valueAC)))

#print axioms native_variant_member_sound
#print axioms native_variant_family_complete

end Cairn.Equations
