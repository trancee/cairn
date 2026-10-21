import QueryACCanonical
import QuerySortedBoundedness

/-!
Executable innermost normalizer for the native sorted rewrite relation. Children are
normalized first; a node with normal children then rewrites at most once at the root, and
every root rewrite yields a normal subterm. By convergence modulo AC, a `reduce` result is
correct exactly when it is AC-equal to `nativeSortedNormalize` of the query term.
-/

namespace Cairn.Equations

def nativeProperMessage (term : NativeQueryTerm) : Bool :=
  (decodeNativeMessage term).isSome

def nativeRootRewrite : NativeQueryTerm → Option NativeQueryTerm
  | .unary .flip .roleA => some .roleB
  | .unary .flip .roleB => some .roleA
  | .unary .fst (.binary .pair left right) =>
    if nativeProperMessage left && nativeProperMessage right then some left else none
  | .unary .snd (.binary .pair left right) =>
    if nativeProperMessage left && nativeProperMessage right then some right else none
  | .binary .sdec (.binary .senc payload first) second =>
    if nativeProperMessage payload && nativeProperMessage first && nativeACEqual first second
    then some payload else none
  | .binary .kdec (.binary .kem payload (.unary .pk first)) second =>
    if nativeProperMessage payload && nativeProperMessage first && nativeACEqual first second
    then some payload else none
  | _ => none

def nativeRootStep (term : NativeQueryTerm) : NativeQueryTerm :=
  (nativeRootRewrite term).getD term

def nativeSortedNormalize : NativeQueryTerm → NativeQueryTerm
  | .unary symbol argument => nativeRootStep (.unary symbol (nativeSortedNormalize argument))
  | .binary symbol left right =>
    nativeRootStep (.binary symbol (nativeSortedNormalize left) (nativeSortedNormalize right))
  | .kdf first second third =>
    .kdf (nativeSortedNormalize first) (nativeSortedNormalize second) (nativeSortedNormalize third)
  | .naturalAdd left right => .naturalAdd (nativeSortedNormalize left) (nativeSortedNormalize right)
  | .list argument => .list (nativeSortedNormalize argument)
  | .cons first rest => .cons (nativeSortedNormalize first) (nativeSortedNormalize rest)
  | .atom sort index => .atom sort index
  | .naturalAtom index => .naturalAtom index
  | .nodeAtom index => .nodeAtom index
  | .queryVariable sort index => .queryVariable sort index
  | .naturalOne => .naturalOne
  | .roleA => .roleA
  | .roleB => .roleB
  | .nil => .nil

private theorem proper_iff : nativeProperMessage term = true ↔ NativeProperMessage term := by
  simp [nativeProperMessage, NativeProperMessage, Option.isSome_iff_exists]

private theorem root_sound (rewritten : nativeRootRewrite term = some result) :
    NativeSortedPrimitiveRewrite term result := by
  unfold nativeRootRewrite at rewritten
  split at rewritten
  · cases rewritten; exact .flipA
  · cases rewritten; exact .flipB
  · split at rewritten
    · rename_i ready
      simp only [Bool.and_eq_true, proper_iff] at ready
      cases rewritten; exact .fst ready.1 ready.2
    · cases rewritten
  · split at rewritten
    · rename_i ready
      simp only [Bool.and_eq_true, proper_iff] at ready
      cases rewritten; exact .snd ready.1 ready.2
    · cases rewritten
  · split at rewritten
    · rename_i ready
      simp only [Bool.and_eq_true, proper_iff, native_ac_equal_iff] at ready
      cases rewritten; exact .sdec ready.1.1 ready.1.2 ready.2
    · cases rewritten
  · split at rewritten
    · rename_i ready
      simp only [Bool.and_eq_true, proper_iff, native_ac_equal_iff] at ready
      cases rewritten; exact .kdec ready.1.1 ready.1.2 ready.2
    · cases rewritten
  · cases rewritten

private theorem root_complete (rewrite : NativeSortedPrimitiveRewrite term result) :
    nativeRootRewrite term = some result := by
  cases rewrite with
  | flipA | flipB => rfl
  | fst left right =>
    simp [nativeRootRewrite, (proper_iff).mpr left, (proper_iff).mpr right]
  | snd left right =>
    simp [nativeRootRewrite, (proper_iff).mpr left, (proper_iff).mpr right]
  | sdec payload first equivalent =>
    simp [nativeRootRewrite, (proper_iff).mpr payload, (proper_iff).mpr first,
      native_ac_equal_iff.mpr equivalent]
  | kdec payload first equivalent =>
    simp [nativeRootRewrite, (proper_iff).mpr payload, (proper_iff).mpr first,
      native_ac_equal_iff.mpr equivalent]

private theorem normal_argument (context : NativeQueryTerm → NativeQueryTerm)
    (preserves : ∀ {left right}, NativeSortedRewrite left right →
      NativeSortedRewrite (context left) (context right))
    (normal : NativeSortedNormal (context argument)) : NativeSortedNormal argument :=
  fun _ rewrite => normal _ (preserves rewrite)

private theorem pair_left (normal : NativeSortedNormal (.binary symbol left right)) :
    NativeSortedNormal left :=
  normal_argument (fun term => .binary symbol term right) (fun step => .binaryLeft step) normal

private theorem pair_right (normal : NativeSortedNormal (.binary symbol left right)) :
    NativeSortedNormal right :=
  normal_argument (fun term => .binary symbol left term) (fun step => .binaryRight step) normal

private theorem role_a_normal : NativeSortedNormal .roleA := by
  intro result step
  cases step with
  | primitive rewrite => cases rewrite

private theorem role_b_normal : NativeSortedNormal .roleB := by
  intro result step
  cases step with
  | primitive rewrite => cases rewrite

-- A node with normal children rewrites at most once at the root, to a normal result.
private theorem root_step
    (rootNormal : ∀ result, NativeSortedPrimitiveRewrite term result → NativeSortedNormal result)
    (stuck : (∀ result, ¬ NativeSortedPrimitiveRewrite term result) → NativeSortedNormal term) :
    (∃ count, NativeSortedSteps term count (nativeRootStep term)) ∧
      NativeSortedNormal (nativeRootStep term) := by
  unfold nativeRootStep
  cases rewritten : nativeRootRewrite term with
  | none =>
    refine ⟨⟨0, .reflexive⟩, stuck fun result rewrite => ?_⟩
    rw [root_complete rewrite] at rewritten
    cases rewritten
  | some result =>
    have rewrite := root_sound rewritten
    exact ⟨⟨1, .step (.primitive rewrite) .reflexive⟩, rootNormal _ rewrite⟩

private theorem unary_normal (normal : NativeSortedNormal argument)
    (rewrite : NativeSortedPrimitiveRewrite (.unary symbol argument) result) :
    NativeSortedNormal result := by
  cases rewrite with
  | flipA => exact role_b_normal
  | flipB => exact role_a_normal
  | fst => exact pair_left normal
  | snd => exact pair_right normal

private theorem binary_normal (normal : NativeSortedNormal left)
    (rewrite : NativeSortedPrimitiveRewrite (.binary symbol left right) result) :
    NativeSortedNormal result := by
  cases rewrite with
  | sdec => exact pair_left normal
  | kdec => exact pair_left normal

private theorem unary_stuck (normal : NativeSortedNormal argument)
    (stuck : ∀ result, ¬ NativeSortedPrimitiveRewrite (.unary symbol argument) result) :
    NativeSortedNormal (.unary symbol argument) := by
  intro result step
  cases step with
  | primitive rewrite => exact stuck _ rewrite
  | unary step => exact normal _ step

private theorem binary_stuck (leftNormal : NativeSortedNormal left)
    (rightNormal : NativeSortedNormal right)
    (stuck : ∀ result, ¬ NativeSortedPrimitiveRewrite (.binary symbol left right) result) :
    NativeSortedNormal (.binary symbol left right) := by
  intro result step
  cases step with
  | primitive rewrite => exact stuck _ rewrite
  | binaryLeft step => exact leftNormal _ step
  | binaryRight step => exact rightNormal _ step

private theorem leaf_normal (leaf : ∀ result, ¬ NativeSortedRewrite term result) :
    (∃ count, NativeSortedSteps term count term) ∧ NativeSortedNormal term :=
  ⟨⟨0, .reflexive⟩, leaf⟩

theorem native_sorted_normalize_spec (term : NativeQueryTerm) :
    (∃ count, NativeSortedSteps term count (nativeSortedNormalize term)) ∧
      NativeSortedNormal (nativeSortedNormalize term) := by
  induction term with
  | unary symbol argument induction =>
    obtain ⟨⟨count, steps⟩, normal⟩ := induction
    obtain ⟨⟨rootCount, rootSteps⟩, rootNormal⟩ :=
      root_step (term := .unary symbol (nativeSortedNormalize argument))
        (fun _ rewrite => unary_normal normal rewrite) (unary_stuck normal)
    exact ⟨⟨count + rootCount, native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .unary symbol term) (fun step => .unary step)
        steps) rootSteps⟩, rootNormal⟩
  | binary symbol left right leftInduction rightInduction =>
    obtain ⟨⟨leftCount, leftSteps⟩, leftNormal⟩ := leftInduction
    obtain ⟨⟨rightCount, rightSteps⟩, rightNormal⟩ := rightInduction
    obtain ⟨⟨rootCount, rootSteps⟩, rootNormal⟩ :=
      root_step (term := .binary symbol (nativeSortedNormalize left) (nativeSortedNormalize right))
        (fun _ rewrite => binary_normal leftNormal rewrite)
        (binary_stuck leftNormal rightNormal)
    exact ⟨⟨leftCount + rightCount + rootCount, native_sorted_steps_transitive
      (native_sorted_steps_transitive
        (native_sorted_steps_context (fun term => .binary symbol term right)
          (fun step => .binaryLeft step) leftSteps)
        (native_sorted_steps_context (fun term => .binary symbol (nativeSortedNormalize left) term)
          (fun step => .binaryRight step) rightSteps)) rootSteps⟩, rootNormal⟩
  | kdf first second third firstInduction secondInduction thirdInduction =>
    obtain ⟨⟨firstCount, firstSteps⟩, firstNormal⟩ := firstInduction
    obtain ⟨⟨secondCount, secondSteps⟩, secondNormal⟩ := secondInduction
    obtain ⟨⟨thirdCount, thirdSteps⟩, thirdNormal⟩ := thirdInduction
    refine ⟨⟨firstCount + secondCount + thirdCount, native_sorted_steps_transitive
      (native_sorted_steps_transitive
        (native_sorted_steps_context (fun term => .kdf term second third)
          (fun step => .kdfFirst step) firstSteps)
        (native_sorted_steps_context (fun term => .kdf (nativeSortedNormalize first) term third)
          (fun step => .kdfSecond step) secondSteps))
      (native_sorted_steps_context
        (fun term => .kdf (nativeSortedNormalize first) (nativeSortedNormalize second) term)
        (fun step => .kdfThird step) thirdSteps)⟩, ?_⟩
    intro result step
    cases step with
    | primitive rewrite => cases rewrite
    | kdfFirst step => exact firstNormal _ step
    | kdfSecond step => exact secondNormal _ step
    | kdfThird step => exact thirdNormal _ step
  | naturalAdd left right leftInduction rightInduction =>
    obtain ⟨⟨leftCount, leftSteps⟩, leftNormal⟩ := leftInduction
    obtain ⟨⟨rightCount, rightSteps⟩, rightNormal⟩ := rightInduction
    refine ⟨⟨leftCount + rightCount, native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .naturalAdd term right)
        (fun step => .naturalLeft step) leftSteps)
      (native_sorted_steps_context (fun term => .naturalAdd (nativeSortedNormalize left) term)
        (fun step => .naturalRight step) rightSteps)⟩, ?_⟩
    intro result step
    cases step with
    | primitive rewrite => cases rewrite
    | naturalLeft step => exact leftNormal _ step
    | naturalRight step => exact rightNormal _ step
  | list argument induction =>
    obtain ⟨⟨count, steps⟩, normal⟩ := induction
    refine ⟨⟨count, native_sorted_steps_context NativeQueryTerm.list
      (fun step => .list step) steps⟩, ?_⟩
    intro result step
    cases step with
    | primitive rewrite => cases rewrite
    | list step => exact normal _ step
  | cons first rest firstInduction restInduction =>
    obtain ⟨⟨firstCount, firstSteps⟩, firstNormal⟩ := firstInduction
    obtain ⟨⟨restCount, restSteps⟩, restNormal⟩ := restInduction
    refine ⟨⟨firstCount + restCount, native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .cons term rest)
        (fun step => .consLeft step) firstSteps)
      (native_sorted_steps_context (fun term => .cons (nativeSortedNormalize first) term)
        (fun step => .consRight step) restSteps)⟩, ?_⟩
    intro result step
    cases step with
    | primitive rewrite => cases rewrite
    | consLeft step => exact firstNormal _ step
    | consRight step => exact restNormal _ step
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB | nil =>
    exact leaf_normal fun result step => by
      cases step with
      | primitive rewrite => cases rewrite

/-- A `reduce` result is a correct normal form, up to AC, exactly when it is AC-equal to the
executable normal form; such a result is itself normal. -/
theorem native_sorted_reduce_certificate (decoded : decodeNativeMessage term = some message) :
    nativeACEqual result (nativeSortedNormalize term) = true ↔
      ∃ count normal, NativeSortedSteps term count normal ∧ NativeSortedNormal normal ∧
        NativeQueryAC normal result := by
  rw [native_ac_equal_iff]
  obtain ⟨⟨count, steps⟩, normal⟩ := native_sorted_normalize_spec term
  constructor
  · intro equivalent
    exact ⟨count, _, steps, normal, .symmetric equivalent⟩
  · rintro ⟨_, other, otherSteps, otherNormal, equivalent⟩
    exact .transitive (.symmetric equivalent)
      (native_sorted_normal_forms_unique otherSteps steps decoded otherNormal normal)

theorem native_sorted_reduce_normal (decoded : decodeNativeMessage term = some message)
    (accepted : nativeACEqual result (nativeSortedNormalize term) = true) :
    NativeSortedNormal result := by
  obtain ⟨⟨count, steps⟩, normal⟩ := native_sorted_normalize_spec term
  obtain ⟨_, _, normalDecoded⟩ := native_sorted_steps_decode steps decoded
  exact native_sorted_normal_ac_invariant
    (.symmetric (native_ac_equal_iff.mp accepted)) normalDecoded normal

#print axioms native_sorted_normalize_spec
#print axioms native_sorted_reduce_certificate
#print axioms native_sorted_reduce_normal
