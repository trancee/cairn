import QuerySystemBindings
import QuerySortRefinement
import QueryResidualRetyping
import QueryACCanonical

namespace Cairn.Equations

/-! Verified syntactic sorted unification and matching for native query systems.

Sort intersections in the native lattice are one of their arguments or empty, so a system without
natural sums has at most one most general unifier and no fresh variables. Natural sums are
flattened and AC-equal summands cancelled (in matching, only variable-free pattern summands);
an empty remainder solves or refutes the equation, and a single remaining summand becomes an
ordinary equation against the rebuilt remainder. `failed` and `solved` carry completeness proofs;
`unsupported` (fuel, size, two or more remaining summands on both sides, or a sort refinement
that needs a new variable) makes no claim. -/

inductive NativeSyntacticResult where
  | solved (bindings : NativeBindingList)
  | failed
  | unsupported

def nativeSyntacticFuel : Nat := 65536
def nativeSyntacticSizeLimit : Nat := 4096

def nativeQuerySize : NativeQueryTerm → Nat
  | .naturalAdd left right | .binary _ left right | .cons left right =>
    1 + nativeQuerySize left + nativeQuerySize right
  | .unary _ argument | .list argument => 1 + nativeQuerySize argument
  | .kdf first second third =>
    1 + nativeQuerySize first + nativeQuerySize second + nativeQuerySize third
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .queryVariable _ _ | .naturalOne | .roleA | .roleB |
      .nil => 1

def nativeSystemSize (equations : NativeEquationSystem) : Nat :=
  equations.foldr (fun equation total =>
    nativeQuerySize equation.1 + nativeQuerySize equation.2 + total) 0

def nativeQueryVariableKey? : NativeQueryTerm → Option NativeVariableKey
  | .queryVariable sort index => some (sort, index)
  | _ => none

def nativeChildEquations (left right : NativeQueryTerm) : NativeEquationSystem :=
  (nativeFreeChildren left).zip (nativeFreeChildren right)

def nativeSyntacticBind (recurse : NativeEquationSystem → NativeSyntacticResult)
    (key : NativeVariableKey) (value : NativeQueryTerm) (rest : NativeEquationSystem) :
    NativeSyntacticResult :=
  let residual := substituteNativeSystem (nativeBindingAssignment [(key, value)]) rest
  if nativeSystemSize residual > nativeSyntacticSizeLimit then .unsupported
  else match recurse residual with
    | .solved bindings => .solved (composeNativeBindings [(key, value)] bindings)
    | result => result

-- The variable side is `x`; the other side is a different term.
def nativeSyntacticVariable (recurse : NativeEquationSystem → NativeSyntacticResult)
    (sort : QuerySort) (index : Nat) (value : NativeQueryTerm) (rest : NativeEquationSystem) :
    NativeSyntacticResult :=
  if (sort, index) ∈ nativeQueryVariables value then .failed
  else if nativeSortedValueCheck sort value then
    nativeSyntacticBind recurse (sort, index) value rest
  else match nativeQueryVariableKey? value with
    | some (other, position) =>
      if nativeSortedValueCheck other (.queryVariable sort index) then
        nativeSyntacticBind recurse (other, position) (.queryVariable sort index) rest
      else if (nativeSortRequirements sort value).isNone then .failed else .unsupported
    | none => if (nativeSortRequirements sort value).isNone then .failed else .unsupported

-- Removes the first summand that `cancels` pairs with `term`.
def nativeSumTake (cancels : NativeQueryTerm → NativeQueryTerm → Bool) (term : NativeQueryTerm) :
    List NativeQueryTerm → Option (List NativeQueryTerm)
  | [] => none
  | first :: rest =>
    if cancels term first then some rest else (nativeSumTake cancels term rest).map (first :: ·)

-- Natural sums form a cancellative commutative semigroup, so paired summands can be dropped.
def nativeSumCancel (cancels : NativeQueryTerm → NativeQueryTerm → Bool) :
    List NativeQueryTerm → List NativeQueryTerm → List NativeQueryTerm × List NativeQueryTerm
  | [], right => ([], right)
  | first :: rest, right =>
    match nativeSumTake cancels first right with
    | some remaining => nativeSumCancel cancels rest remaining
    | none =>
      let result := nativeSumCancel cancels rest right
      (first :: result.1, result.2)

-- A subject variable is a constant, so only a variable-free pattern summand is its own instance.
def nativeGroundCancels (pattern subject : NativeQueryTerm) : Bool :=
  (nativeQueryVariables pattern).isEmpty && nativeACEqual pattern subject

def nativeSyntacticUnify : Nat → NativeEquationSystem → NativeSyntacticResult
  | 0, _ => .unsupported
  | _ + 1, [] => .solved []
  | fuel + 1, (left, right) :: rest =>
    if left = right then nativeSyntacticUnify fuel rest
    else match nativeQueryVariableKey? left, nativeQueryVariableKey? right with
      | some (sort, index), _ =>
        nativeSyntacticVariable (nativeSyntacticUnify fuel) sort index right rest
      | none, some (sort, index) =>
        nativeSyntacticVariable (nativeSyntacticUnify fuel) sort index left rest
      | none, none =>
        if nativeQueryHead left ≠ nativeQueryHead right then .failed
        else if nativeQueryHead left = .naturalAdd then
          match nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right) with
          | ([], []) => nativeSyntacticUnify fuel rest
          | ([], _ :: _) | (_ :: _, []) => .failed
          | ([kept], other :: others) =>
            nativeSyntacticUnify fuel ((kept, nativeACRebuild (other :: others)) :: rest)
          | (first :: second :: kept, [other]) =>
            nativeSyntacticUnify fuel ((nativeACRebuild (first :: second :: kept), other) :: rest)
          | (_ :: _ :: _, _ :: _ :: _) => .unsupported
        else nativeSyntacticUnify fuel (nativeChildEquations left right ++ rest)

def nativeBindingLookup (key : NativeVariableKey) : NativeBindingList → Option NativeQueryTerm
  | [] => none
  | (bound, value) :: rest => if bound = key then some value else nativeBindingLookup key rest

-- Pattern variables are bindable; subject variables are constants.
def nativeSyntacticMatch :
    Nat → List (NativeQueryTerm × NativeQueryTerm) → NativeBindingList → NativeSyntacticResult
  | 0, _, _ => .unsupported
  | _ + 1, [], bindings => .solved bindings
  | fuel + 1, (pattern, subject) :: rest, bindings =>
    match nativeQueryVariableKey? pattern with
    | some key =>
      match nativeBindingLookup key bindings with
      | some bound =>
        if nativeACEqual bound subject then nativeSyntacticMatch fuel rest bindings else .failed
      | none =>
        if nativeSortedValueCheck key.1 subject then
          nativeSyntacticMatch fuel rest ((key, subject) :: bindings)
        else .failed
    | none =>
      if nativeQueryHead pattern ≠ nativeQueryHead subject then .failed
      else if nativeQueryHead pattern = .naturalAdd then
        match nativeSumCancel nativeGroundCancels (nativeACSummands pattern)
            (nativeACSummands subject) with
        | ([], []) => nativeSyntacticMatch fuel rest bindings
        | ([], _ :: _) | (_ :: _, []) => .failed
        | ([kept], other :: others) =>
          nativeSyntacticMatch fuel ((kept, nativeACRebuild (other :: others)) :: rest) bindings
        | (_ :: _ :: _, _ :: _) => .unsupported
      else nativeSyntacticMatch fuel (nativeChildEquations pattern subject ++ rest) bindings

def NativeSyntacticSpec (equations : NativeEquationSystem) (variables : List NativeVariableKey) :
    NativeSyntacticResult → Prop
  | .solved bindings =>
    NativeCompleteACSystemOn equations variables [nativeBindingAssignment bindings]
  | .failed => NativeCompleteACSystemOn equations variables []
  | .unsupported => True

def NativeACMatcher (pairs : List (NativeQueryTerm × NativeQueryTerm))
    (assignment : QuerySort → Nat → NativeQueryTerm) : Prop :=
  NativeSortedAssignment assignment ∧ ∀ pair ∈ pairs,
    NativeQueryAC (substituteNativeQuery assignment pair.1) pair.2

private theorem key_some (found : nativeQueryVariableKey? term = some (sort, index)) :
    term = .queryVariable sort index := by
  cases term <;> simp_all [nativeQueryVariableKey?]

private theorem rigid_head (rigid : nativeQueryVariableKey? term = none)
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    nativeQueryHead (substituteNativeQuery assignment term) = nativeQueryHead term := by
  cases term <;> simp_all [nativeQueryVariableKey?, substituteNativeQuery, nativeQueryHead]

private theorem rigid_children (rigid : nativeQueryVariableKey? term = none)
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    nativeFreeChildren (substituteNativeQuery assignment term) =
      (nativeFreeChildren term).map (substituteNativeQuery assignment) := by
  cases term <;> simp_all [nativeQueryVariableKey?, substituteNativeQuery, nativeFreeChildren]

private theorem head_children_length (head : nativeQueryHead left = nativeQueryHead right) :
    (nativeFreeChildren left).length = (nativeFreeChildren right).length := by
  cases left <;> cases right <;> simp_all [nativeQueryHead, nativeFreeChildren]

private theorem children_zip_iff (first : NativeQueryTerm → NativeQueryTerm)
    (second : NativeQueryTerm → NativeQueryTerm) :
    ∀ (left right : List NativeQueryTerm), left.length = right.length →
      (NativeChildrenAC (left.map first) (right.map second) ↔
        ∀ pair ∈ left.zip right, NativeQueryAC (first pair.1) (second pair.2))
  | [], [], _ => by simp [NativeChildrenAC]
  | _ :: _, [], length | [], _ :: _, length => by simp at length
  | head :: tail, other :: remaining, length => by
    simp only [List.length_cons, Nat.add_right_cancel_iff] at length
    simp only [List.map_cons, NativeChildrenAC, List.zip_cons_cons, List.forall_mem_cons,
      children_zip_iff first second tail remaining length]

-- Equal rigid non-addition heads reduce an equation to its argument equations.
private theorem rigid_ac_iff (rigid : nativeQueryVariableKey? left = none)
    (head : nativeQueryHead left = nativeQueryHead right)
    (notAddition : nativeQueryHead left ≠ .naturalAdd)
    (first second : QuerySort → Nat → NativeQueryTerm)
    (subject : nativeFreeChildren (substituteNativeQuery second right) =
      (nativeFreeChildren right).map (substituteNativeQuery second))
    (subjectHead : nativeQueryHead (substituteNativeQuery second right) = nativeQueryHead right) :
    NativeQueryAC (substituteNativeQuery first left) (substituteNativeQuery second right) ↔
      ∀ pair ∈ nativeChildEquations left right,
        NativeQueryAC (substituteNativeQuery first pair.1) (substituteNativeQuery second pair.2) := by
  rw [native_query_ac_constructor_iff (by rw [rigid_head rigid]; exact notAddition),
    rigid_head rigid, rigid_children rigid, subject, subjectHead]
  simp only [head, true_and]
  exact children_zip_iff _ _ _ _ (head_children_length head)

private theorem system_append_iff :
    NativeACSystemUnifier (first ++ second) assignment ↔
      (∀ equation ∈ first, NativeQueryAC (substituteNativeQuery assignment equation.1)
        (substituteNativeQuery assignment equation.2)) ∧
        NativeACSystemUnifier second assignment := by
  unfold NativeACSystemUnifier
  simp only [List.mem_append]
  constructor
  · rintro ⟨sorted, solved⟩
    exact ⟨fun equation member => solved equation (.inl member),
      sorted, fun equation member => solved equation (.inr member)⟩
  · rintro ⟨first, sorted, second⟩
    refine ⟨sorted, ?_⟩
    rintro equation (member | member)
    · exact first equation member
    · exact second equation member

private theorem decompose_iff (leftRigid : nativeQueryVariableKey? left = none)
    (rightRigid : nativeQueryVariableKey? right = none)
    (head : nativeQueryHead left = nativeQueryHead right)
    (notAddition : nativeQueryHead left ≠ .naturalAdd) :
    NativeACSystemUnifier ((left, right) :: rest) assignment ↔
      NativeACSystemUnifier (nativeChildEquations left right ++ rest) assignment := by
  rw [native_system_cons_iff, system_append_iff]
  unfold NativeACUnifier
  rw [rigid_ac_iff leftRigid head notAddition assignment assignment
    (rigid_children rightRigid assignment) (rigid_head rightRigid assignment)]
  constructor
  · rintro ⟨⟨_, children⟩, rest⟩
    exact ⟨children, rest⟩
  · rintro ⟨children, rest⟩
    exact ⟨⟨rest.1, children⟩, rest⟩

private theorem spec_congr
    (solves : ∀ assignment, NativeACSystemUnifier first assignment ↔
      NativeACSystemUnifier second assignment)
    (holds : NativeSyntacticSpec second variables result) :
    NativeSyntacticSpec first variables result := by
  have congr (family : List (QuerySort → Nat → NativeQueryTerm)) :
      NativeCompleteACSystemOn first variables family ↔
        NativeCompleteACSystemOn second variables family := by
    unfold NativeCompleteACSystemOn
    simp only [solves]
  cases result with
  | solved => exact (congr _).mpr holds
  | failed => exact (congr _).mpr holds
  | unsupported => trivial

private theorem complete_empty (none : ∀ assignment, ¬NativeACSystemUnifier equations assignment)
    (variables : List NativeVariableKey) : NativeCompleteACSystemOn equations variables [] :=
  ⟨by simp, fun solution solved => (none solution solved).elim⟩

private theorem word_substitution (assignment : QuerySort → Nat → NativeQueryTerm)
    (term : NativeQueryTerm) :
    nativeACAtomWord (substituteNativeQuery assignment term) =
      (nativeACSummands term).flatMap
        (fun summand => nativeACAtomWord (substituteNativeQuery assignment summand)) := by
  induction term with
  | naturalAdd _ _ left right =>
    simp only [substituteNativeQuery, nativeACAtomWord, nativeACSummands, List.flatMap_append,
      left, right]
  | atom | naturalAtom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil => simp [nativeACSummands]

private theorem word_rebuild (assignment : QuerySort → Nat → NativeQueryTerm) :
    ∀ (terms : List NativeQueryTerm), terms ≠ [] →
      nativeACAtomWord (substituteNativeQuery assignment (nativeACRebuild terms)) =
        terms.flatMap (fun summand => nativeACAtomWord (substituteNativeQuery assignment summand))
  | [], empty => absurd rfl empty
  | [_], _ => by simp [nativeACRebuild]
  | first :: second :: rest, _ => by
    simp only [nativeACRebuild, substituteNativeQuery, nativeACAtomWord]
    rw [word_rebuild assignment (second :: rest) (by simp)]
    simp only [List.flatMap_cons]

private theorem word_plain (term : NativeQueryTerm) :
    nativeACAtomWord term = (nativeACSummands term).flatMap nativeACAtomWord := by
  simpa only [native_substitution_identity] using word_substitution NativeQueryTerm.queryVariable term

private theorem word_rebuild_plain (terms : List NativeQueryTerm) (nonempty : terms ≠ []) :
    nativeACAtomWord (nativeACRebuild terms) = terms.flatMap nativeACAtomWord := by
  simpa only [native_substitution_identity] using
    word_rebuild NativeQueryTerm.queryVariable terms nonempty

private theorem take_perm {cancels : NativeQueryTerm → NativeQueryTerm → Bool} :
    ∀ {terms remaining : List NativeQueryTerm}, nativeSumTake cancels term terms = some remaining →
      ∃ partner, cancels term partner = true ∧ terms.Perm (partner :: remaining)
  | [], _, taken => by simp [nativeSumTake] at taken
  | first :: rest, remaining, taken => by
    unfold nativeSumTake at taken
    split at taken
    · rename_i paired
      cases taken
      exact ⟨first, paired, .refl _⟩
    · obtain ⟨tail, found, equal⟩ := Option.map_eq_some_iff.mp taken
      subst equal
      obtain ⟨partner, paired, permutation⟩ := take_perm found
      exact ⟨partner, paired, (permutation.cons first).trans (.swap _ _ _)⟩

private theorem cancel_common {cancels : NativeQueryTerm → NativeQueryTerm → Bool}
    {words subjectWords : NativeQueryTerm → List NativeACClass}
    (related : ∀ term partner, cancels term partner = true →
      (words term).Perm (subjectWords partner)) :
    ∀ (left right : List NativeQueryTerm), ∃ common : List NativeACClass,
      (left.flatMap words).Perm (common ++ (nativeSumCancel cancels left right).1.flatMap words) ∧
        (right.flatMap subjectWords).Perm
          (common ++ (nativeSumCancel cancels left right).2.flatMap subjectWords)
  | [], right => ⟨[], by simp [nativeSumCancel]⟩
  | first :: rest, right => by
    unfold nativeSumCancel
    split
    · rename_i remaining taken
      obtain ⟨partner, paired, permutation⟩ := take_perm taken
      obtain ⟨common, leftPerm, rightPerm⟩ := cancel_common related rest remaining
      refine ⟨subjectWords partner ++ common, ?_, ?_⟩
      · rw [List.flatMap_cons, List.append_assoc]
        exact (related first partner paired).append leftPerm
      · rw [List.append_assoc]
        refine (permutation.flatMap_right subjectWords).trans ?_
        rw [List.flatMap_cons]
        exact rightPerm.append_left _
    · obtain ⟨common, leftPerm, rightPerm⟩ := cancel_common related rest right
      refine ⟨common, ?_, rightPerm⟩
      simp only [List.flatMap_cons]
      exact (leftPerm.append_left (words first)).trans (List.perm_append_comm_assoc _ _ _)

private theorem cancel_iff {cancels : NativeQueryTerm → NativeQueryTerm → Bool}
    {words subjectWords : NativeQueryTerm → List NativeACClass}
    (related : ∀ term partner, cancels term partner = true →
      (words term).Perm (subjectWords partner)) (left right : List NativeQueryTerm) :
    (left.flatMap words).Perm (right.flatMap subjectWords) ↔
      ((nativeSumCancel cancels left right).1.flatMap words).Perm
        ((nativeSumCancel cancels left right).2.flatMap subjectWords) := by
  obtain ⟨common, leftPerm, rightPerm⟩ := cancel_common related left right
  constructor
  · intro permutation
    exact (List.perm_append_left_iff common).mp
      (leftPerm.symm.trans (permutation.trans rightPerm))
  · intro permutation
    exact leftPerm.trans (((List.perm_append_left_iff common).mpr permutation).trans rightPerm.symm)

private theorem unify_sum_iff (assignment : QuerySort → Nat → NativeQueryTerm)
    (left right : NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right) ↔
      ((nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right)).1.flatMap
          fun summand => nativeACAtomWord (substituteNativeQuery assignment summand)).Perm
        ((nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right)).2.flatMap
          fun summand => nativeACAtomWord (substituteNativeQuery assignment summand)) := by
  rw [native_ac_atom_word_iff, word_substitution, word_substitution]
  exact cancel_iff (fun _ _ paired => native_ac_atom_word_iff.mp
    (native_ac_substitution assignment (native_ac_equal_iff.mp paired))) _ _

private theorem match_sum_iff (assignment : QuerySort → Nat → NativeQueryTerm)
    (pattern subject : NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment pattern) subject ↔
      ((nativeSumCancel nativeGroundCancels (nativeACSummands pattern)
          (nativeACSummands subject)).1.flatMap
          fun summand => nativeACAtomWord (substituteNativeQuery assignment summand)).Perm
        ((nativeSumCancel nativeGroundCancels (nativeACSummands pattern)
          (nativeACSummands subject)).2.flatMap nativeACAtomWord) := by
  rw [native_ac_atom_word_iff, word_substitution, word_plain subject]
  refine cancel_iff (fun term partner paired => ?_) _ _
  simp only [nativeGroundCancels, Bool.and_eq_true, List.isEmpty_iff] at paired
  have fixed := native_substitution_assignment_ac_on (term := term) (first := assignment)
    (second := NativeQueryTerm.queryVariable) (by
      intro sort index member
      rw [paired.1] at member
      cases member)
  rw [native_substitution_identity] at fixed
  exact native_ac_atom_word_iff.mp (.transitive fixed (native_ac_equal_iff.mp paired.2))

-- A sum with no summand left over is never the image of a nonempty sum.
private theorem cancelled_empty {words subjectWords : NativeQueryTerm → List NativeACClass}
    (nonempty : ∀ term, words term ≠ []) (subjectNonempty : ∀ term, subjectWords term ≠ [])
    (shape : (left = [] ∧ right ≠ []) ∨ (left ≠ [] ∧ right = [])) :
    ¬(left.flatMap words).Perm (right.flatMap subjectWords) := by
  intro permutation
  rcases shape with ⟨rfl, nonemptyRight⟩ | ⟨nonemptyLeft, rfl⟩
  · obtain ⟨term, rest, rfl⟩ := List.exists_cons_of_ne_nil nonemptyRight
    have empty := permutation.symm.eq_nil
    simp only [List.flatMap_cons, List.append_eq_nil_iff] at empty
    exact subjectNonempty term empty.1
  · obtain ⟨term, rest, rfl⟩ := List.exists_cons_of_ne_nil nonemptyLeft
    have empty := permutation.eq_nil
    simp only [List.flatMap_cons, List.append_eq_nil_iff] at empty
    exact nonempty term empty.1

private theorem word_nonempty_substituted (assignment : QuerySort → Nat → NativeQueryTerm) :
    ∀ term, nativeACAtomWord (substituteNativeQuery assignment term) ≠ [] :=
  fun _ => native_ac_atom_word_nonempty _

private theorem unify_cancel_trivial
    (cancelled : nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right) =
      ([], [])) (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right) := by
  rw [unify_sum_iff, cancelled]

private theorem unify_cancel_failed
    (cancelled : nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right) =
      (kept, others))
    (shape : (kept = [] ∧ others ≠ []) ∨ (kept ≠ [] ∧ others = []))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    ¬NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right) := by
  rw [unify_sum_iff, cancelled]
  exact cancelled_empty (word_nonempty_substituted assignment) (word_nonempty_substituted assignment)
    shape

private theorem unify_cancel_equation
    (cancelled : nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right) =
      (kept, others)) (keptNonempty : kept ≠ []) (othersNonempty : others ≠ [])
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment left) (substituteNativeQuery assignment right) ↔
      NativeQueryAC (substituteNativeQuery assignment (nativeACRebuild kept))
        (substituteNativeQuery assignment (nativeACRebuild others)) := by
  rw [unify_sum_iff, cancelled, native_ac_atom_word_iff, word_rebuild assignment _ keptNonempty,
    word_rebuild assignment _ othersNonempty]

private theorem match_cancel_trivial
    (cancelled : nativeSumCancel nativeGroundCancels (nativeACSummands pattern)
      (nativeACSummands subject) = ([], [])) (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment pattern) subject := by
  rw [match_sum_iff, cancelled]
  exact .nil

private theorem match_cancel_failed
    (cancelled : nativeSumCancel nativeGroundCancels (nativeACSummands pattern)
      (nativeACSummands subject) = (kept, others))
    (shape : (kept = [] ∧ others ≠ []) ∨ (kept ≠ [] ∧ others = []))
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    ¬NativeQueryAC (substituteNativeQuery assignment pattern) subject := by
  rw [match_sum_iff, cancelled]
  exact cancelled_empty (word_nonempty_substituted assignment) native_ac_atom_word_nonempty shape

private theorem match_cancel_equation
    (cancelled : nativeSumCancel nativeGroundCancels (nativeACSummands pattern)
      (nativeACSummands subject) = (kept, others)) (keptNonempty : kept ≠ [])
    (othersNonempty : others ≠ []) (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment pattern) subject ↔
      NativeQueryAC (substituteNativeQuery assignment (nativeACRebuild kept))
        (nativeACRebuild others) := by
  rw [match_sum_iff, cancelled, native_ac_atom_word_iff, word_rebuild assignment _ keptNonempty,
    word_rebuild_plain _ othersNonempty]

private theorem unify_cancel_spec
    (cancelled : nativeSumCancel nativeACEqual (nativeACSummands left) (nativeACSummands right) =
      (kept, others)) (keptNonempty : kept ≠ []) (othersNonempty : others ≠ [])
    (holds : NativeSyntacticSpec ((nativeACRebuild kept, nativeACRebuild others) :: rest) variables
      result) :
    NativeSyntacticSpec ((left, right) :: rest) variables result :=
  spec_congr (fun assignment => by
    rw [native_system_cons_iff, native_system_cons_iff]
    unfold NativeACUnifier
    rw [unify_cancel_equation cancelled keptNonempty othersNonempty assignment]) holds

private theorem bind_spec (recurse : NativeEquationSystem → NativeSyntacticResult)
    (inductive_spec : ∀ equations variables,
      NativeSyntacticSpec equations variables (recurse equations))
    (elimination : ∀ variables family, NativeCompleteACSystemOn
      (substituteNativeSystem (nativeBindingAssignment [(key, value)]) rest)
      (nativeAssignmentVariables variables (nativeBindingAssignment [(key, value)])) family →
      NativeCompleteACSystemOn equations variables
        (family.map (composeNativeAssignments (nativeBindingAssignment [(key, value)]))))
    (variables : List NativeVariableKey) :
    NativeSyntacticSpec equations variables (nativeSyntacticBind recurse key value rest) := by
  unfold nativeSyntacticBind
  simp only
  split
  · trivial
  · have residual := inductive_spec
      (substituteNativeSystem (nativeBindingAssignment [(key, value)]) rest)
      (nativeAssignmentVariables variables (nativeBindingAssignment [(key, value)]))
    revert residual
    cases recurse (substituteNativeSystem (nativeBindingAssignment [(key, value)]) rest) with
    | solved bindings =>
      intro residual
      have complete := elimination variables _ residual
      simp only [List.map_cons, List.map_nil] at complete
      simpa only [NativeSyntacticSpec, native_bindings_composition] using complete
    | failed =>
      intro residual
      simpa only [NativeSyntacticSpec, List.map_nil] using elimination variables _ residual
    | unsupported => intro _; trivial

private theorem variable_spec (recurse : NativeEquationSystem → NativeSyntacticResult)
    (inductive_spec : ∀ equations variables,
      NativeSyntacticSpec equations variables (recurse equations))
    (distinct : value ≠ .queryVariable sort index) (variables : List NativeVariableKey) :
    NativeSyntacticSpec ((.queryVariable sort index, value) :: rest) variables
      (nativeSyntacticVariable recurse sort index value rest) := by
  have refuted (missing : nativeSortRequirements sort value = none) :
      NativeCompleteACSystemOn ((.queryVariable sort index, value) :: rest) variables [] := by
    apply complete_empty
    intro assignment solved
    obtain ⟨⟨sorted, equivalent⟩, _⟩ := native_system_cons_iff.mp solved
    have value_sorted := (native_sorted_value_ac_iff equivalent sort).mp (sorted sort index)
    have holds := (native_sort_requirements_iff assignment sorted sort value).mp value_sorted
    rw [missing] at holds
    exact holds
  unfold nativeSyntacticVariable
  split
  · rename_i member
    exact native_system_occurs_complete_empty_family member distinct rest variables
  · rename_i absent
    split
    · rename_i accepted
      exact bind_spec recurse inductive_spec
        (fun variables family complete => native_system_variable_elimination
          ((native_sorted_value_check_iff _ _).mpr accepted) absent complete) variables
    · split
      · rename_i other position found
        have equal := key_some found
        subst equal
        split
        · rename_i accepted
          have otherAbsent : (other, position) ∉ nativeQueryVariables (.queryVariable sort index) := by
            simp only [nativeQueryVariables, List.mem_singleton, Prod.mk.injEq]
            rintro ⟨rfl, rfl⟩
            exact distinct rfl
          exact bind_spec recurse inductive_spec
            (fun variables family complete => native_system_reversed_variable_elimination
              ((native_sorted_value_check_iff _ _).mpr accepted) otherAbsent complete) variables
        · split
          · rename_i missing
            exact refuted (Option.isNone_iff_eq_none.mp missing)
          · trivial
      · split
        · rename_i missing
          exact refuted (Option.isNone_iff_eq_none.mp missing)
        · trivial

theorem native_syntactic_unify_spec :
    ∀ (fuel : Nat) (equations : NativeEquationSystem) (variables : List NativeVariableKey),
      NativeSyntacticSpec equations variables (nativeSyntacticUnify fuel equations)
  | 0, _, _ => trivial
  | _ + 1, [], variables => by
    have identity : nativeBindingAssignment [] = NativeQueryTerm.queryVariable := rfl
    simpa only [nativeSyntacticUnify, NativeSyntacticSpec, identity] using
      native_system_empty_complete variables
  | fuel + 1, (left, right) :: rest, variables => by
    have inductive_spec := native_syntactic_unify_spec fuel
    unfold nativeSyntacticUnify
    split
    · rename_i equal
      subst equal
      exact spec_congr (fun assignment => by
          rw [native_system_cons_iff]
          exact ⟨And.right, fun solved => ⟨⟨solved.1, .reflexive⟩, solved⟩⟩)
        (inductive_spec rest variables)
    · rename_i distinct
      split
      · rename_i _ _ sort index found
        have equal := key_some found
        subst equal
        exact variable_spec _ inductive_spec (Ne.symm distinct) variables
      · rename_i sort index _ found
        have equal := key_some found
        subst equal
        exact spec_congr (fun assignment => by
            rw [native_system_cons_iff, native_system_cons_iff]
            constructor <;> rintro ⟨first, rest⟩ <;> exact ⟨⟨first.1, .symmetric first.2⟩, rest⟩)
          (variable_spec _ inductive_spec distinct variables)
      · rename_i leftRigid rightRigid
        split
        · rename_i clash
          apply complete_empty
          intro assignment solved
          have head := native_query_ac_head (native_system_cons_iff.mp solved).1.2
          rw [rigid_head leftRigid, rigid_head rightRigid] at head
          exact clash head
        · rename_i head
          have head := Classical.not_not.mp head
          split
          · split
            · rename_i cancelled
              exact spec_congr (fun assignment => by
                  rw [native_system_cons_iff]
                  exact ⟨And.right, fun solved =>
                    ⟨⟨solved.1, unify_cancel_trivial cancelled assignment⟩, solved⟩⟩)
                (inductive_spec rest variables)
            · rename_i cancelled
              exact complete_empty (fun assignment solved => unify_cancel_failed cancelled
                (.inl ⟨rfl, by simp⟩) assignment (native_system_cons_iff.mp solved).1.2) variables
            · rename_i cancelled
              exact complete_empty (fun assignment solved => unify_cancel_failed cancelled
                (.inr ⟨by simp, rfl⟩) assignment (native_system_cons_iff.mp solved).1.2) variables
            · rename_i cancelled
              exact unify_cancel_spec (kept := [_]) cancelled (by simp) (by simp)
                (inductive_spec _ variables)
            · rename_i cancelled
              exact unify_cancel_spec (others := [_]) cancelled (by simp) (by simp)
                (inductive_spec _ variables)
            · trivial
          · rename_i notAddition
            exact spec_congr (fun _ => decompose_iff leftRigid rightRigid head notAddition)
              (inductive_spec _ variables)

private theorem lookup_assignment :
    ∀ (bindings : NativeBindingList), nativeBindingLookup (sort, index) bindings = some value →
      nativeBindingAssignment bindings sort index = value
  | [], found => by simp [nativeBindingLookup] at found
  | (bound, other) :: rest, found => by
    unfold nativeBindingLookup at found
    simp only [nativeBindingAssignment]
    split at found
    · rename_i equal
      simp_all
    · rename_i different
      simp only [different, ↓reduceIte]
      exact lookup_assignment rest found

private theorem match_rigid_iff (rigid : nativeQueryVariableKey? pattern = none)
    (head : nativeQueryHead pattern = nativeQueryHead subject)
    (notAddition : nativeQueryHead pattern ≠ .naturalAdd)
    (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativeQueryAC (substituteNativeQuery assignment pattern) subject ↔
      ∀ pair ∈ nativeChildEquations pattern subject,
        NativeQueryAC (substituteNativeQuery assignment pair.1) pair.2 := by
  have identity := native_substitution_identity subject
  have children := rigid_children (term := pattern) rigid
  rw [native_query_ac_constructor_iff (by rw [rigid_head rigid]; exact notAddition),
    rigid_head rigid, children]
  simp only [head, true_and]
  have mapped := children_zip_iff (substituteNativeQuery assignment) id
    (nativeFreeChildren pattern) (nativeFreeChildren subject) (head_children_length head)
  simpa only [List.map_id, id, nativeChildEquations] using mapped

private theorem match_sound :
    ∀ (fuel : Nat) (pairs : List (NativeQueryTerm × NativeQueryTerm))
      (bindings result : NativeBindingList),
      (∀ binding ∈ bindings, NativeSortedValue binding.1.1 binding.2) →
      nativeSyntacticMatch fuel pairs bindings = .solved result →
      (∀ binding ∈ result, NativeSortedValue binding.1.1 binding.2) ∧
        (∀ key value, nativeBindingLookup key bindings = some value →
          nativeBindingLookup key result = some value) ∧
        ∀ pair ∈ pairs, NativeQueryAC
          (substituteNativeQuery (nativeBindingAssignment result) pair.1) pair.2
  | 0, _, _, _, _, solved => by simp [nativeSyntacticMatch] at solved
  | _ + 1, [], bindings, result, values, solved => by
    simp only [nativeSyntacticMatch, NativeSyntacticResult.solved.injEq] at solved
    subst solved
    exact ⟨values, fun _ _ found => found, by simp⟩
  | fuel + 1, (pattern, subject) :: rest, bindings, result, values, solved => by
    unfold nativeSyntacticMatch at solved
    split at solved
    · rename_i key found
      obtain ⟨sort, index⟩ := key
      have equal := key_some found
      subst equal
      split at solved
      · rename_i bound looked
        split at solved
        · rename_i same
          obtain ⟨sorted, extends_, matched⟩ :=
            match_sound fuel rest bindings result values solved
          refine ⟨sorted, extends_, ?_⟩
          simp only [List.forall_mem_cons]
          refine ⟨?_, matched⟩
          rw [substituteNativeQuery, lookup_assignment result (extends_ _ _ looked)]
          exact native_ac_equal_iff.mp same
        · simp at solved
      · rename_i looked
        split at solved
        · rename_i accepted
          have extended : ∀ binding ∈ ((sort, index), subject) :: bindings,
              NativeSortedValue binding.1.1 binding.2 := by
            simp only [List.forall_mem_cons]
            exact ⟨(native_sorted_value_check_iff _ _).mpr accepted, values⟩
          obtain ⟨sorted, extends_, matched⟩ :=
            match_sound fuel rest _ result extended solved
          refine ⟨sorted, ?_, ?_⟩
          · intro key value found
            apply extends_
            unfold nativeBindingLookup
            split
            · rename_i equal
              subst equal
              rw [looked] at found
              cases found
            · exact found
          · simp only [List.forall_mem_cons]
            refine ⟨?_, matched⟩
            have own : nativeBindingLookup (sort, index) (((sort, index), subject) :: bindings) =
                some subject := by simp [nativeBindingLookup]
            rw [substituteNativeQuery, lookup_assignment result (extends_ _ _ own)]
            exact .reflexive
        · simp at solved
    · rename_i rigid
      split at solved
      · simp at solved
      · rename_i head
        have head := Classical.not_not.mp head
        split at solved
        · split at solved
          · rename_i cancelled
            obtain ⟨sorted, extends_, matched⟩ :=
              match_sound fuel rest bindings result values solved
            refine ⟨sorted, extends_, ?_⟩
            simp only [List.forall_mem_cons]
            exact ⟨match_cancel_trivial cancelled _, matched⟩
          · simp at solved
          · simp at solved
          · rename_i cancelled
            obtain ⟨sorted, extends_, matched⟩ :=
              match_sound fuel _ bindings result values solved
            refine ⟨sorted, extends_, ?_⟩
            simp only [List.forall_mem_cons] at matched ⊢
            exact ⟨(match_cancel_equation (kept := [_]) cancelled (by simp) (by simp) _).mpr
              matched.1, matched.2⟩
          · simp at solved
        · rename_i notAddition
          obtain ⟨sorted, extends_, matched⟩ :=
            match_sound fuel _ bindings result values solved
          refine ⟨sorted, extends_, ?_⟩
          simp only [List.forall_mem_cons]
          simp only [List.forall_mem_append] at matched
          exact ⟨(match_rigid_iff rigid head notAddition _).mpr matched.1, matched.2⟩

private theorem match_failed :
    ∀ (fuel : Nat) (pairs : List (NativeQueryTerm × NativeQueryTerm))
      (bindings : NativeBindingList),
      nativeSyntacticMatch fuel pairs bindings = .failed →
      ∀ assignment, NativeSortedAssignment assignment →
        (∀ key value, nativeBindingLookup key bindings = some value →
          NativeQueryAC (assignment key.1 key.2) value) →
        ¬∀ pair ∈ pairs, NativeQueryAC (substituteNativeQuery assignment pair.1) pair.2
  | 0, _, _, failed => by simp [nativeSyntacticMatch] at failed
  | _ + 1, [], _, failed => by simp [nativeSyntacticMatch] at failed
  | fuel + 1, (pattern, subject) :: rest, bindings, failed => by
    intro assignment sorted consistent matched
    simp only [List.forall_mem_cons] at matched
    unfold nativeSyntacticMatch at failed
    split at failed
    · rename_i key found
      obtain ⟨sort, index⟩ := key
      have equal := key_some found
      subst equal
      have here : NativeQueryAC (assignment sort index) subject := matched.1
      split at failed
      · rename_i bound looked
        split at failed
        · exact match_failed fuel rest bindings failed assignment sorted consistent matched.2
        · rename_i different
          exact different (native_ac_equal_iff.mpr
            (.transitive (.symmetric (consistent _ _ looked)) here))
      · rename_i looked
        split at failed
        · refine match_failed fuel rest _ failed assignment sorted ?_ matched.2
          intro key value found
          unfold nativeBindingLookup at found
          split at found
          · rename_i equal
            subst equal
            cases found
            exact here
          · exact consistent key value found
        · rename_i rejected
          exact rejected ((native_sorted_value_check_iff _ _).mp
            ((native_sorted_value_ac_iff here sort).mp (sorted sort index)))
    · rename_i rigid
      split at failed
      · rename_i clash
        have head := native_query_ac_head matched.1
        rw [rigid_head rigid] at head
        exact clash head
      · rename_i head
        have head := Classical.not_not.mp head
        split at failed
        · split at failed
          · exact match_failed fuel rest bindings failed assignment sorted consistent matched.2
          · rename_i cancelled
            exact match_cancel_failed cancelled (.inl ⟨rfl, by simp⟩) assignment matched.1
          · rename_i cancelled
            exact match_cancel_failed cancelled (.inr ⟨by simp, rfl⟩) assignment matched.1
          · rename_i cancelled
            refine match_failed fuel _ bindings failed assignment sorted consistent ?_
            simp only [List.forall_mem_cons]
            exact ⟨(match_cancel_equation (kept := [_]) cancelled (by simp) (by simp) _).mp
              matched.1, matched.2⟩
          · simp at failed
        · rename_i notAddition
          refine match_failed fuel _ bindings failed assignment sorted consistent ?_
          simp only [List.forall_mem_append]
          exact ⟨(match_rigid_iff rigid head notAddition _).mp matched.1, matched.2⟩

theorem native_syntactic_match_solved
    (solved : nativeSyntacticMatch fuel pairs [] = .solved bindings) :
    NativeACMatcher pairs (nativeBindingAssignment bindings) := by
  obtain ⟨sorted, _, matched⟩ := match_sound fuel pairs [] bindings (by simp) solved
  exact ⟨native_bindings_sorted_of_values bindings sorted, matched⟩

theorem native_syntactic_match_failed
    (failed : nativeSyntacticMatch fuel pairs [] = .failed) :
    ∀ assignment, ¬NativeACMatcher pairs assignment := by
  intro assignment matcher
  exact match_failed fuel pairs [] failed assignment matcher.1
    (by simp [nativeBindingLookup]) matcher.2

-- Instance checks are matching problems: each general binding is a pattern for the specific one.
theorem native_ac_instance_match_iff (variables : List NativeVariableKey)
    (general specific : QuerySort → Nat → NativeQueryTerm) :
    NativeACInstanceOn variables general specific ↔
      ∃ factor, NativeACMatcher
        (variables.map fun key => (general key.1 key.2, specific key.1 key.2)) factor := by
  unfold NativeACInstanceOn NativeACMatcher NativeAssignmentACOn composeNativeAssignments
  simp only [List.forall_mem_map]
  constructor
  · rintro ⟨factor, sorted, equivalent⟩
    exact ⟨factor, sorted, fun key member => .symmetric (equivalent key.1 key.2 member)⟩
  · rintro ⟨factor, sorted, equivalent⟩
    exact ⟨factor, sorted, fun sort index member => .symmetric (equivalent (sort, index) member)⟩

-- Given a most general unifier, a sound family is complete iff one member generalizes it.
theorem native_complete_family_cover_iff
    (principal : NativeCompleteACSystemOn equations variables [general])
    (sound : ∀ candidate ∈ family, NativeACSystemUnifier equations candidate) :
    NativeCompleteACSystemOn equations variables family ↔
      ∃ candidate ∈ family, NativeACInstanceOn variables candidate general := by
  constructor
  · intro complete
    exact complete.2 general (principal.1 general (by simp))
  · rintro ⟨candidate, member, cover⟩
    refine ⟨sound, fun solution solved => ?_⟩
    obtain ⟨most, mostMember, instance_⟩ := principal.2 solution solved
    have equal := List.mem_singleton.mp mostMember
    subst equal
    exact ⟨candidate, member, native_ac_instance_transitive cover instance_⟩

theorem native_complete_empty_family_iff
    (refuted : NativeCompleteACSystemOn equations variables [])
    (sound : ∀ candidate ∈ family, NativeACSystemUnifier equations candidate) :
    NativeCompleteACSystemOn equations variables family ↔ family = [] := by
  constructor
  · intro _
    apply List.eq_nil_iff_forall_not_mem.mpr
    intro candidate member
    obtain ⟨_, absent, _⟩ := refuted.2 candidate (sound candidate member)
    simp at absent
  · rintro rfl
    exact refuted

#print axioms native_syntactic_unify_spec
#print axioms native_syntactic_match_solved
#print axioms native_syntactic_match_failed
#print axioms native_ac_instance_match_iff
#print axioms native_complete_family_cover_iff
#print axioms native_complete_empty_family_iff

end Cairn.Equations
