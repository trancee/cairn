import QueryGeneralCompleteness
import QuerySortedBoundedness

namespace Cairn.Equations

abbrev NativeVariantScheme : Type := NativeQueryTerm × NativeEquationSystem × Nat

-- Rule variables are message-sorted and allocated above every source index.
def nativeFreshMessage (index : Nat) : NativeQueryTerm := .queryVariable .message index

def nativeUnaryVariantSchemes (symbol : UnarySymbol) (value : NativeQueryTerm)
    (equations : NativeEquationSystem) (next : Nat) : List NativeVariantScheme :=
  (.unary symbol value, equations, next) ::
    match symbol with
    | .fst =>
      [(nativeFreshMessage next,
        (value, .binary .pair (nativeFreshMessage next) (nativeFreshMessage (next + 1))) :: equations,
        next + 2)]
    | .snd =>
      [(nativeFreshMessage (next + 1),
        (value, .binary .pair (nativeFreshMessage next) (nativeFreshMessage (next + 1))) :: equations,
        next + 2)]
    | .flip => [(.roleB, (value, .roleA) :: equations, next), (.roleA, (value, .roleB) :: equations, next)]
    | .hash | .pk => []

def nativeBinaryVariantSchemes (symbol : BinarySymbol) (left right : NativeQueryTerm)
    (equations : NativeEquationSystem) (next : Nat) : List NativeVariantScheme :=
  (.binary symbol left right, equations, next) ::
    match symbol with
    | .sdec =>
      [(nativeFreshMessage next,
        (left, .binary .senc (nativeFreshMessage next) (nativeFreshMessage (next + 1))) ::
          (right, nativeFreshMessage (next + 1)) :: equations,
        next + 2)]
    | .kdec =>
      [(nativeFreshMessage next,
        (left, .binary .kem (nativeFreshMessage next) (.unary .pk (nativeFreshMessage (next + 1)))) ::
          (right, nativeFreshMessage (next + 1)) :: equations,
        next + 2)]
    | .ext | .kem | .mac | .pair | .senc => []

def nativeJoinVariantSchemes (firsts : List NativeVariantScheme)
    (seconds : Nat → List NativeVariantScheme)
    (build : NativeQueryTerm → NativeQueryTerm → NativeEquationSystem → Nat → List NativeVariantScheme) :
    List NativeVariantScheme :=
  firsts.flatMap fun first =>
    (seconds first.2.2).flatMap fun second =>
      build first.1 second.1 (first.2.1 ++ second.2.1) second.2.2

-- Each destructor node either stays or takes one guarded rule with fresh pattern variables.
def nativeVariantSchemes : NativeQueryTerm → Nat → List NativeVariantScheme
  | .unary symbol argument, next =>
    (nativeVariantSchemes argument next).flatMap fun scheme =>
      nativeUnaryVariantSchemes symbol scheme.1 scheme.2.1 scheme.2.2
  | .list argument, next =>
    (nativeVariantSchemes argument next).map fun scheme => (.list scheme.1, scheme.2.1, scheme.2.2)
  | .binary symbol left right, next =>
    nativeJoinVariantSchemes (nativeVariantSchemes left next) (nativeVariantSchemes right)
      (nativeBinaryVariantSchemes symbol)
  | .naturalAdd left right, next =>
    nativeJoinVariantSchemes (nativeVariantSchemes left next) (nativeVariantSchemes right)
      (fun first second equations after => [(.naturalAdd first second, equations, after)])
  | .cons left right, next =>
    nativeJoinVariantSchemes (nativeVariantSchemes left next) (nativeVariantSchemes right)
      (fun first second equations after => [(.cons first second, equations, after)])
  | .kdf first second third, next =>
    nativeJoinVariantSchemes (nativeVariantSchemes first next) (nativeVariantSchemes second)
      (fun firstValue secondValue equations middle =>
        (nativeVariantSchemes third middle).map fun scheme =>
          (.kdf firstValue secondValue scheme.1, equations ++ scheme.2.1, scheme.2.2))
  | term, next => [(term, [], next)]

def NativeSchemeScope (term : NativeQueryTerm) (next after : Nat)
    (entry : QuerySort × Nat) : Prop :=
  entry ∈ nativeQueryVariables term ∨
    (entry.1 = .message ∧ next ≤ entry.2 ∧ entry.2 < after)

def NativeSchemeScoped (term : NativeQueryTerm) (next : Nat) (scheme : NativeVariantScheme) : Prop :=
  next ≤ scheme.2.2 ∧
    ∀ entry ∈ nativeQueryVariables scheme.1 ++ nativeSystemVariables scheme.2.1,
      NativeSchemeScope term next scheme.2.2 entry

theorem native_system_variables_cons :
    nativeSystemVariables (equation :: equations) =
      nativeQueryVariables equation.1 ++ nativeQueryVariables equation.2 ++
        nativeSystemVariables equations := by
  simp [nativeSystemVariables]

theorem native_system_variables_append :
    nativeSystemVariables (first ++ second) =
      nativeSystemVariables first ++ nativeSystemVariables second := by
  simp [nativeSystemVariables]

syntax "scope_close" : tactic

set_option hygiene false in
macro_rules | `(tactic| scope_close) => `(tactic|
  first
  | (subst inside; exact scope_fresh (by omega) (by omega))
  | exact lift _ (by omega) _ (by simp only [List.mem_append]; simp only [inside, true_or, or_true])
  | (rcases inside with inside | inside <;> scope_close))

private theorem scope_lift (lower : next ≤ first) (upper : last ≤ after)
    (included : ∀ entry ∈ nativeQueryVariables child, entry ∈ nativeQueryVariables parent)
    (within : NativeSchemeScope child first last entry) : NativeSchemeScope parent next after entry := by
  rcases within with inside | ⟨sort, low, high⟩
  · exact .inl (included _ inside)
  · exact .inr ⟨sort, by omega, by omega⟩

private theorem scope_fresh (low : next ≤ index) (high : index < after) :
    NativeSchemeScope term next after (.message, index) :=
  .inr ⟨rfl, low, high⟩

private theorem unary_schemes_scoped (child : NativeSchemeScoped argument next (value, equations, after))
    (member : scheme ∈ nativeUnaryVariantSchemes symbol value equations after) :
    NativeSchemeScoped (.unary symbol argument) next scheme := by
  obtain ⟨bound, within⟩ := child
  have lift : ∀ last, after ≤ last → ∀ entry,
      entry ∈ nativeQueryVariables value ++ nativeSystemVariables equations →
      NativeSchemeScope (.unary symbol argument) next last entry := by
    intro last upper entry inside
    exact scope_lift (Nat.le_refl _) upper (fun _ member => by simpa [nativeQueryVariables] using member)
      (within entry inside)
  cases symbol <;> simp only [nativeUnaryVariantSchemes, List.mem_cons, List.not_mem_nil, or_false] at member
  all_goals
    rcases member with rfl | rfl | rfl
  all_goals
    refine ⟨by dsimp only at bound ⊢; omega, fun entry inside => ?_⟩
    dsimp only at inside bound ⊢
    simp only [native_system_variables_cons, nativeQueryVariables, nativeFreshMessage,
      List.mem_append, List.mem_cons, List.not_mem_nil, or_false, or_assoc] at inside
    scope_close

private theorem join_member (member : scheme ∈ nativeJoinVariantSchemes firsts seconds build) :
    ∃ firstValue firstEquations middle secondValue secondEquations after,
      (firstValue, firstEquations, middle) ∈ firsts ∧
      (secondValue, secondEquations, after) ∈ seconds middle ∧
      scheme ∈ build firstValue secondValue (firstEquations ++ secondEquations) after := by
  simp only [nativeJoinVariantSchemes, List.mem_flatMap] at member
  obtain ⟨⟨firstValue, firstEquations, middle⟩, firstMember,
    ⟨secondValue, secondEquations, after⟩, secondMember, buildMember⟩ := member
  exact ⟨_, _, _, _, _, _, firstMember, secondMember, buildMember⟩

private theorem join_lift
    (leftIncluded : ∀ entry ∈ nativeQueryVariables left, entry ∈ nativeQueryVariables parent)
    (rightIncluded : ∀ entry ∈ nativeQueryVariables right, entry ∈ nativeQueryVariables parent)
    (first : NativeSchemeScoped left next (firstValue, firstEquations, middle))
    (second : NativeSchemeScoped right middle (secondValue, secondEquations, after))
    (upper : after ≤ last)
    (inside : entry ∈ nativeQueryVariables firstValue ++ nativeQueryVariables secondValue ++
      (nativeSystemVariables firstEquations ++ nativeSystemVariables secondEquations)) :
    NativeSchemeScope parent next last entry := by
  obtain ⟨firstBound, firstWithin⟩ := first
  obtain ⟨secondBound, secondWithin⟩ := second
  dsimp only at firstBound secondBound firstWithin secondWithin
  simp only [List.mem_append] at inside
  rcases inside with (inside | inside) | (inside | inside)
  · exact scope_lift (Nat.le_refl _) (by omega) leftIncluded
      (firstWithin entry (List.mem_append.mpr (.inl inside)))
  · exact scope_lift firstBound upper rightIncluded
      (secondWithin entry (List.mem_append.mpr (.inl inside)))
  · exact scope_lift (Nat.le_refl _) (by omega) leftIncluded
      (firstWithin entry (List.mem_append.mpr (.inr inside)))
  · exact scope_lift firstBound upper rightIncluded
      (secondWithin entry (List.mem_append.mpr (.inr inside)))

private theorem binary_schemes_scoped
    (first : NativeSchemeScoped left next (firstValue, firstEquations, middle))
    (second : NativeSchemeScoped right middle (secondValue, secondEquations, after))
    (member : scheme ∈ nativeBinaryVariantSchemes symbol firstValue secondValue
      (firstEquations ++ secondEquations) after) :
    NativeSchemeScoped (.binary symbol left right) next scheme := by
  have bound : next ≤ after := Nat.le_trans first.1 second.1
  have lift : ∀ last, after ≤ last → ∀ entry,
      entry ∈ nativeQueryVariables firstValue ++ nativeQueryVariables secondValue ++
        (nativeSystemVariables firstEquations ++ nativeSystemVariables secondEquations) →
      NativeSchemeScope (.binary symbol left right) next last entry :=
    fun _ upper _ inside => join_lift
      (fun _ member => by simp [nativeQueryVariables, member])
      (fun _ member => by simp [nativeQueryVariables, member]) first second upper inside
  cases symbol <;> simp only [nativeBinaryVariantSchemes, List.mem_cons, List.not_mem_nil,
    or_false] at member
  all_goals
    rcases member with rfl | rfl
  all_goals
    refine ⟨by dsimp only; omega, fun entry inside => ?_⟩
    dsimp only at inside ⊢
    simp only [native_system_variables_cons, native_system_variables_append, nativeQueryVariables,
      nativeFreshMessage, List.mem_append, List.mem_cons, List.not_mem_nil, or_false, or_assoc] at inside
    scope_close

private theorem pair_schemes_scoped (build : NativeQueryTerm → NativeQueryTerm → NativeQueryTerm)
    (variables : ∀ first second, nativeQueryVariables (build first second) =
      nativeQueryVariables first ++ nativeQueryVariables second)
    (first : NativeSchemeScoped left next (firstValue, firstEquations, middle))
    (second : NativeSchemeScoped right middle (secondValue, secondEquations, after)) :
    NativeSchemeScoped (build left right) next
      (build firstValue secondValue, firstEquations ++ secondEquations, after) := by
  refine ⟨Nat.le_trans first.1 second.1, fun entry inside => ?_⟩
  dsimp only at inside ⊢
  rw [variables, native_system_variables_append] at inside
  exact join_lift (fun _ member => by simp [variables, member])
    (fun _ member => by simp [variables, member]) first second (Nat.le_refl _)
    (by simpa only [List.append_assoc] using inside)

theorem native_variant_schemes_scope (member : scheme ∈ nativeVariantSchemes term next) :
    NativeSchemeScoped term next scheme := by
  induction term generalizing next scheme with
  | unary symbol argument induction =>
    simp only [nativeVariantSchemes, List.mem_flatMap] at member
    obtain ⟨⟨value, equations, after⟩, child, member⟩ := member
    exact unary_schemes_scoped (induction child) member
  | list argument induction =>
    simp only [nativeVariantSchemes, List.mem_map] at member
    obtain ⟨⟨value, equations, after⟩, child, rfl⟩ := member
    obtain ⟨bound, within⟩ := induction child
    exact ⟨bound, fun entry inside => scope_lift (Nat.le_refl _) (Nat.le_refl _)
      (fun _ member => by simpa [nativeQueryVariables] using member)
      (within entry (by simpa [nativeQueryVariables] using inside))⟩
  | binary symbol left right leftInduction rightInduction =>
    obtain ⟨_, _, _, _, _, _, first, second, member⟩ := join_member member
    exact binary_schemes_scoped (leftInduction first) (rightInduction second) member
  | naturalAdd left right leftInduction rightInduction =>
    obtain ⟨_, _, _, _, _, _, first, second, member⟩ := join_member member
    simp only [List.mem_cons, List.not_mem_nil, or_false] at member
    subst member
    exact pair_schemes_scoped NativeQueryTerm.naturalAdd (fun _ _ => rfl)
      (leftInduction first) (rightInduction second)
  | cons left right leftInduction rightInduction =>
    obtain ⟨_, _, _, _, _, _, first, second, member⟩ := join_member member
    simp only [List.mem_cons, List.not_mem_nil, or_false] at member
    subst member
    exact pair_schemes_scoped NativeQueryTerm.cons (fun _ _ => rfl)
      (leftInduction first) (rightInduction second)
  | kdf first second third firstInduction secondInduction thirdInduction =>
    obtain ⟨_, _, _, _, _, _, firstMember, secondMember, member⟩ := join_member member
    simp only [List.mem_map] at member
    obtain ⟨⟨thirdValue, thirdEquations, after⟩, thirdMember, rfl⟩ := member
    have leading := pair_schemes_scoped NativeQueryTerm.cons (fun _ _ => rfl)
      (firstInduction firstMember) (secondInduction secondMember)
    obtain ⟨thirdBound, thirdWithin⟩ := thirdInduction thirdMember
    obtain ⟨prefixBound, prefixWithin⟩ := leading
    dsimp only at prefixBound prefixWithin thirdBound thirdWithin
    refine ⟨by dsimp only; omega, fun entry inside => ?_⟩
    dsimp only at inside ⊢
    simp only [nativeQueryVariables, native_system_variables_append, List.mem_append] at inside
    have kdfVariables : ∀ entry, entry ∈ nativeQueryVariables (.cons first second) →
        entry ∈ nativeQueryVariables (.kdf first second third) := by
      intro _ member
      simp only [nativeQueryVariables, List.mem_append] at member ⊢
      exact .inl member
    rcases inside with ((inside | inside) | inside) | ((inside | inside) | inside)
    all_goals first
      | exact scope_lift (Nat.le_refl _) (by omega) kdfVariables (prefixWithin entry (by
          simp only [nativeQueryVariables, native_system_variables_append, List.mem_append]
          simp only [inside, true_or, or_true]))
      | exact scope_lift prefixBound (Nat.le_refl _)
          (fun _ member => by simp [nativeQueryVariables, member])
          (thirdWithin entry (by simp only [List.mem_append]; simp only [inside, true_or, or_true]))
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB | nil =>
    simp only [nativeVariantSchemes, List.mem_cons, List.not_mem_nil, or_false] at member
    subst member
    refine ⟨Nat.le_refl _, fun entry inside => .inl ?_⟩
    simpa [nativeSystemVariables] using inside

def NativeReaches (source target : NativeQueryTerm) : Prop :=
  ∃ count result, NativeSortedSteps source count result ∧ NativeQueryAC result target

private theorem system_append_left (solved : NativeACSystemUnifier (first ++ second) assignment) :
    NativeACSystemUnifier first assignment :=
  ⟨solved.1, fun equation member => solved.2 equation (List.mem_append_left _ member)⟩

private theorem system_append_right (solved : NativeACSystemUnifier (first ++ second) assignment) :
    NativeACSystemUnifier second assignment :=
  ⟨solved.1, fun equation member => solved.2 equation (List.mem_append_right _ member)⟩

private theorem system_head (solved : NativeACSystemUnifier ((left, right) :: equations) assignment) :
    NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right) :=
  solved.2 (left, right) (by simp)

private theorem system_tail (solved : NativeACSystemUnifier (equation :: equations) assignment) :
    NativeACSystemUnifier equations assignment :=
  ⟨solved.1, fun other member => solved.2 other (List.mem_cons_of_mem _ member)⟩

private theorem reach_unary (reach : NativeReaches source target) :
    NativeReaches (.unary symbol source) (.unary symbol target) := by
  obtain ⟨count, result, steps, equivalent⟩ := reach
  exact ⟨count, _, native_sorted_steps_context (fun term => .unary symbol term)
    (fun step => .unary step) steps, .unary equivalent⟩

private theorem reach_list (reach : NativeReaches source target) :
    NativeReaches (.list source) (.list target) := by
  obtain ⟨count, result, steps, equivalent⟩ := reach
  exact ⟨count, _, native_sorted_steps_context NativeQueryTerm.list
    (fun step => .list step) steps, .list equivalent⟩

private theorem reach_pair (build : NativeQueryTerm → NativeQueryTerm → NativeQueryTerm)
    (leftStep : ∀ {left right other}, NativeSortedRewrite left right →
      NativeSortedRewrite (build left other) (build right other))
    (rightStep : ∀ {left right other}, NativeSortedRewrite left right →
      NativeSortedRewrite (build other left) (build other right))
    (congruence : ∀ {firstLeft firstRight secondLeft secondRight},
      NativeQueryAC firstLeft firstRight → NativeQueryAC secondLeft secondRight →
      NativeQueryAC (build firstLeft secondLeft) (build firstRight secondRight))
    (first : NativeReaches firstSource firstTarget) (second : NativeReaches secondSource secondTarget) :
    ∃ count firstResult secondResult,
      NativeSortedSteps (build firstSource secondSource) count (build firstResult secondResult) ∧
      NativeQueryAC firstResult firstTarget ∧ NativeQueryAC secondResult secondTarget ∧
      NativeQueryAC (build firstResult secondResult) (build firstTarget secondTarget) := by
  obtain ⟨_, firstResult, firstSteps, firstAC⟩ := first
  obtain ⟨_, secondResult, secondSteps, secondAC⟩ := second
  exact ⟨_, firstResult, secondResult, native_sorted_steps_transitive
    (native_sorted_steps_context (fun term => build term secondSource) leftStep firstSteps)
    (native_sorted_steps_context (fun term => build firstResult term) rightStep secondSteps),
    firstAC, secondAC, congruence firstAC secondAC⟩

private theorem reach_root (steps : NativeSortedSteps source count middle)
    (root : NativeSortedPrimitiveRewrite middle result) (equivalent : NativeQueryAC result target) :
    NativeReaches source target :=
  ⟨_, _, native_sorted_steps_transitive steps (.step (.primitive root) .reflexive), equivalent⟩

private theorem ac_unary_inversion (equivalent : NativeQueryAC term (.unary symbol argument)) :
    ∃ other, term = .unary symbol other ∧ NativeQueryAC other argument := by
  have head := native_query_ac_head equivalent
  cases term <;> simp only [nativeQueryHead, reduceCtorEq, NativeQueryHead.unary.injEq] at head
  subst head
  exact ⟨_, rfl, native_ac_unary_iff.1 equivalent⟩

private theorem ac_binary_inversion (equivalent : NativeQueryAC term (.binary symbol left right)) :
    ∃ first second, term = .binary symbol first second ∧ NativeQueryAC first left ∧
      NativeQueryAC second right := by
  have head := native_query_ac_head equivalent
  cases term <;> simp only [nativeQueryHead, reduceCtorEq, NativeQueryHead.binary.injEq] at head
  subst head
  exact ⟨_, _, rfl, (native_ac_binary_iff.1 equivalent).1, (native_ac_binary_iff.1 equivalent).2⟩

private theorem ac_role_a_inversion (equivalent : NativeQueryAC term .roleA) : term = .roleA := by
  have head := native_query_ac_head equivalent
  cases term <;> simp_all [nativeQueryHead]

private theorem ac_role_b_inversion (equivalent : NativeQueryAC term .roleB) : term = .roleB := by
  have head := native_query_ac_head equivalent
  cases term <;> simp_all [nativeQueryHead]

theorem native_message_value_proper (value : NativeSortedValue .message term) :
    NativeProperMessage term := by
  cases value with
  | message decoded => exact ⟨_, decoded⟩

private theorem fresh_proper (sorted : NativeSortedAssignment assignment)
    (equivalent : NativeQueryAC term (substituteNativeQuery assignment (nativeFreshMessage index))) :
    NativeProperMessage term :=
  native_message_value_proper ((native_sorted_value_ac_iff equivalent .message).2 (sorted .message index))

private theorem reach_projection (sorted : NativeSortedAssignment assignment)
    (steps : NativeSortedSteps source count result)
    (equivalent : NativeQueryAC result
      (.binary .pair (assignment .message first) (assignment .message second))) :
    NativeReaches (.unary .fst source) (assignment .message first) ∧
      NativeReaches (.unary .snd source) (assignment .message second) := by
  obtain ⟨left, right, rfl, leftAC, rightAC⟩ := ac_binary_inversion equivalent
  have context : ∀ symbol, NativeSortedSteps (.unary symbol source) count
      (.unary symbol (.binary .pair left right)) := fun symbol =>
    native_sorted_steps_context (fun term => .unary symbol term) (fun step => .unary step) steps
  exact ⟨reach_root (context .fst) (.fst (fresh_proper sorted leftAC) (fresh_proper sorted rightAC)) leftAC,
    reach_root (context .snd) (.snd (fresh_proper sorted leftAC) (fresh_proper sorted rightAC)) rightAC⟩

private theorem reach_flip (steps : NativeSortedSteps source count result) :
    (NativeQueryAC result .roleA → NativeReaches (.unary .flip source) .roleB) ∧
      (NativeQueryAC result .roleB → NativeReaches (.unary .flip source) .roleA) := by
  have context := native_sorted_steps_context (fun term => .unary .flip term)
    (fun step => .unary step) steps
  refine ⟨fun equivalent => ?_, fun equivalent => ?_⟩
  · rw [ac_role_a_inversion equivalent] at context
    exact reach_root context .flipA .reflexive
  · rw [ac_role_b_inversion equivalent] at context
    exact reach_root context .flipB .reflexive

private theorem reach_decryption (sorted : NativeSortedAssignment assignment)
    (steps : NativeSortedSteps source count (.binary symbol cipher key))
    (keyAC : NativeQueryAC key (assignment .message (index + 1))) :
    (NativeQueryAC cipher (.binary .senc (assignment .message index) (assignment .message (index + 1))) →
      symbol = .sdec → NativeReaches source (assignment .message index)) ∧
    (NativeQueryAC cipher
        (.binary .kem (assignment .message index) (.unary .pk (assignment .message (index + 1)))) →
      symbol = .kdec → NativeReaches source (assignment .message index)) := by
  refine ⟨fun equivalent symbolEq => ?_, fun equivalent symbolEq => ?_⟩
  · subst symbolEq
    obtain ⟨payload, encryptionKey, rfl, payloadAC, encryptionAC⟩ := ac_binary_inversion equivalent
    exact reach_root steps (.sdec (fresh_proper (index := index) sorted payloadAC)
      (fresh_proper (index := index + 1) sorted encryptionAC)
      (.transitive encryptionAC (.symmetric keyAC))) payloadAC
  · subst symbolEq
    obtain ⟨payload, publicKey, rfl, payloadAC, publicAC⟩ := ac_binary_inversion equivalent
    obtain ⟨encryptionKey, rfl, encryptionAC⟩ := ac_unary_inversion publicAC
    exact reach_root steps (.kdec (fresh_proper (index := index) sorted payloadAC)
      (fresh_proper (index := index + 1) sorted encryptionAC)
      (.transitive encryptionAC (.symmetric keyAC))) payloadAC

theorem native_variant_schemes_reach (member : scheme ∈ nativeVariantSchemes term next)
    (solved : NativeACSystemUnifier scheme.2.1 assignment) :
    NativeReaches (substituteNativeQuery assignment term) (substituteNativeQuery assignment scheme.1) := by
  induction term generalizing next scheme with
  | unary symbol argument induction =>
    simp only [nativeVariantSchemes, List.mem_flatMap] at member
    obtain ⟨⟨value, equations, after⟩, child, member⟩ := member
    cases symbol <;> simp only [nativeUnaryVariantSchemes, List.mem_cons, List.not_mem_nil,
      or_false] at member
    all_goals rcases member with rfl | rfl | rfl
    all_goals first
      | exact reach_unary (induction child solved)
      | (obtain ⟨_, _, steps, equivalent⟩ := induction child (system_tail solved)
         have head := system_head solved
         first
         | exact (reach_projection solved.1 steps (.transitive equivalent head)).1
         | exact (reach_projection solved.1 steps (.transitive equivalent head)).2
         | exact (reach_flip steps).1 (.transitive equivalent head)
         | exact (reach_flip steps).2 (.transitive equivalent head))
  | list argument induction =>
    simp only [nativeVariantSchemes, List.mem_map] at member
    obtain ⟨⟨value, equations, after⟩, child, rfl⟩ := member
    exact reach_list (induction child solved)
  | binary symbol left right leftInduction rightInduction =>
    obtain ⟨_, _, _, _, _, _, first, second, member⟩ := join_member member
    cases symbol <;> simp only [nativeBinaryVariantSchemes, List.mem_cons, List.not_mem_nil,
      or_false] at member
    all_goals rcases member with rfl | rfl
    all_goals first
      | (obtain ⟨_, _, _, steps, _, _, equivalent⟩ := reach_pair (NativeQueryTerm.binary _)
          (fun step => .binaryLeft step) (fun step => .binaryRight step) (fun first second => .binary first second)
          (leftInduction first (system_append_left solved))
          (rightInduction second (system_append_right solved))
         exact ⟨_, _, steps, equivalent⟩)
      | (have rest := system_tail (system_tail solved)
         have cipher := system_head solved
         have key := system_head (system_tail solved)
         obtain ⟨_, _, _, steps, cipherAC, keyAC, _⟩ := reach_pair (NativeQueryTerm.binary _)
          (fun step => .binaryLeft step) (fun step => .binaryRight step) (fun first second => .binary first second)
          (leftInduction first (system_append_left rest))
          (rightInduction second (system_append_right rest))
         first
         | exact (reach_decryption solved.1 steps (.transitive keyAC key)).1
             (.transitive cipherAC cipher) rfl
         | exact (reach_decryption solved.1 steps (.transitive keyAC key)).2
             (.transitive cipherAC cipher) rfl)
  | naturalAdd left right leftInduction rightInduction =>
    obtain ⟨_, _, _, _, _, _, first, second, member⟩ := join_member member
    simp only [List.mem_cons, List.not_mem_nil, or_false] at member
    subst member
    obtain ⟨_, _, _, steps, _, _, equivalent⟩ := reach_pair NativeQueryTerm.naturalAdd
      (fun step => .naturalLeft step) (fun step => .naturalRight step)
      (fun first second => .naturalAdd first second)
      (leftInduction first (system_append_left solved))
      (rightInduction second (system_append_right solved))
    exact ⟨_, _, steps, equivalent⟩
  | cons left right leftInduction rightInduction =>
    obtain ⟨_, _, _, _, _, _, first, second, member⟩ := join_member member
    simp only [List.mem_cons, List.not_mem_nil, or_false] at member
    subst member
    obtain ⟨_, _, _, steps, _, _, equivalent⟩ := reach_pair NativeQueryTerm.cons
      (fun step => .consLeft step) (fun step => .consRight step)
      (fun first second => .cons first second)
      (leftInduction first (system_append_left solved))
      (rightInduction second (system_append_right solved))
    exact ⟨_, _, steps, equivalent⟩
  | kdf first second third firstInduction secondInduction thirdInduction =>
    obtain ⟨_, _, _, _, _, _, firstMember, secondMember, member⟩ := join_member member
    simp only [List.mem_map] at member
    obtain ⟨⟨thirdValue, thirdEquations, after⟩, thirdMember, rfl⟩ := member
    have leading := system_append_left solved
    obtain ⟨_, firstResult, firstSteps, firstAC⟩ :=
      firstInduction firstMember (system_append_left leading)
    obtain ⟨_, secondResult, secondSteps, secondAC⟩ :=
      secondInduction secondMember (system_append_right leading)
    obtain ⟨_, thirdResult, thirdSteps, thirdAC⟩ :=
      thirdInduction thirdMember (system_append_right solved)
    exact ⟨_, _, native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .kdf term _ _) (fun step => .kdfFirst step) firstSteps)
      (native_sorted_steps_transitive
        (native_sorted_steps_context (fun term => .kdf firstResult term _)
          (fun step => .kdfSecond step) secondSteps)
        (native_sorted_steps_context (fun term => .kdf firstResult secondResult term)
          (fun step => .kdfThird step) thirdSteps)),
      .kdf firstAC secondAC thirdAC⟩
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB | nil =>
    simp only [nativeVariantSchemes, List.mem_cons, List.not_mem_nil, or_false] at member
    subst member
    exact ⟨0, _, .reflexive, .reflexive⟩

def NativeNormalizedAssignment (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  ∀ sort index, NativeSortedNormal (assignment sort index)

def NativeFreshBelow (term : NativeQueryTerm) (next : Nat) : Prop :=
  ∀ entry ∈ nativeQueryVariables term, entry.1 = .message → entry.2 < next

def NativeAgreeOutside (first second : QuerySort → Nat → NativeQueryTerm) (start stop : Nat) : Prop :=
  ∀ sort index, (sort = .message → index < start ∨ stop ≤ index) → second sort index = first sort index

def nativeUpdateMessage (assignment : QuerySort → Nat → NativeQueryTerm) (target : Nat)
    (value : NativeQueryTerm) : QuerySort → Nat → NativeQueryTerm
  | .message, index => if index = target then value else assignment .message index
  | sort, index => assignment sort index

theorem native_substitution_agree
    (agree : ∀ entry ∈ nativeQueryVariables term, first entry.1 entry.2 = second entry.1 entry.2) :
    substituteNativeQuery first term = substituteNativeQuery second term := by
  induction term <;> simp_all [substituteNativeQuery, nativeQueryVariables]

private theorem system_agree (solved : NativeACSystemUnifier equations first)
    (sorted : NativeSortedAssignment second)
    (agree : ∀ entry ∈ nativeSystemVariables equations, second entry.1 entry.2 = first entry.1 entry.2) :
    NativeACSystemUnifier equations second := by
  refine ⟨sorted, fun equation member => ?_⟩
  have included : ∀ entry, entry ∈ nativeQueryVariables equation.1 ∨
      entry ∈ nativeQueryVariables equation.2 → entry ∈ nativeSystemVariables equations := by
    intro entry inside
    exact List.mem_flatMap.mpr ⟨equation, member, List.mem_append.mpr inside⟩
  rw [native_substitution_agree (fun entry inside => agree entry (included entry (.inl inside))),
    native_substitution_agree (fun entry inside => agree entry (included entry (.inr inside)))]
  exact solved.2 equation member

private theorem scheme_stable (within : NativeSchemeScoped term next scheme)
    (fresh : NativeFreshBelow term next) (lower : scheme.2.2 ≤ start)
    (agree : NativeAgreeOutside first second start stop) :
    ∀ entry ∈ nativeQueryVariables scheme.1 ++ nativeSystemVariables scheme.2.1,
      second entry.1 entry.2 = first entry.1 entry.2 := by
  intro ⟨sort, index⟩ inside
  apply agree
  intro message
  left
  rcases within.2 _ inside with source | ⟨_, _, high⟩
  · have := fresh _ source message
    have := within.1
    dsimp only at *
    omega
  · dsimp only at *
    omega

private theorem scheme_stable_value (within : NativeSchemeScoped term next scheme)
    (fresh : NativeFreshBelow term next) (lower : scheme.2.2 ≤ start)
    (agree : NativeAgreeOutside first second start stop) :
    substituteNativeQuery second scheme.1 = substituteNativeQuery first scheme.1 :=
  native_substitution_agree fun entry inside =>
    scheme_stable within fresh lower agree entry (List.mem_append_left _ inside)

private theorem scheme_stable_system (within : NativeSchemeScoped term next scheme)
    (fresh : NativeFreshBelow term next) (lower : scheme.2.2 ≤ start)
    (agree : NativeAgreeOutside first second start stop)
    (solved : NativeACSystemUnifier scheme.2.1 first) (sorted : NativeSortedAssignment second) :
    NativeACSystemUnifier scheme.2.1 second :=
  system_agree solved sorted fun entry inside =>
    scheme_stable within fresh lower agree entry (List.mem_append_right _ inside)

private theorem agree_trans (first : NativeAgreeOutside base middle start pivot)
    (second : NativeAgreeOutside middle last pivot stop) (lower : start ≤ pivot) (upper : pivot ≤ stop) :
    NativeAgreeOutside base last start stop := by
  intro sort index outside
  rw [second sort index (fun message => by
      rcases outside message with low | high
      · exact .inl (by omega)
      · exact .inr high),
    first sort index (fun message => by
      rcases outside message with low | high
      · exact .inl low
      · exact .inr (by omega))]

private theorem agree_update (assignment : QuerySort → Nat → NativeQueryTerm) (target : Nat)
    (value : NativeQueryTerm) :
    NativeAgreeOutside assignment (nativeUpdateMessage assignment target value) target (target + 1) := by
  intro sort index outside
  cases sort <;> simp only [nativeUpdateMessage]
  have := outside rfl
  split <;> first | rfl | omega

private theorem sorted_update (sorted : NativeSortedAssignment assignment)
    (proper : NativeProperMessage value) :
    NativeSortedAssignment (nativeUpdateMessage assignment target value) := by
  intro sort index
  cases sort <;> simp only [nativeUpdateMessage]
  all_goals first | exact sorted _ index | skip
  split
  · obtain ⟨_, decoded⟩ := proper
    exact .message decoded
  · exact sorted _ index

private theorem normalized_update (normalized : NativeNormalizedAssignment assignment)
    (normal : NativeSortedNormal value) :
    NativeNormalizedAssignment (nativeUpdateMessage assignment target value) := by
  intro sort index
  cases sort <;> simp only [nativeUpdateMessage]
  all_goals first | exact normalized _ index | skip
  split
  · exact normal
  · exact normalized _ index

private theorem update_hit : nativeUpdateMessage assignment target value .message target = value := by
  simp [nativeUpdateMessage]

private theorem update_miss (different : index ≠ target) :
    nativeUpdateMessage assignment target value .message index = assignment .message index := by
  simp [nativeUpdateMessage, different]

private theorem normal_unary (normal : NativeSortedNormal argument)
    (noRoot : ∀ result, ¬ NativeSortedPrimitiveRewrite (.unary symbol argument) result) :
    NativeSortedNormal (.unary symbol argument) := by
  intro result step
  cases step with
  | primitive root => exact noRoot _ root
  | unary inner => exact normal _ inner

private theorem normal_binary (left : NativeSortedNormal first) (right : NativeSortedNormal second)
    (noRoot : ∀ result, ¬ NativeSortedPrimitiveRewrite (.binary symbol first second) result) :
    NativeSortedNormal (.binary symbol first second) := by
  intro result step
  cases step with
  | primitive root => exact noRoot _ root
  | binaryLeft inner => exact left _ inner
  | binaryRight inner => exact right _ inner

private theorem normal_natural_add (left : NativeSortedNormal first) (right : NativeSortedNormal second) :
    NativeSortedNormal (.naturalAdd first second) := by
  intro result step
  cases step with
  | primitive root => cases root
  | naturalLeft inner => exact left _ inner
  | naturalRight inner => exact right _ inner

private theorem normal_cons (left : NativeSortedNormal first) (right : NativeSortedNormal second) :
    NativeSortedNormal (.cons first second) := by
  intro result step
  cases step with
  | primitive root => cases root
  | consLeft inner => exact left _ inner
  | consRight inner => exact right _ inner

private theorem normal_list (normal : NativeSortedNormal argument) :
    NativeSortedNormal (.list argument) := by
  intro result step
  cases step with
  | primitive root => cases root
  | list inner => exact normal _ inner

private theorem normal_kdf (first : NativeSortedNormal firstArgument)
    (second : NativeSortedNormal secondArgument) (third : NativeSortedNormal thirdArgument) :
    NativeSortedNormal (.kdf firstArgument secondArgument thirdArgument) := by
  intro result step
  cases step with
  | primitive root => cases root
  | kdfFirst inner => exact first _ inner
  | kdfSecond inner => exact second _ inner
  | kdfThird inner => exact third _ inner

private theorem normal_binary_children (normal : NativeSortedNormal (.binary symbol first second)) :
    NativeSortedNormal first ∧ NativeSortedNormal second :=
  ⟨fun _ step => normal _ (.binaryLeft step), fun _ step => normal _ (.binaryRight step)⟩

private theorem normal_unary_child (normal : NativeSortedNormal (.unary symbol argument)) :
    NativeSortedNormal argument :=
  fun _ step => normal _ (.unary step)

private theorem update_pair (sorted : NativeSortedAssignment assignment)
    (normalized : NativeNormalizedAssignment assignment)
    (firstProper : NativeProperMessage first) (secondProper : NativeProperMessage second)
    (firstNormal : NativeSortedNormal first) (secondNormal : NativeSortedNormal second) :
    ∃ extended, NativeSortedAssignment extended ∧ NativeNormalizedAssignment extended ∧
      NativeAgreeOutside assignment extended index (index + 2) ∧
      extended .message index = first ∧ extended .message (index + 1) = second := by
  refine ⟨nativeUpdateMessage (nativeUpdateMessage assignment index first) (index + 1) second,
    sorted_update (sorted_update sorted firstProper) secondProper,
    normalized_update (normalized_update normalized firstNormal) secondNormal,
    agree_trans (agree_update _ _ _) (agree_update _ _ _) (by omega) (by omega),
    by simp [nativeUpdateMessage], by simp [nativeUpdateMessage]⟩

private theorem agree_refl : NativeAgreeOutside assignment assignment start stop :=
  fun _ _ _ => rfl

private theorem fresh_child
    (included : ∀ entry ∈ nativeQueryVariables child, entry ∈ nativeQueryVariables parent)
    (fresh : NativeFreshBelow parent next) : NativeFreshBelow child next :=
  fun entry inside => fresh entry (included entry inside)

private theorem fresh_mono (fresh : NativeFreshBelow term next) (bound : next ≤ later) :
    NativeFreshBelow term later :=
  fun entry inside message => Nat.lt_of_lt_of_le (fresh entry inside message) bound

private theorem fresh_agree (fresh : NativeFreshBelow term next)
    (agree : NativeAgreeOutside first second next stop) :
    substituteNativeQuery second term = substituteNativeQuery first term :=
  native_substitution_agree fun entry inside => agree _ _ fun message => .inl (fresh entry inside message)

private theorem system_append_intro (first : NativeACSystemUnifier left assignment)
    (second : NativeACSystemUnifier right assignment) :
    NativeACSystemUnifier (left ++ right) assignment :=
  ⟨first.1, fun equation member => (List.mem_append.1 member).elim (first.2 equation) (second.2 equation)⟩

abbrev NativeSchemeCovers (assignment : QuerySort → Nat → NativeQueryTerm) (term : NativeQueryTerm)
    (next : Nat) (scheme : NativeVariantScheme)
    (extended : QuerySort → Nat → NativeQueryTerm) : Prop :=
  scheme ∈ nativeVariantSchemes term next ∧ NativeSortedAssignment extended ∧
    NativeNormalizedAssignment extended ∧ NativeAgreeOutside assignment extended next scheme.2.2 ∧
    NativeACSystemUnifier scheme.2.1 extended ∧
    ∃ count result, NativeSortedSteps (substituteNativeQuery assignment term) count result ∧
      NativeSortedNormal result ∧ NativeQueryAC result (substituteNativeQuery extended scheme.1)

abbrev NativeCoverable (term : NativeQueryTerm) : Prop :=
  ∀ {next assignment}, NativeSortedAssignment assignment → NativeNormalizedAssignment assignment →
    NativeFreshBelow term next → ∃ scheme extended, NativeSchemeCovers assignment term next scheme extended

private theorem cover_join (leftCover : NativeCoverable left) (rightCover : NativeCoverable right)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (leftFresh : NativeFreshBelow left next) (rightFresh : NativeFreshBelow right next) :
    ∃ firstValue firstEquations middle secondValue secondEquations after extended
      firstCount firstResult secondCount secondResult,
      (firstValue, firstEquations, middle) ∈ nativeVariantSchemes left next ∧
      (secondValue, secondEquations, after) ∈ nativeVariantSchemes right middle ∧
      NativeSortedAssignment extended ∧ NativeNormalizedAssignment extended ∧
      NativeAgreeOutside assignment extended next after ∧
      NativeACSystemUnifier (firstEquations ++ secondEquations) extended ∧
      NativeSortedSteps (substituteNativeQuery assignment left) firstCount firstResult ∧
      NativeSortedNormal firstResult ∧
      NativeQueryAC firstResult (substituteNativeQuery extended firstValue) ∧
      NativeSortedSteps (substituteNativeQuery assignment right) secondCount secondResult ∧
      NativeSortedNormal secondResult ∧
      NativeQueryAC secondResult (substituteNativeQuery extended secondValue) ∧
      next ≤ middle ∧ middle ≤ after := by
  obtain ⟨⟨firstValue, firstEquations, middle⟩, firstExtended, firstMember, firstSorted,
    firstNormalized, firstAgree, firstSolved, firstCount, firstResult, firstSteps, firstNormal,
    firstAC⟩ := leftCover sorted normalized leftFresh
  have firstScope := native_variant_schemes_scope firstMember
  obtain ⟨⟨secondValue, secondEquations, after⟩, extended, secondMember, secondSorted,
    secondNormalized, secondAgree, secondSolved, secondCount, secondResult, secondSteps,
    secondNormal, secondAC⟩ := rightCover firstSorted firstNormalized (fresh_mono rightFresh firstScope.1)
  have secondScope := native_variant_schemes_scope secondMember
  rw [fresh_agree rightFresh firstAgree] at secondSteps
  rw [← scheme_stable_value firstScope leftFresh (Nat.le_refl _) secondAgree] at firstAC
  exact ⟨_, _, _, _, _, _, extended, _, _, _, _, firstMember, secondMember, secondSorted,
    secondNormalized, agree_trans firstAgree secondAgree firstScope.1 secondScope.1,
    system_append_intro
      (scheme_stable_system firstScope leftFresh (Nat.le_refl _) secondAgree firstSolved secondSorted)
      secondSolved,
    firstSteps, firstNormal, firstAC, secondSteps, secondNormal, secondAC, firstScope.1, secondScope.1⟩

private theorem system_cons_intro
    (head : NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right))
    (rest : NativeACSystemUnifier equations assignment) :
    NativeACSystemUnifier ((left, right) :: equations) assignment :=
  ⟨rest.1, fun equation member => by
    rcases List.mem_cons.1 member with rfl | member
    · exact head
    · exact rest.2 equation member⟩

private theorem join_intro (first : (firstValue, firstEquations, middle) ∈ firsts)
    (second : (secondValue, secondEquations, after) ∈ seconds middle)
    (inside : scheme ∈ build firstValue secondValue (firstEquations ++ secondEquations) after) :
    scheme ∈ nativeJoinVariantSchemes firsts seconds build := by
  simp only [nativeJoinVariantSchemes, List.mem_flatMap]
  exact ⟨_, first, _, second, inside⟩

private theorem normal_role_a : NativeSortedNormal .roleA := by
  intro _ step
  cases step with
  | primitive root => cases root

private theorem normal_role_b : NativeSortedNormal .roleB := by
  intro _ step
  cases step with
  | primitive root => cases root

private theorem cover_unary (cover : NativeCoverable argument)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (fresh : NativeFreshBelow (.unary symbol argument) next) :
    ∃ scheme extended, NativeSchemeCovers assignment (.unary symbol argument) next scheme extended := by
  have argumentFresh : NativeFreshBelow argument next :=
    fresh_child (fun entry inside => by simpa [nativeQueryVariables] using inside) fresh
  obtain ⟨⟨value, equations, after⟩, extended, member, extendedSorted, extendedNormalized, agree,
    solved, count, result, steps, normal, equivalent⟩ := cover sorted normalized argumentFresh
  have scope := native_variant_schemes_scope member
  have context : NativeSortedSteps (substituteNativeQuery assignment (.unary symbol argument)) count
      (.unary symbol result) :=
    native_sorted_steps_context (fun term => .unary symbol term) (fun step => .unary step) steps
  have lift : ∀ {scheme}, scheme ∈ nativeUnaryVariantSchemes symbol value equations after →
      scheme ∈ nativeVariantSchemes (.unary symbol argument) next :=
    fun inside => List.mem_flatMap.2 ⟨_, member, inside⟩
  by_cases root : ∃ target, NativeSortedPrimitiveRewrite (.unary symbol result) target
  · obtain ⟨target, root⟩ := root
    cases root with
    | flipA =>
      exact ⟨(.roleB, (value, .roleA) :: equations, after), extended,
        lift (by simp [nativeUnaryVariantSchemes]), extendedSorted, extendedNormalized, agree,
        system_cons_intro (.symmetric equivalent) solved, _, _,
        native_sorted_steps_transitive context (.step (.primitive .flipA) .reflexive), normal_role_b,
        .reflexive⟩
    | flipB =>
      exact ⟨(.roleA, (value, .roleB) :: equations, after), extended,
        lift (by simp [nativeUnaryVariantSchemes]), extendedSorted, extendedNormalized, agree,
        system_cons_intro (.symmetric equivalent) solved, _, _,
        native_sorted_steps_transitive context (.step (.primitive .flipB) .reflexive), normal_role_a,
        .reflexive⟩
    | fst leftProper rightProper =>
      obtain ⟨leftNormal, rightNormal⟩ := normal_binary_children normal
      obtain ⟨updated, updatedSorted, updatedNormalized, updatedAgree, hitFirst, hitSecond⟩ :=
        update_pair (index := after) extendedSorted extendedNormalized leftProper rightProper
          leftNormal rightNormal
      have stable : substituteNativeQuery updated value = substituteNativeQuery extended value :=
        scheme_stable_value scope argumentFresh (Nat.le_refl _) updatedAgree
      refine ⟨(nativeFreshMessage after,
          (value, .binary .pair (nativeFreshMessage after) (nativeFreshMessage (after + 1))) :: equations,
          after + 2), updated, lift (by simp [nativeUnaryVariantSchemes]), updatedSorted,
        updatedNormalized, agree_trans agree updatedAgree scope.1 (Nat.le_add_right _ _),
        system_cons_intro ?_
          (scheme_stable_system scope argumentFresh (Nat.le_refl _) updatedAgree solved updatedSorted),
        _, _, native_sorted_steps_transitive context
          (.step (.primitive (.fst leftProper rightProper)) .reflexive), leftNormal, ?_⟩
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst, hitSecond, stable]
        exact .symmetric equivalent
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst]
        exact .reflexive
    | snd leftProper rightProper =>
      obtain ⟨leftNormal, rightNormal⟩ := normal_binary_children normal
      obtain ⟨updated, updatedSorted, updatedNormalized, updatedAgree, hitFirst, hitSecond⟩ :=
        update_pair (index := after) extendedSorted extendedNormalized leftProper rightProper
          leftNormal rightNormal
      have stable : substituteNativeQuery updated value = substituteNativeQuery extended value :=
        scheme_stable_value scope argumentFresh (Nat.le_refl _) updatedAgree
      refine ⟨(nativeFreshMessage (after + 1),
          (value, .binary .pair (nativeFreshMessage after) (nativeFreshMessage (after + 1))) :: equations,
          after + 2), updated, lift (by simp [nativeUnaryVariantSchemes]), updatedSorted,
        updatedNormalized, agree_trans agree updatedAgree scope.1 (Nat.le_add_right _ _),
        system_cons_intro ?_
          (scheme_stable_system scope argumentFresh (Nat.le_refl _) updatedAgree solved updatedSorted),
        _, _, native_sorted_steps_transitive context
          (.step (.primitive (.snd leftProper rightProper)) .reflexive), rightNormal, ?_⟩
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst, hitSecond, stable]
        exact .symmetric equivalent
      · simp only [substituteNativeQuery, nativeFreshMessage, hitSecond]
        exact .reflexive
  · exact ⟨(.unary symbol value, equations, after), extended,
      lift (by simp [nativeUnaryVariantSchemes]), extendedSorted, extendedNormalized, agree, solved,
      _, _, context, normal_unary normal (fun target step => root ⟨target, step⟩), .unary equivalent⟩

private theorem cover_binary (leftCover : NativeCoverable left) (rightCover : NativeCoverable right)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (fresh : NativeFreshBelow (.binary symbol left right) next) :
    ∃ scheme extended, NativeSchemeCovers assignment (.binary symbol left right) next scheme extended := by
  have leftFresh : NativeFreshBelow left next :=
    fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh
  have rightFresh : NativeFreshBelow right next :=
    fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh
  obtain ⟨firstValue, firstEquations, middle, secondValue, secondEquations, after, extended,
    firstCount, firstResult, secondCount, secondResult, firstMember, secondMember, extendedSorted,
    extendedNormalized, agree, solved, firstSteps, firstNormal, firstAC, secondSteps, secondNormal,
    secondAC, low, high⟩ := cover_join leftCover rightCover sorted normalized leftFresh rightFresh
  have firstScope := native_variant_schemes_scope firstMember
  have secondScope := native_variant_schemes_scope secondMember
  have context : NativeSortedSteps (substituteNativeQuery assignment (.binary symbol left right))
      (firstCount + secondCount) (.binary symbol firstResult secondResult) :=
    native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .binary symbol term _) (fun step => .binaryLeft step)
        firstSteps)
      (native_sorted_steps_context (fun term => .binary symbol firstResult term)
        (fun step => .binaryRight step) secondSteps)
  have lift : ∀ {scheme}, scheme ∈ nativeBinaryVariantSchemes symbol firstValue secondValue
      (firstEquations ++ secondEquations) after →
      scheme ∈ nativeVariantSchemes (.binary symbol left right) next :=
    fun inside => join_intro firstMember secondMember inside
  have stableAll : ∀ {updated}, NativeSortedAssignment updated →
      NativeAgreeOutside extended updated after (after + 2) →
      substituteNativeQuery updated firstValue = substituteNativeQuery extended firstValue ∧
      substituteNativeQuery updated secondValue = substituteNativeQuery extended secondValue ∧
      NativeACSystemUnifier (firstEquations ++ secondEquations) updated :=
    fun updatedSorted updatedAgree =>
      ⟨scheme_stable_value firstScope leftFresh high updatedAgree,
        scheme_stable_value secondScope (fresh_mono rightFresh low) (Nat.le_refl _) updatedAgree,
        system_append_intro
          (scheme_stable_system firstScope leftFresh high updatedAgree (system_append_left solved)
            updatedSorted)
          (scheme_stable_system secondScope (fresh_mono rightFresh low) (Nat.le_refl _) updatedAgree
            (system_append_right solved) updatedSorted)⟩
  by_cases root : ∃ target, NativeSortedPrimitiveRewrite (.binary symbol firstResult secondResult) target
  · obtain ⟨target, root⟩ := root
    cases root with
    | sdec payloadProper keyProper keyAC =>
      obtain ⟨payloadNormal, keyNormal⟩ := normal_binary_children firstNormal
      obtain ⟨updated, updatedSorted, updatedNormalized, updatedAgree, hitFirst, hitSecond⟩ :=
        update_pair (index := after) extendedSorted extendedNormalized payloadProper keyProper
          payloadNormal keyNormal
      obtain ⟨firstStable, secondStable, rest⟩ := stableAll updatedSorted updatedAgree
      refine ⟨(nativeFreshMessage after,
          (firstValue, .binary .senc (nativeFreshMessage after) (nativeFreshMessage (after + 1))) ::
            (secondValue, nativeFreshMessage (after + 1)) :: (firstEquations ++ secondEquations),
          after + 2), updated, lift (by simp [nativeBinaryVariantSchemes]), updatedSorted,
        updatedNormalized, agree_trans agree updatedAgree (by omega) (Nat.le_add_right _ _),
        system_cons_intro ?_ (system_cons_intro ?_ rest), _, _, native_sorted_steps_transitive context
          (.step (.primitive (.sdec payloadProper keyProper keyAC)) .reflexive), payloadNormal, ?_⟩
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst, hitSecond, firstStable]
        exact .symmetric firstAC
      · simp only [substituteNativeQuery, nativeFreshMessage, hitSecond, secondStable]
        exact .transitive (.symmetric secondAC) (.symmetric keyAC)
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst]
        exact .reflexive
    | kdec payloadProper keyProper keyAC =>
      obtain ⟨payloadNormal, publicNormal⟩ := normal_binary_children firstNormal
      have keyNormal := normal_unary_child publicNormal
      obtain ⟨updated, updatedSorted, updatedNormalized, updatedAgree, hitFirst, hitSecond⟩ :=
        update_pair (index := after) extendedSorted extendedNormalized payloadProper keyProper
          payloadNormal keyNormal
      obtain ⟨firstStable, secondStable, rest⟩ := stableAll updatedSorted updatedAgree
      refine ⟨(nativeFreshMessage after,
          (firstValue, .binary .kem (nativeFreshMessage after) (.unary .pk (nativeFreshMessage (after + 1)))) ::
            (secondValue, nativeFreshMessage (after + 1)) :: (firstEquations ++ secondEquations),
          after + 2), updated, lift (by simp [nativeBinaryVariantSchemes]), updatedSorted,
        updatedNormalized, agree_trans agree updatedAgree (by omega) (Nat.le_add_right _ _),
        system_cons_intro ?_ (system_cons_intro ?_ rest), _, _, native_sorted_steps_transitive context
          (.step (.primitive (.kdec payloadProper keyProper keyAC)) .reflexive), payloadNormal, ?_⟩
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst, hitSecond, firstStable]
        exact .symmetric firstAC
      · simp only [substituteNativeQuery, nativeFreshMessage, hitSecond, secondStable]
        exact .transitive (.symmetric secondAC) (.symmetric keyAC)
      · simp only [substituteNativeQuery, nativeFreshMessage, hitFirst]
        exact .reflexive
  · exact ⟨(.binary symbol firstValue secondValue, firstEquations ++ secondEquations, after), extended,
      lift (by simp [nativeBinaryVariantSchemes]), extendedSorted, extendedNormalized, agree, solved,
      _, _, context, normal_binary firstNormal secondNormal (fun target step => root ⟨target, step⟩),
      .binary firstAC secondAC⟩

private theorem cover_natural_add (leftCover : NativeCoverable left) (rightCover : NativeCoverable right)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (fresh : NativeFreshBelow (.naturalAdd left right) next) :
    ∃ scheme extended, NativeSchemeCovers assignment (.naturalAdd left right) next scheme extended := by
  obtain ⟨firstValue, firstEquations, middle, secondValue, secondEquations, after, extended,
    _, firstResult, _, secondResult, firstMember, secondMember, extendedSorted,
    extendedNormalized, agree, solved, firstSteps, firstNormal, firstAC, secondSteps, secondNormal,
    secondAC, _, _⟩ := cover_join leftCover rightCover sorted normalized
      (fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh)
      (fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh)
  exact ⟨(.naturalAdd firstValue secondValue, firstEquations ++ secondEquations, after), extended,
    join_intro firstMember secondMember (by simp), extendedSorted, extendedNormalized, agree, solved,
    _, _, native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .naturalAdd term _) (fun step => .naturalLeft step)
        firstSteps)
      (native_sorted_steps_context (fun term => .naturalAdd firstResult term)
        (fun step => .naturalRight step) secondSteps),
    normal_natural_add firstNormal secondNormal, .naturalAdd firstAC secondAC⟩

private theorem cover_cons (leftCover : NativeCoverable left) (rightCover : NativeCoverable right)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (fresh : NativeFreshBelow (.cons left right) next) :
    ∃ scheme extended, NativeSchemeCovers assignment (.cons left right) next scheme extended := by
  obtain ⟨firstValue, firstEquations, middle, secondValue, secondEquations, after, extended,
    _, firstResult, _, secondResult, firstMember, secondMember, extendedSorted,
    extendedNormalized, agree, solved, firstSteps, firstNormal, firstAC, secondSteps, secondNormal,
    secondAC, _, _⟩ := cover_join leftCover rightCover sorted normalized
      (fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh)
      (fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh)
  exact ⟨(.cons firstValue secondValue, firstEquations ++ secondEquations, after), extended,
    join_intro firstMember secondMember (by simp), extendedSorted, extendedNormalized, agree, solved,
    _, _, native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .cons term _) (fun step => .consLeft step) firstSteps)
      (native_sorted_steps_context (fun term => .cons firstResult term) (fun step => .consRight step)
        secondSteps),
    normal_cons firstNormal secondNormal, .cons firstAC secondAC⟩

private theorem cover_list (cover : NativeCoverable argument)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (fresh : NativeFreshBelow (.list argument) next) :
    ∃ scheme extended, NativeSchemeCovers assignment (.list argument) next scheme extended := by
  obtain ⟨⟨value, equations, after⟩, extended, member, extendedSorted, extendedNormalized, agree,
    solved, _, _, steps, normal, equivalent⟩ := cover sorted normalized
      (fresh_child (fun entry inside => by simpa [nativeQueryVariables] using inside) fresh)
  exact ⟨(.list value, equations, after), extended, List.mem_map.2 ⟨_, member, rfl⟩, extendedSorted,
    extendedNormalized, agree, solved, _, _,
    native_sorted_steps_context (fun term => .list term) (fun step => .list step) steps,
    normal_list normal, .list equivalent⟩

private theorem cover_kdf (firstCover : NativeCoverable first) (secondCover : NativeCoverable second)
    (thirdCover : NativeCoverable third)
    (sorted : NativeSortedAssignment assignment) (normalized : NativeNormalizedAssignment assignment)
    (fresh : NativeFreshBelow (.kdf first second third) next) :
    ∃ scheme extended, NativeSchemeCovers assignment (.kdf first second third) next scheme extended := by
  have firstFresh : NativeFreshBelow first next :=
    fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh
  have secondFresh : NativeFreshBelow second next :=
    fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh
  have thirdFresh : NativeFreshBelow third next :=
    fresh_child (fun entry inside => by simp [nativeQueryVariables, inside]) fresh
  obtain ⟨firstValue, firstEquations, middle, secondValue, secondEquations, after, joined,
    _, firstResult, _, secondResult, firstMember, secondMember, joinedSorted,
    joinedNormalized, joinedAgree, joinedSolved, firstSteps, firstNormal, firstAC, secondSteps,
    secondNormal, secondAC, low, high⟩ :=
    cover_join firstCover secondCover sorted normalized firstFresh secondFresh
  obtain ⟨⟨thirdValue, thirdEquations, last⟩, extended, thirdMember, extendedSorted,
    extendedNormalized, thirdAgree, thirdSolved, _, thirdResult, thirdSteps, thirdNormal, thirdAC⟩ :=
    thirdCover joinedSorted joinedNormalized (fresh_mono thirdFresh (Nat.le_trans low high))
  have firstScope := native_variant_schemes_scope firstMember
  have secondScope := native_variant_schemes_scope secondMember
  have thirdScope := native_variant_schemes_scope thirdMember
  rw [fresh_agree thirdFresh joinedAgree] at thirdSteps
  have firstStable : substituteNativeQuery extended firstValue = substituteNativeQuery joined firstValue :=
    scheme_stable_value firstScope firstFresh high thirdAgree
  have secondStable : substituteNativeQuery extended secondValue =
      substituteNativeQuery joined secondValue :=
    scheme_stable_value secondScope (fresh_mono secondFresh low) (Nat.le_refl _) thirdAgree
  have joinedStable : NativeACSystemUnifier (firstEquations ++ secondEquations) extended :=
    system_append_intro
      (scheme_stable_system firstScope firstFresh high thirdAgree (system_append_left joinedSolved)
        extendedSorted)
      (scheme_stable_system secondScope (fresh_mono secondFresh low) (Nat.le_refl _) thirdAgree
        (system_append_right joinedSolved) extendedSorted)
  refine ⟨(.kdf firstValue secondValue thirdValue,
      (firstEquations ++ secondEquations) ++ thirdEquations, last), extended,
    join_intro firstMember secondMember (List.mem_map.2 ⟨_, thirdMember, rfl⟩), extendedSorted,
    extendedNormalized, agree_trans joinedAgree thirdAgree (Nat.le_trans low high) thirdScope.1,
    system_append_intro joinedStable thirdSolved, _, _,
    native_sorted_steps_transitive
      (native_sorted_steps_context (fun term => .kdf term _ _) (fun step => .kdfFirst step) firstSteps)
      (native_sorted_steps_transitive
        (native_sorted_steps_context (fun term => .kdf firstResult term _) (fun step => .kdfSecond step)
          secondSteps)
        (native_sorted_steps_context (fun term => .kdf firstResult secondResult term)
          (fun step => .kdfThird step) thirdSteps)),
    normal_kdf firstNormal secondNormal thirdNormal, ?_⟩
  simp only [substituteNativeQuery, firstStable, secondStable]
  exact .kdf firstAC secondAC thirdAC

theorem native_variant_schemes_cover : NativeCoverable term := by
  induction term
  case unary symbol argument induction => exact cover_unary induction
  case binary symbol left right leftInduction rightInduction => exact cover_binary leftInduction rightInduction
  case naturalAdd left right leftInduction rightInduction =>
    exact cover_natural_add leftInduction rightInduction
  case cons left right leftInduction rightInduction => exact cover_cons leftInduction rightInduction
  case list argument induction => exact cover_list induction
  case kdf first second third firstInduction secondInduction thirdInduction =>
    exact cover_kdf firstInduction secondInduction thirdInduction
  case queryVariable sort index =>
    intro next assignment sorted normalized _
    exact ⟨(.queryVariable sort index, [], next), assignment, by simp [nativeVariantSchemes], sorted,
      normalized, agree_refl, ⟨sorted, by simp⟩, 0, _, .reflexive, normalized sort index, .reflexive⟩
  all_goals
    intro next assignment sorted normalized _
    refine ⟨(_, [], next), assignment, by simp [nativeVariantSchemes], sorted, normalized, agree_refl,
      ⟨sorted, by simp⟩, 0, _, .reflexive, ?_, .reflexive⟩
    intro _ step
    cases step with
    | primitive root => cases root

def nativeFreshBase (term : NativeQueryTerm) : Nat :=
  (nativeQueryVariables term).foldr (fun entry bound => max (entry.2 + 1) bound) 0

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

def nativeVariantSystem (term : NativeQueryTerm) (scheme : NativeVariantScheme) : NativeEquationSystem :=
  scheme.2.1 ++ [(term, term), (scheme.1, scheme.1)]

-- Each scheme contributes the sorted AC-unifier family of its accumulated equations.
def nativeVariants (term : NativeQueryTerm) : List (NativeQueryTerm × (QuerySort → Nat → NativeQueryTerm)) :=
  (nativeVariantSchemes term (nativeFreshBase term)).flatMap fun scheme =>
    (nativeSortedACSystemBindingFamily (nativeVariantSystem term scheme)).map fun bindings =>
      (scheme.1, nativeBindingAssignment bindings)

private theorem variant_system_term (inside : entry ∈ nativeQueryVariables term) :
    entry ∈ nativeSystemVariables (nativeVariantSystem term scheme) := by
  simp [nativeVariantSystem, nativeSystemVariables, inside]

private theorem variant_system_value (inside : entry ∈ nativeQueryVariables scheme.1) :
    entry ∈ nativeSystemVariables (nativeVariantSystem term scheme) := by
  simp [nativeVariantSystem, nativeSystemVariables, inside]

private theorem variant_system_intro (solved : NativeACSystemUnifier scheme.2.1 assignment) :
    NativeACSystemUnifier (nativeVariantSystem term scheme) assignment :=
  system_append_intro solved
    (system_cons_intro .reflexive (system_cons_intro .reflexive ⟨solved.1, by simp⟩))

private theorem variant_member (member : (value, general) ∈ nativeVariants term) :
    ∃ scheme bindings, scheme ∈ nativeVariantSchemes term (nativeFreshBase term) ∧
      bindings ∈ nativeSortedACSystemBindingFamily (nativeVariantSystem term scheme) ∧
      value = scheme.1 ∧ general = nativeBindingAssignment bindings := by
  simp only [nativeVariants, List.mem_flatMap, List.mem_map, Prod.mk.injEq] at member
  obtain ⟨scheme, schemeMember, bindings, bindingsMember, rfl, rfl⟩ := member
  exact ⟨scheme, bindings, schemeMember, bindingsMember, rfl, rfl⟩

theorem native_finite_variants_sound (member : (value, general) ∈ nativeVariants term) :
    NativeSortedAssignment general ∧
      NativeReaches (substituteNativeQuery general term) (substituteNativeQuery general value) := by
  obtain ⟨scheme, bindings, schemeMember, bindingsMember, rfl, rfl⟩ := variant_member member
  have solved := native_sorted_ac_system_family_sound _ bindingsMember
  exact ⟨solved.1, native_variant_schemes_reach schemeMember (system_append_left solved)⟩

-- Variants are complete for normalized sorted instances, as in Escobar-Meseguer.
theorem native_finite_variants_complete (sorted : NativeSortedAssignment assignment)
    (normalized : NativeNormalizedAssignment assignment) :
    ∃ value general factor, (value, general) ∈ nativeVariants term ∧
      NativeSortedAssignment factor ∧
      NativeAssignmentACOn (nativeQueryVariables term) assignment
        (composeNativeAssignments general factor) ∧
      ∃ count normalForm variantCount variantNormal,
        NativeSortedSteps (substituteNativeQuery assignment term) count normalForm ∧
        NativeSortedNormal normalForm ∧
        NativeSortedSteps (substituteNativeQuery general term) variantCount variantNormal ∧
        NativeSortedNormal variantNormal ∧
        NativeQueryAC variantNormal (substituteNativeQuery general value) ∧
        NativeQueryAC normalForm (substituteNativeQuery factor variantNormal) := by
  obtain ⟨scheme, extended, schemeMember, _, _, agree, solved, count, normalForm, steps, normal,
    equivalent⟩ := native_variant_schemes_cover sorted normalized (fresh_base (term := term))
  obtain ⟨_, complete⟩ := native_sorted_ac_system_family_complete (nativeVariantSystem term scheme)
  obtain ⟨general, generalMember, factor, factorSorted, instanceAC⟩ :=
    complete extended (variant_system_intro solved)
  obtain ⟨bindings, bindingsMember, rfl⟩ := List.mem_map.1 generalMember
  have generalSolved := native_sorted_ac_system_family_sound _ bindingsMember
  have valueAC : NativeQueryAC (substituteNativeQuery extended scheme.1)
      (substituteNativeQuery factor (substituteNativeQuery (nativeBindingAssignment bindings) scheme.1)) := by
    rw [native_substitution_composition]
    exact native_substitution_assignment_ac_on fun sort index inside =>
      instanceAC sort index (variant_system_value inside)
  have generalNormal : NativeSortedNormal
      (substituteNativeQuery (nativeBindingAssignment bindings) scheme.1) := by
    intro result step
    exact native_sorted_query_normal_ac_invariant (.transitive equivalent valueAC) normal _
      (native_sorted_rewrite_substitution factorSorted step)
  obtain ⟨variantCount, variantNormal, variantSteps, variantAC⟩ :=
    native_variant_schemes_reach schemeMember (system_append_left generalSolved)
  refine ⟨scheme.1, nativeBindingAssignment bindings, factor,
    List.mem_flatMap.2 ⟨scheme, schemeMember, List.mem_map.2 ⟨bindings, bindingsMember, rfl⟩⟩,
    factorSorted, fun sort index inside => ?_, count, normalForm, variantCount, variantNormal, steps,
    normal, variantSteps,
    native_sorted_query_normal_ac_invariant (.symmetric variantAC) generalNormal, variantAC,
    .transitive equivalent (.transitive valueAC (native_ac_substitution factor (.symmetric variantAC)))⟩
  have same : extended sort index = assignment sort index :=
    agree sort index fun message => .inl (fresh_base (term := term) _ inside message)
  rw [← same]
  exact instanceAC sort index (variant_system_term inside)

#print axioms native_variant_schemes_scope
#print axioms native_variant_schemes_reach
#print axioms native_variant_schemes_cover
#print axioms native_finite_variants_sound
#print axioms native_finite_variants_complete

end Cairn.Equations
