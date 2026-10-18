import QueryImage

namespace Cairn.Equations

inductive NativeQueryAC : NativeQueryTerm → NativeQueryTerm → Prop where
  | reflexive : NativeQueryAC term term
  | symmetric : NativeQueryAC left right → NativeQueryAC right left
  | transitive : NativeQueryAC first second → NativeQueryAC second third → NativeQueryAC first third
  | associative : NativeQueryAC (.naturalAdd (.naturalAdd first second) third)
      (.naturalAdd first (.naturalAdd second third))
  | commutative : NativeQueryAC (.naturalAdd left right) (.naturalAdd right left)
  | naturalAdd : NativeQueryAC firstLeft firstRight → NativeQueryAC secondLeft secondRight →
      NativeQueryAC (.naturalAdd firstLeft secondLeft) (.naturalAdd firstRight secondRight)
  | unary : NativeQueryAC left right → NativeQueryAC (.unary symbol left) (.unary symbol right)
  | binary : NativeQueryAC firstLeft firstRight → NativeQueryAC secondLeft secondRight →
      NativeQueryAC (.binary symbol firstLeft secondLeft) (.binary symbol firstRight secondRight)
  | kdf : NativeQueryAC firstLeft firstRight → NativeQueryAC secondLeft secondRight →
      NativeQueryAC thirdLeft thirdRight →
      NativeQueryAC (.kdf firstLeft secondLeft thirdLeft) (.kdf firstRight secondRight thirdRight)
  | list : NativeQueryAC left right → NativeQueryAC (.list left) (.list right)
  | cons : NativeQueryAC firstLeft firstRight → NativeQueryAC secondLeft secondRight →
      NativeQueryAC (.cons firstLeft secondLeft) (.cons firstRight secondRight)

private inductive DecodedAC (relation : α → α → Prop) : Option α → Option α → Prop where
  | absent : DecodedAC relation none none
  | present : relation left right → DecodedAC relation (some left) (some right)

private theorem decoded_reflexive {relation : α → α → Prop}
    (reflexive : ∀ term, relation term term) (term : Option α) :
    DecodedAC relation term term := by
  cases term with
  | none => exact .absent
  | some term => exact .present (reflexive term)

private theorem decoded_symmetric
    (symmetric : ∀ {left right}, relation left right → relation right left)
    (equivalent : DecodedAC relation left right) : DecodedAC relation right left := by
  cases equivalent with
  | absent => exact .absent
  | present step => exact .present (symmetric step)

private theorem decoded_transitive
    (transitive : ∀ {first second third}, relation first second → relation second third →
      relation first third)
    (first : DecodedAC relation left middle) (second : DecodedAC relation middle right) :
    DecodedAC relation left right := by
  cases first with
  | absent => cases second; exact .absent
  | present first =>
    cases second with
    | present second => exact .present (transitive first second)

private theorem decoded_map (function : α → β)
    (preserves : ∀ {left right}, firstRelation left right →
      secondRelation (function left) (function right))
    (equivalent : DecodedAC firstRelation left right) :
    DecodedAC secondRelation (left.map function) (right.map function) := by
  cases equivalent with
  | absent => exact .absent
  | present step => exact .present (preserves step)

private theorem decoded_binary (function : α → α → α)
    (preserves : ∀ {firstLeft firstRight secondLeft secondRight},
      relation firstLeft firstRight → relation secondLeft secondRight →
      relation (function firstLeft secondLeft) (function firstRight secondRight))
    (first : DecodedAC relation firstLeft firstRight)
    (second : DecodedAC relation secondLeft secondRight) :
    DecodedAC relation
      (do let left ← firstLeft; let right ← secondLeft; return function left right)
      (do let left ← firstRight; let right ← secondRight; return function left right) := by
  cases first <;> cases second
  · exact .absent
  · exact .absent
  · exact .absent
  · exact .present (preserves ‹_› ‹_›)

private theorem decoded_ternary (function : α → α → α → α)
    (preserves : ∀ {firstLeft firstRight secondLeft secondRight thirdLeft thirdRight},
      relation firstLeft firstRight → relation secondLeft secondRight →
      relation thirdLeft thirdRight →
      relation (function firstLeft secondLeft thirdLeft) (function firstRight secondRight thirdRight))
    (first : DecodedAC relation firstLeft firstRight)
    (second : DecodedAC relation secondLeft secondRight)
    (third : DecodedAC relation thirdLeft thirdRight) :
    DecodedAC relation
      (do let first ← firstLeft; let second ← secondLeft; let third ← thirdLeft;
          return function first second third)
      (do let first ← firstRight; let second ← secondRight; let third ← thirdRight;
          return function first second third) := by
  cases first <;> cases second <;> cases third
  all_goals first | exact .absent | exact .present (preserves ‹_› ‹_› ‹_›)

private theorem decode_natural_add_message (left right : NativeQueryTerm) :
    decodeNativeMessage (.naturalAdd left right) =
      (decodeNativeNatural (.naturalAdd left right)).map MessageTerm.natural := by
  cases first : decodeNativeNatural left <;> cases second : decodeNativeNatural right <;>
    simp_all [decodeNativeMessage, decodeNativeNatural]

private theorem decode_unary_message (symbol : UnarySymbol) (term : NativeQueryTerm) :
    decodeNativeMessage (.unary symbol term) =
      (decodeNativeMessage term).map (MessageTerm.unary symbol) := by
  cases decoded : decodeNativeMessage term <;> simp_all [decodeNativeMessage]

private theorem decoded_native_ac (equivalent : NativeQueryAC left right) :
    DecodedAC NaturalAC (decodeNativeNatural left) (decodeNativeNatural right) ∧
    DecodedAC MessageAC (decodeNativeMessage left) (decodeNativeMessage right) := by
  induction equivalent with
  | reflexive =>
    exact ⟨decoded_reflexive (fun _ => .reflexive) _, decoded_reflexive (fun _ => .reflexive) _⟩
  | symmetric _ induction =>
    exact ⟨decoded_symmetric (fun step => .symmetric step) induction.1,
      decoded_symmetric (fun step => .symmetric step) induction.2⟩
  | transitive _ _ first second =>
    exact ⟨decoded_transitive (fun first second => .transitive first second) first.1 second.1,
      decoded_transitive (fun first second => .transitive first second) first.2 second.2⟩
  | @associative first second third =>
    cases firstValue : decodeNativeNatural first <;>
      cases secondValue : decodeNativeNatural second <;>
      cases thirdValue : decodeNativeNatural third <;>
      simp only [decodeNativeNatural, decodeNativeMessage, firstValue, secondValue, thirdValue]
    all_goals constructor
    all_goals first | exact .absent | exact .present .associative |
      exact .present (.natural .associative)
  | @commutative left right =>
    cases firstValue : decodeNativeNatural left <;>
      cases secondValue : decodeNativeNatural right <;>
      simp only [decodeNativeNatural, decodeNativeMessage, firstValue, secondValue]
    all_goals constructor
    all_goals first | exact .absent | exact .present .commutative |
      exact .present (.natural .commutative)
  | naturalAdd _ _ first second =>
    have natural := decoded_binary NaturalTerm.add
      (fun first second => .transitive (.addLeft first) (.addRight second)) first.1 second.1
    refine ⟨natural, ?_⟩
    rw [decode_natural_add_message, decode_natural_add_message]
    exact decoded_map MessageTerm.natural (fun step => MessageAC.natural step) natural
  | @unary left right symbol _ induction =>
    refine ⟨.absent, ?_⟩
    rw [decode_unary_message, decode_unary_message]
    exact decoded_map (MessageTerm.unary symbol) (fun step => MessageAC.unary step) induction.2
  | @binary firstLeft firstRight secondLeft secondRight symbol _ _ first second =>
    exact ⟨.absent, decoded_binary (MessageTerm.binary symbol)
      (fun first second => .transitive (.binaryLeft first) (.binaryRight second)) first.2 second.2⟩
  | kdf _ _ _ first second third =>
    exact ⟨.absent, decoded_ternary MessageTerm.kdf
      (fun first second third => .transitive (.kdfFirst first)
        (.transitive (.kdfSecond second) (.kdfThird third))) first.2 second.2 third.2⟩
  | list => exact ⟨.absent, .absent⟩
  | cons => exact ⟨.absent, .absent⟩

theorem native_natural_ac_preservation (equivalent : NaturalAC left right) :
    NativeQueryAC (encodeNativeNatural left) (encodeNativeNatural right) := by
  induction equivalent with
  | reflexive => exact .reflexive
  | symmetric _ induction => exact .symmetric induction
  | transitive _ _ first second => exact .transitive first second
  | associative => exact .associative
  | commutative => exact .commutative
  | addLeft _ induction => exact .naturalAdd induction .reflexive
  | addRight _ induction => exact .naturalAdd .reflexive induction

theorem native_message_ac_preservation (equivalent : MessageAC left right) :
    NativeQueryAC (encodeNativeMessage left) (encodeNativeMessage right) := by
  induction equivalent with
  | reflexive => exact .reflexive
  | symmetric _ induction => exact .symmetric induction
  | transitive _ _ first second => exact .transitive first second
  | natural equivalent => exact native_natural_ac_preservation equivalent
  | unary _ induction => exact .unary induction
  | binaryLeft _ induction => exact .binary induction .reflexive
  | binaryRight _ induction => exact .binary .reflexive induction
  | kdfFirst _ induction => exact .kdf induction .reflexive .reflexive
  | kdfSecond _ induction => exact .kdf .reflexive induction .reflexive
  | kdfThird _ induction => exact .kdf .reflexive .reflexive induction

theorem native_natural_ac_reflection
    (equivalent : NativeQueryAC (encodeNativeNatural left) (encodeNativeNatural right)) :
    NaturalAC left right := by
  have decoded := (decoded_native_ac equivalent).1
  rw [native_natural_round_trip, native_natural_round_trip] at decoded
  cases decoded with
  | present step => exact step

theorem native_message_ac_reflection
    (equivalent : NativeQueryAC (encodeNativeMessage left) (encodeNativeMessage right)) :
    MessageAC left right := by
  have decoded := (decoded_native_ac equivalent).2
  rw [native_message_round_trip, native_message_round_trip] at decoded
  cases decoded with
  | present step => exact step

theorem native_ac_natural_image (equivalent : NativeQueryAC left right)
    (decoded : decodeNativeNatural left = some term) :
    ∃ result, decodeNativeNatural right = some result ∧ NaturalAC term result := by
  have related := (decoded_native_ac equivalent).1
  rw [decoded] at related
  cases value : decodeNativeNatural right with
  | none => rw [value] at related; cases related
  | some result =>
    rw [value] at related
    cases related with
    | present step => exact ⟨result, rfl, step⟩

theorem native_ac_message_image (equivalent : NativeQueryAC left right)
    (decoded : decodeNativeMessage left = some term) :
    ∃ result, decodeNativeMessage right = some result ∧ MessageAC term result := by
  have related := (decoded_native_ac equivalent).2
  rw [decoded] at related
  cases value : decodeNativeMessage right with
  | none => rw [value] at related; cases related
  | some result =>
    rw [value] at related
    cases related with
    | present step => exact ⟨result, rfl, step⟩

#print axioms native_natural_ac_preservation
#print axioms native_message_ac_preservation
#print axioms native_natural_ac_reflection
#print axioms native_message_ac_reflection
#print axioms native_ac_natural_image
#print axioms native_ac_message_image

end Cairn.Equations
