import QueryRelabeling

namespace Cairn.Equations

-- Proof-only labels preserve raw relations, not native proper-sort matching guards.
def kindAbstraction : NativeLeafRelabeling where
  atoms sort index :=
    match sort with
    | .freshAtom => .naturalAtom (2 * index + 1)
    | .publicAtom => .atom .publicAtom index
    | .messageAtom => .atom .messageAtom index
  naturals index := .naturalAtom (2 * index)
  nodes index := .nodeAtom index
  variables sort index :=
    match sort with
    | .freshAtom => .queryVariable .natural (2 * index + 1)
    | .natural => .queryVariable .natural (2 * index)
    | .publicAtom => .queryVariable .publicAtom index
    | .message => .queryVariable .message index
    | .node => .queryVariable .node index

def kindExpansion : NativeLeafRelabeling where
  atoms sort index := .atom sort index
  naturals index :=
    if index % 2 = 0 then .naturalAtom (index / 2) else .atom .freshAtom (index / 2)
  nodes index := .nodeAtom index
  variables sort index :=
    match sort with
    | .natural =>
      if index % 2 = 0 then .queryVariable .natural (index / 2)
      else .queryVariable .freshAtom (index / 2)
    | .publicAtom => .queryVariable .publicAtom index
    | .freshAtom => .queryVariable .freshAtom index
    | .message => .queryVariable .message index
    | .node => .queryVariable .node index

theorem native_kind_round_trip (term : NativeQueryTerm) :
    relabelNative kindExpansion (relabelNative kindAbstraction term) = term := by
  induction term with
  | atom sort index =>
    cases sort <;> simp [relabelNative, kindAbstraction, kindExpansion] <;> omega
  | naturalAtom index => simp [relabelNative, kindAbstraction, kindExpansion]
  | nodeAtom => rfl
  | queryVariable sort index =>
    cases sort <;> simp [relabelNative, kindAbstraction, kindExpansion] <;> omega
  | naturalOne | roleA | roleB | nil => rfl
  | naturalAdd left right first second =>
    simp only [relabelNative, first, second]
  | unary symbol argument induction => simp only [relabelNative, induction]
  | binary symbol left right first second => simp only [relabelNative, first, second]
  | kdf first second third firstInduction secondInduction thirdInduction =>
    simp only [relabelNative, firstInduction, secondInduction, thirdInduction]
  | list argument induction => simp only [relabelNative, induction]
  | cons first rest firstInduction restInduction =>
    simp only [relabelNative, firstInduction, restInduction]

theorem native_kind_abstraction_injective : Function.Injective (relabelNative kindAbstraction) := by
  intro left right equality
  have recovered := congrArg (relabelNative kindExpansion) equality
  simpa only [native_kind_round_trip] using recovered

def decodeKindMessage (term : NativeQueryTerm) : Option MessageTerm :=
  decodeNativeMessage (relabelNative kindAbstraction term)

def NativeKindFramedImage (term : NativeQueryTerm) : Prop :=
  NativeFramedImage (relabelNative kindAbstraction term)

def abstractKindAssignment (assignment : QuerySort → Nat → NativeQueryTerm) :
    QuerySort → Nat → NativeQueryTerm
  | .natural, index =>
    if index % 2 = 0 then relabelNative kindAbstraction (assignment .natural (index / 2))
    else relabelNative kindAbstraction (assignment .freshAtom (index / 2))
  | .freshAtom, index => .queryVariable .freshAtom index
  | .publicAtom, index => relabelNative kindAbstraction (assignment .publicAtom index)
  | .message, index => relabelNative kindAbstraction (assignment .message index)
  | .node, index => relabelNative kindAbstraction (assignment .node index)

theorem native_kind_substitution (assignment : QuerySort → Nat → NativeQueryTerm)
    (term : NativeQueryTerm) :
    relabelNative kindAbstraction (substituteNativeQuery assignment term) =
      substituteNativeQuery (abstractKindAssignment assignment) (relabelNative kindAbstraction term) := by
  induction term with
  | atom sort index => cases sort <;> rfl
  | naturalAtom | nodeAtom | naturalOne | roleA | roleB | nil => rfl
  | queryVariable sort index =>
    have oddHalf : (2 * index + 1) / 2 = index := by omega
    cases sort <;>
      simp [substituteNativeQuery, relabelNative, kindAbstraction, abstractKindAssignment, oddHalf]
  | naturalAdd left right first second =>
    simp only [substituteNativeQuery, relabelNative, first, second]
  | unary symbol argument induction => simp only [substituteNativeQuery, relabelNative, induction]
  | binary symbol left right first second =>
    simp only [substituteNativeQuery, relabelNative, first, second]
  | kdf first second third firstInduction secondInduction thirdInduction =>
    simp only [substituteNativeQuery, relabelNative, firstInduction, secondInduction, thirdInduction]
  | list argument induction => simp only [substituteNativeQuery, relabelNative, induction]
  | cons first rest firstInduction restInduction =>
    simp only [substituteNativeQuery, relabelNative, firstInduction, restInduction]

theorem native_kind_framed_substitution (assignment : QuerySort → Nat → NativeQueryTerm)
    (shadow : QuerySubstitution)
    (compatible : abstractKindAssignment assignment = nativeQueryAssignment shadow)
    (image : NativeKindFramedImage term) :
    NativeKindFramedImage (substituteNativeQuery assignment term) := by
  unfold NativeKindFramedImage
  rw [native_kind_substitution, compatible]
  exact native_framed_substitution shadow image

theorem native_kind_ac_reflection
    (equivalent : NativeQueryAC (relabelNative kindAbstraction left)
      (relabelNative kindAbstraction right)) : NativeQueryAC left right := by
  have expanded := native_ac_relabeling kindExpansion equivalent
  simpa only [native_kind_round_trip] using expanded

theorem native_kind_rewrite_reflection
    (rewrite : NativeRewrite (relabelNative kindAbstraction left)
      (relabelNative kindAbstraction right)) : NativeRewrite left right := by
  have expanded := native_rewrite_relabeling kindExpansion rewrite
  simpa only [native_kind_round_trip] using expanded

theorem native_kind_modulo_ac_reflection
    (rewrite : NativeModuloACRewrite (relabelNative kindAbstraction left)
      (relabelNative kindAbstraction right)) : NativeModuloACRewrite left right := by
  have expanded := native_modulo_ac_relabeling kindExpansion rewrite
  simpa only [native_kind_round_trip] using expanded

theorem native_kind_framed_ac (equivalent : NativeQueryAC left right)
    (image : NativeKindFramedImage left) : NativeKindFramedImage right :=
  (native_framed_ac (native_ac_relabeling kindAbstraction equivalent)).1 image

theorem native_kind_framed_rewrite (rewrite : NativeRewrite left right)
    (image : NativeKindFramedImage left) : NativeKindFramedImage right :=
  native_framed_rewrite (native_rewrite_relabeling kindAbstraction rewrite) image

theorem native_kind_modulo_ac_decode (rewrite : NativeModuloACRewrite left right)
    (decoded : decodeKindMessage left = some term) :
    ∃ result, ModuloACRewrite term result ∧ decodeKindMessage right = some result :=
  native_modulo_ac_decode (native_modulo_ac_relabeling kindAbstraction rewrite) decoded

structure NativeKindMessage where
  term : NativeQueryTerm
  source : MessageTerm
  decoded : decodeKindMessage term = some source

theorem native_kind_termination :
    WellFounded (fun right left : NativeKindMessage =>
      NativeModuloACRewrite left.term right.term) := by
  apply Subrelation.wf (r := (measure (fun term : NativeKindMessage => messageWeight term.source)).rel)
    _ (measure (fun term : NativeKindMessage => messageWeight term.source)).wf
  intro right left rewrite
  obtain ⟨result, step, decoded⟩ := native_kind_modulo_ac_decode rewrite left.decoded
  have equality := Option.some.inj (decoded.symm.trans right.decoded)
  subst result
  exact modulo_ac_rewrite_decreases_weight step

#print axioms native_kind_round_trip
#print axioms native_kind_abstraction_injective
#print axioms native_kind_substitution
#print axioms native_kind_framed_substitution
#print axioms native_kind_ac_reflection
#print axioms native_kind_rewrite_reflection
#print axioms native_kind_modulo_ac_reflection
#print axioms native_kind_framed_ac
#print axioms native_kind_framed_rewrite
#print axioms native_kind_modulo_ac_decode
#print axioms native_kind_termination

end Cairn.Equations
