import QuerySubstitution

namespace Cairn.Equations

/-! Native Maude syntax for the query AST: printer, parser and the six rule templates. -/

inductive NativeMaudeHead where
  | publicAtom
  | freshAtom
  | messageAtom
  | naturalAtom
  | nodeAtom
  | one
  | add
  | roleA
  | roleB
  | unary (symbol : UnarySymbol)
  | binary (symbol : BinarySymbol)
  | kdf
  | list
  | cons
  | nil

def nativeTamarinName (name : List Char) : List Char := ['t', 'a', 'm', 'X', 'C'] ++ name

def nativeMaudeHeadName : NativeMaudeHead → List Char
  | .publicAtom => ['p']
  | .freshAtom => ['f']
  | .messageAtom => ['c']
  | .naturalAtom => ['t']
  | .nodeAtom => ['n']
  | .one => nativeTamarinName ['t', 'o', 'n', 'e']
  | .add => ['t', 'a', 'm', 't', 'p', 'l', 'u', 's']
  | .roleA => nativeTamarinName ['r', 'o', 'l', 'e', 'A']
  | .roleB => nativeTamarinName ['r', 'o', 'l', 'e', 'B']
  | .unary .flip => nativeTamarinName ['f', 'l', 'i', 'p']
  | .unary .fst => nativeTamarinName ['f', 's', 't']
  | .unary .hash => nativeTamarinName ['h']
  | .unary .pk => nativeTamarinName ['p', 'k']
  | .unary .snd => nativeTamarinName ['s', 'n', 'd']
  | .binary .ext => nativeTamarinName ['e', 'x', 't']
  | .binary .kdec => nativeTamarinName ['k', 'd', 'e', 'c']
  | .binary .kem => nativeTamarinName ['k', 'e', 'm']
  | .binary .mac => nativeTamarinName ['m', 'a', 'c']
  | .binary .pair => nativeTamarinName ['p', 'a', 'i', 'r']
  | .binary .sdec => nativeTamarinName ['s', 'd', 'e', 'c']
  | .binary .senc => nativeTamarinName ['s', 'e', 'n', 'c']
  | .kdf => nativeTamarinName ['k', 'd', 'f']
  | .list => ['l', 'i', 's', 't']
  | .cons => ['c', 'o', 'n', 's']
  | .nil => ['n', 'i', 'l']

def nativeMaudeHeads : List NativeMaudeHead := [
  .publicAtom, .freshAtom, .messageAtom, .naturalAtom, .nodeAtom, .one, .add, .roleA, .roleB,
  .unary .flip, .unary .fst, .unary .hash, .unary .pk, .unary .snd,
  .binary .ext, .binary .kdec, .binary .kem, .binary .mac, .binary .pair, .binary .sdec,
  .binary .senc, .kdf, .list, .cons, .nil
]

def nativeMaudeHeadNamed (name : List Char) : Option NativeMaudeHead :=
  nativeMaudeHeads.find? fun head => nativeMaudeHeadName head == name

def nativeMaudeSortName : QuerySort → List Char
  | .publicAtom => ['P', 'u', 'b']
  | .freshAtom => ['F', 'r', 'e', 's', 'h']
  | .message => ['M', 's', 'g']
  | .natural => ['T', 'a', 'm', 'N', 'a', 't']
  | .node => ['N', 'o', 'd', 'e']

def nativeMaudeSortNamed (name : List Char) : Option QuerySort :=
  [QuerySort.publicAtom, .freshAtom, .message, .natural, .node].find? fun sort =>
    nativeMaudeSortName sort == name

def nativeDigitChar (digit : Nat) : Char := Char.ofNat (48 + digit)

def nativeDigits (value : Nat) : List Char :=
  if value < 10 then [nativeDigitChar value]
  else nativeDigits (value / 10) ++ [nativeDigitChar (value % 10)]
termination_by value
decreasing_by omega

def nativeDigitValue (digits : List Char) : Nat :=
  digits.foldl (fun value digit => value * 10 + (digit.toNat - 48)) 0

-- Closed canonical decimals only: no sign, no leading zero except `0` itself.
def nativeDecimal? : List Char → Option Nat
  | [] => none
  | first :: rest =>
    if (first :: rest).all Char.isDigit && (first != '0' || rest.isEmpty) then
      some (nativeDigitValue (first :: rest))
    else none

def nativeMaudeChars : NativeQueryTerm → List Char
  | .atom .publicAtom index => nativeMaudeHeadName .publicAtom ++ '(' :: (nativeDigits index ++ [')'])
  | .atom .freshAtom index => nativeMaudeHeadName .freshAtom ++ '(' :: (nativeDigits index ++ [')'])
  | .atom .messageAtom index => nativeMaudeHeadName .messageAtom ++ '(' :: (nativeDigits index ++ [')'])
  | .naturalAtom index => nativeMaudeHeadName .naturalAtom ++ '(' :: (nativeDigits index ++ [')'])
  | .nodeAtom index => nativeMaudeHeadName .nodeAtom ++ '(' :: (nativeDigits index ++ [')'])
  | .queryVariable sort index => 'x' :: nativeDigits index ++ ':' :: nativeMaudeSortName sort
  | .naturalOne => nativeMaudeHeadName .one
  | .naturalAdd left right =>
    nativeMaudeHeadName .add ++ '(' :: nativeMaudeChars left ++ ',' :: nativeMaudeChars right ++ [')']
  | .roleA => nativeMaudeHeadName .roleA
  | .roleB => nativeMaudeHeadName .roleB
  | .unary symbol argument => nativeMaudeHeadName (.unary symbol) ++ '(' :: nativeMaudeChars argument ++ [')']
  | .binary symbol left right =>
    nativeMaudeHeadName (.binary symbol) ++
      '(' :: nativeMaudeChars left ++ ',' :: nativeMaudeChars right ++ [')']
  | .kdf first second third =>
    nativeMaudeHeadName .kdf ++ '(' :: nativeMaudeChars first ++ ',' :: nativeMaudeChars second ++
      ',' :: nativeMaudeChars third ++ [')']
  | .list argument => nativeMaudeHeadName .list ++ '(' :: nativeMaudeChars argument ++ [')']
  | .cons first rest =>
    nativeMaudeHeadName .cons ++ '(' :: nativeMaudeChars first ++ ',' :: nativeMaudeChars rest ++ [')']
  | .nil => nativeMaudeHeadName .nil

def nativeMaudeTerm (term : NativeQueryTerm) : String := String.ofList (nativeMaudeChars term)

def nativeSpan (keep : Char → Bool) : List Char → List Char × List Char
  | [] => ([], [])
  | head :: rest =>
    if keep head then
      let split := nativeSpan keep rest
      (head :: split.1, split.2)
    else ([], head :: rest)

def nativeSkipSpaces : List Char → List Char
  | [] => []
  | head :: rest => if head = ' ' then nativeSkipSpaces rest else head :: rest

def nativeMaudeAtom : NativeMaudeHead → Option (Nat → NativeQueryTerm)
  | .publicAtom => some (.atom .publicAtom)
  | .freshAtom => some (.atom .freshAtom)
  | .messageAtom => some (.atom .messageAtom)
  | .naturalAtom => some .naturalAtom
  | .nodeAtom => some .nodeAtom
  | _ => none

-- Maude prints flattened AC sums; they are read back right-nested.
def nativeAddChain (first second : NativeQueryTerm) : List NativeQueryTerm → NativeQueryTerm
  | [] => .naturalAdd first second
  | third :: rest => .naturalAdd first (nativeAddChain second third rest)

def nativeMaudeApply : NativeMaudeHead → List NativeQueryTerm → Option NativeQueryTerm
  | .one, [] => some .naturalOne
  | .roleA, [] => some .roleA
  | .roleB, [] => some .roleB
  | .nil, [] => some .nil
  | .add, first :: second :: rest => some (nativeAddChain first second rest)
  | .unary symbol, [argument] => some (.unary symbol argument)
  | .binary symbol, [left, right] => some (.binary symbol left right)
  | .kdf, [first, second, third] => some (.kdf first second third)
  | .list, [argument] => some (.list argument)
  | .cons, [first, rest] => some (.cons first rest)
  | _, _ => none

def nativeParseIndex (build : Nat → NativeQueryTerm) (input : List Char) :
    Option (NativeQueryTerm × List Char) :=
  match nativeSpan Char.isDigit input with
  | (digits, ')' :: rest) => (nativeDecimal? digits).map fun index => (build index, rest)
  | _ => none

def nativeParseVariable (digits rest : List Char) : Option (NativeQueryTerm × List Char) :=
  let sorted := nativeSpan Char.isAlphanum rest
  match nativeMaudeSortNamed sorted.1, nativeDecimal? digits with
  | some sort, some index => some (.queryVariable sort index, sorted.2)
  | _, _ => none

mutual
def nativeParseTerm : Nat → List Char → Option (NativeQueryTerm × List Char)
  | 0, _ => none
  | fuel + 1, input =>
    match nativeSpan Char.isAlphanum (nativeSkipSpaces input) with
    | ('x' :: digits, ':' :: rest) => nativeParseVariable digits rest
    | (word, '(' :: rest) =>
      match nativeMaudeHeadNamed word with
      | none => none
      | some head =>
        match nativeMaudeAtom head with
        | some build => nativeParseIndex build rest
        | none =>
          match nativeParseArguments fuel rest with
          | none => none
          | some (arguments, rest) => (nativeMaudeApply head arguments).map fun term => (term, rest)
    | (word, rest) =>
      match nativeMaudeHeadNamed word with
      | none => none
      | some head => (nativeMaudeApply head []).map fun term => (term, rest)

def nativeParseArguments : Nat → List Char → Option (List NativeQueryTerm × List Char)
  | 0, _ => none
  | fuel + 1, input =>
    match nativeParseTerm fuel input with
    | none => none
    | some (term, rest) =>
      match nativeSkipSpaces rest with
      | ',' :: rest => (nativeParseArguments fuel rest).map fun parsed => (term :: parsed.1, parsed.2)
      | ')' :: rest => some ([term], rest)
      | _ => none
end

def nativeMaudeParse (text : String) : Option NativeQueryTerm :=
  match nativeParseTerm (text.toList.length + 1) text.toList with
  | some (term, rest) => if nativeSkipSpaces rest = [] then some term else none
  | none => none

/-! Round trip. -/

def nativeMaudeFuel : NativeQueryTerm → Nat
  | .naturalAdd left right | .binary _ left right | .cons left right =>
    nativeMaudeFuel left + nativeMaudeFuel right + 3
  | .unary _ argument | .list argument => nativeMaudeFuel argument + 2
  | .kdf first second third =>
    nativeMaudeFuel first + nativeMaudeFuel second + nativeMaudeFuel third + 4
  | _ => 1

private theorem digit_char (digit : Nat) (small : digit < 10) :
    (nativeDigitChar digit).isDigit = true ∧ (nativeDigitChar digit).toNat - 48 = digit := by
  have : ∀ k : Fin 10, (nativeDigitChar k.val).isDigit = true ∧
      (nativeDigitChar k.val).toNat - 48 = k.val := by decide
  exact this ⟨digit, small⟩

private theorem digits_digit : ∀ value, ∀ character ∈ nativeDigits value, character.isDigit = true
  | value, character, inside => by
    rw [nativeDigits] at inside
    split at inside
    · simp only [List.mem_singleton] at inside
      exact inside ▸ (digit_char value (by omega)).1
    · rcases List.mem_append.mp inside with earlier | last
      · exact digits_digit (value / 10) character earlier
      · simp only [List.mem_singleton] at last
        exact last ▸ (digit_char (value % 10) (Nat.mod_lt _ (by omega))).1
termination_by value => value
decreasing_by omega

private theorem digits_value : ∀ value, nativeDigitValue (nativeDigits value) = value
  | value => by
    rw [nativeDigits]
    split
    · rename_i small
      simpa [nativeDigitValue] using (digit_char _ small).2
    · rename_i large
      have earlier := digits_value (value / 10)
      simp only [nativeDigitValue, List.foldl_append, List.foldl_cons, List.foldl_nil] at earlier ⊢
      rw [earlier, (digit_char (value % 10) (Nat.mod_lt _ (by omega))).2]
      omega
termination_by value => value
decreasing_by omega

private theorem digits_shape : ∀ value, ∃ first rest, nativeDigits value = first :: rest ∧
    (first != '0' || rest.isEmpty) = true
  | value => by
    rw [nativeDigits]
    split
    · refine ⟨_, [], rfl, by simp⟩
    · rename_i large
      obtain ⟨first, rest, shape, canonical⟩ := digits_shape (value / 10)
      refine ⟨first, rest ++ [nativeDigitChar (value % 10)], by rw [shape]; rfl, ?_⟩
      have positive : value / 10 ≠ 0 := by omega
      cases first_zero : (first != '0') with
      | true => simp
      | false =>
        simp only [first_zero, Bool.false_or, List.isEmpty_iff] at canonical
        subst canonical
        simp only [bne_eq_false_iff_eq] at first_zero
        subst first_zero
        rw [nativeDigits] at shape
        split at shape
        · rename_i small
          simp only [List.cons.injEq, and_true] at shape
          have : ∀ k : Fin 10, nativeDigitChar k.val = '0' → k.val = 0 := by decide
          exact absurd (this ⟨value / 10, small⟩ shape) positive
        · rename_i large
          have : (nativeDigits (value / 10 / 10) ++ [nativeDigitChar (value / 10 % 10)]).length ≥ 2 := by
            obtain ⟨_, _, inner, _⟩ := digits_shape (value / 10 / 10)
            simp [inner]
          rw [shape] at this
          simp at this
termination_by value => value
decreasing_by all_goals omega

private theorem decimal_digits (value : Nat) : nativeDecimal? (nativeDigits value) = some value := by
  obtain ⟨first, rest, shape, canonical⟩ := digits_shape value
  have all : (first :: rest).all Char.isDigit = true := by
    rw [← shape, List.all_eq_true]
    exact digits_digit value
  rw [shape]
  simp only [nativeDecimal?, all, canonical, Bool.and_self, ↓reduceIte]
  rw [← shape, digits_value]

private theorem span_append (keep : Char → Bool) (word rest : List Char)
    (kept : ∀ character ∈ word, keep character = true)
    (stops : ∀ character, rest.head? = some character → keep character = false) :
    nativeSpan keep (word ++ rest) = (word, rest) := by
  induction word with
  | nil =>
    cases rest with
    | nil => rfl
    | cons head tail => simp [nativeSpan, stops head rfl]
  | cons head tail ih =>
    simp only [List.cons_append, nativeSpan, kept head (by simp)]
    rw [ih fun character inside => kept character (by simp [inside])]
    rfl

private theorem head_named : ∀ head : NativeMaudeHead,
    nativeMaudeHeadNamed (nativeMaudeHeadName head) = some head := by
  intro head
  cases head <;> (try rename_i symbol; cases symbol) <;> rfl

private theorem head_alphanumeric : ∀ head : NativeMaudeHead,
    ∀ character ∈ nativeMaudeHeadName head, character.isAlphanum = true := by
  intro head
  cases head <;> (try rename_i symbol; cases symbol) <;> decide

private theorem head_not_variable : ∀ head : NativeMaudeHead, ∀ rest,
    nativeMaudeHeadName head ≠ 'x' :: rest := by
  intro head rest
  cases head <;> (try rename_i symbol; cases symbol) <;> simp [nativeMaudeHeadName, nativeTamarinName]

private theorem sort_named : ∀ sort : QuerySort, nativeMaudeSortNamed (nativeMaudeSortName sort) = some sort := by
  intro sort
  cases sort <;> rfl

private theorem sort_alphanumeric : ∀ sort : QuerySort,
    ∀ character ∈ nativeMaudeSortName sort, character.isAlphanum = true := by
  intro sort
  cases sort <;> decide

private theorem digit_alphanumeric (character : Char) (digit : character.isDigit = true) :
    character.isAlphanum = true := by
  simp [Char.isAlphanum, digit]

-- Every rendered term is followed by end of input, `,` or `)`.
def NativeMaudeStop (rest : List Char) : Prop :=
  rest = [] ∨ (∃ tail, rest = ',' :: tail) ∨ ∃ tail, rest = ')' :: tail

private theorem stop_not_alphanumeric (stop : NativeMaudeStop rest) :
    ∀ character, rest.head? = some character → character.isAlphanum = false := by
  rcases stop with rfl | ⟨tail, rfl⟩ | ⟨tail, rfl⟩ <;> intro character found <;>
    simp at found <;> subst found <;> decide

private theorem head_nonempty : ∀ head : NativeMaudeHead, nativeMaudeHeadName head ≠ [] := by
  intro head
  cases head <;> (try rename_i symbol; cases symbol) <;> decide

private theorem skip_word (word rest : List Char) (nonempty : word ≠ [])
    (alphanumeric : ∀ character ∈ word, character.isAlphanum = true) :
    nativeSkipSpaces (word ++ rest) = word ++ rest := by
  cases word with
  | nil => exact absurd rfl nonempty
  | cons first others =>
    have notSpace : first ≠ ' ' := by
      intro same
      have := alphanumeric first (by simp)
      subst same
      exact absurd this (by decide)
    simp [nativeSkipSpaces, notSpace]

private theorem parse_index (build : Nat → NativeQueryTerm) (index : Nat) (rest : List Char) :
    nativeParseIndex build (nativeDigits index ++ ')' :: rest) = some (build index, rest) := by
  rw [nativeParseIndex, span_append _ _ _ (digits_digit index) (by intro c found; simp at found; subst found; decide)]
  simp [decimal_digits]

private theorem parse_constant (head : NativeMaudeHead) (term : NativeQueryTerm)
    (applied : nativeMaudeApply head [] = some term) (stop : NativeMaudeStop rest) (fuel : Nat) :
    nativeParseTerm (fuel + 1) (nativeMaudeHeadName head ++ rest) = some (term, rest) := by
  have skipped := skip_word (nativeMaudeHeadName head) rest (head_nonempty head) (head_alphanumeric head)
  rw [nativeParseTerm, skipped,
    span_append _ _ _ (head_alphanumeric head) (stop_not_alphanumeric stop)]
  cases head <;> (try rename_i symbol; cases symbol) <;>
    simp only [nativeMaudeApply, reduceCtorEq, Option.some.injEq] at applied <;> subst applied <;>
    rcases stop with rfl | ⟨tail, rfl⟩ | ⟨tail, rfl⟩ <;> rfl

private theorem parse_application (head : NativeMaudeHead) (arguments : List NativeQueryTerm)
    (term : NativeQueryTerm) (body rest : List Char) (fuel : Nat)
    (notAtom : nativeMaudeAtom head = none)
    (parsed : nativeParseArguments fuel body = some (arguments, rest))
    (applied : nativeMaudeApply head arguments = some term) :
    nativeParseTerm (fuel + 1) (nativeMaudeHeadName head ++ '(' :: body) = some (term, rest) := by
  have skipped := skip_word (nativeMaudeHeadName head) ('(' :: body) (head_nonempty head)
    (head_alphanumeric head)
  rw [nativeParseTerm, skipped, span_append _ _ _ (head_alphanumeric head) (by
    intro character found; simp at found; subst found; decide)]
  cases named : nativeMaudeHeadName head with
  | nil => exact absurd named (head_nonempty head)
  | cons first others =>
    rw [← named]
    simp only [head_named, notAtom, parsed, applied, Option.map_some]

private theorem parse_atom (head : NativeMaudeHead) (build : Nat → NativeQueryTerm)
    (atom : nativeMaudeAtom head = some build) (index : Nat) (rest : List Char) (fuel : Nat) :
    nativeParseTerm (fuel + 1) (nativeMaudeHeadName head ++ '(' :: (nativeDigits index ++ ')' :: rest)) =
      some (build index, rest) := by
  have skipped := skip_word (nativeMaudeHeadName head) ('(' :: (nativeDigits index ++ ')' :: rest))
    (head_nonempty head) (head_alphanumeric head)
  rw [nativeParseTerm, skipped, span_append _ _ _ (head_alphanumeric head) (by
    intro character found; simp at found; subst found; decide)]
  cases named : nativeMaudeHeadName head with
  | nil => exact absurd named (head_nonempty head)
  | cons first others =>
    rw [← named]
    simp only [head_named, atom]
    exact parse_index build index rest

private abbrev NativeRoundTrip (term : NativeQueryTerm) : Prop :=
  ∀ fuel rest, nativeMaudeFuel term ≤ fuel → NativeMaudeStop rest →
    nativeParseTerm fuel (nativeMaudeChars term ++ rest) = some (term, rest)

private theorem arguments_last (roundTrip : NativeRoundTrip term) (fuel : Nat)
    (enough : nativeMaudeFuel term + 1 ≤ fuel) (rest : List Char) :
    nativeParseArguments fuel (nativeMaudeChars term ++ ')' :: rest) = some ([term], rest) := by
  obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
  rw [nativeParseArguments, roundTrip fuel (')' :: rest) (by omega) (.inr (.inr ⟨rest, rfl⟩))]
  simp [nativeSkipSpaces]

private theorem arguments_next (roundTrip : NativeRoundTrip term) (fuel : Nat)
    (enough : nativeMaudeFuel term + 1 ≤ fuel) (tail rest : List Char) (terms : List NativeQueryTerm)
    (remaining : nativeParseArguments (fuel - 1) tail = some (terms, rest)) :
    nativeParseArguments fuel (nativeMaudeChars term ++ ',' :: tail) = some (term :: terms, rest) := by
  obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
  rw [nativeParseArguments, roundTrip fuel (',' :: tail) (by omega) (.inr (.inl ⟨tail, rfl⟩))]
  simp only [Nat.add_sub_cancel] at remaining
  simp [nativeSkipSpaces, remaining]

private theorem round_trip : ∀ term, NativeRoundTrip term := by
  intro term
  induction term with
  | atom sort index =>
    intro fuel rest enough _
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    cases sort
    · simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
      exact parse_atom .publicAtom _ rfl index rest fuel
    · simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
      exact parse_atom .freshAtom _ rfl index rest fuel
    · simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
      exact parse_atom .messageAtom _ rfl index rest fuel
  | naturalAtom index =>
    intro fuel rest enough _
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_atom .naturalAtom _ rfl index rest fuel
  | nodeAtom index =>
    intro fuel rest enough _
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_atom .nodeAtom _ rfl index rest fuel
  | queryVariable sort index =>
    intro fuel rest enough stop
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    have spanned := span_append Char.isAlphanum ('x' :: nativeDigits index) (':' :: nativeMaudeSortName sort ++ rest)
      (by
        intro character inside
        rcases List.mem_cons.mp inside with rfl | digit
        · decide
        · exact digit_alphanumeric character (digits_digit index character digit))
      (by intro character found; simp at found; subst found; decide)
    simp only [nativeMaudeChars, List.cons_append, List.append_assoc] at spanned ⊢
    rw [nativeParseTerm]
    simp only [nativeSkipSpaces, show ('x' = ' ') = False by decide, ↓reduceIte]
    rw [spanned]
    simp only [nativeParseVariable]
    rw [span_append _ _ _ (sort_alphanumeric sort) (stop_not_alphanumeric stop)]
    simp [sort_named, decimal_digits]
  | naturalOne =>
    intro fuel rest enough stop
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    exact parse_constant .one _ rfl stop fuel
  | roleA =>
    intro fuel rest enough stop
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    exact parse_constant .roleA _ rfl stop fuel
  | roleB =>
    intro fuel rest enough stop
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    exact parse_constant .roleB _ rfl stop fuel
  | nil =>
    intro fuel rest enough stop
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by simp [nativeMaudeFuel] at enough; omega⟩
    exact parse_constant .nil _ rfl stop fuel
  | naturalAdd left right leftTrip rightTrip =>
    intro fuel rest enough _
    simp only [nativeMaudeFuel] at enough
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_application .add [left, right] _ _ _ fuel rfl
      (arguments_next leftTrip fuel (by omega) _ rest [right]
        (arguments_last rightTrip (fuel - 1) (by omega) rest)) rfl
  | unary symbol argument trip =>
    intro fuel rest enough _
    simp only [nativeMaudeFuel] at enough
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_application (.unary symbol) [argument] _ _ _ fuel rfl
      (arguments_last trip fuel (by omega) rest) rfl
  | binary symbol left right leftTrip rightTrip =>
    intro fuel rest enough _
    simp only [nativeMaudeFuel] at enough
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_application (.binary symbol) [left, right] _ _ _ fuel rfl
      (arguments_next leftTrip fuel (by omega) _ rest [right]
        (arguments_last rightTrip (fuel - 1) (by omega) rest)) rfl
  | kdf first second third firstTrip secondTrip thirdTrip =>
    intro fuel rest enough _
    simp only [nativeMaudeFuel] at enough
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_application .kdf [first, second, third] _ _ _ fuel rfl
      (arguments_next firstTrip fuel (by omega) _ rest [second, third]
        (arguments_next secondTrip (fuel - 1) (by omega) _ rest [third]
          (arguments_last thirdTrip (fuel - 1 - 1) (by omega) rest))) rfl
  | list argument trip =>
    intro fuel rest enough _
    simp only [nativeMaudeFuel] at enough
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_application .list [argument] _ _ _ fuel rfl
      (arguments_last trip fuel (by omega) rest) rfl
  | cons first others firstTrip othersTrip =>
    intro fuel rest enough _
    simp only [nativeMaudeFuel] at enough
    obtain ⟨fuel, rfl⟩ : ∃ smaller, fuel = smaller + 1 := ⟨fuel - 1, by omega⟩
    simp only [nativeMaudeChars, List.append_assoc, List.cons_append, List.nil_append]
    exact parse_application .cons [first, others] _ _ _ fuel rfl
      (arguments_next firstTrip fuel (by omega) _ rest [others]
        (arguments_last othersTrip (fuel - 1) (by omega) rest)) rfl

private theorem fuel_length : ∀ term, nativeMaudeFuel term ≤ (nativeMaudeChars term).length := by
  intro term
  induction term with
  | naturalOne | roleA | roleB | nil =>
    simp [nativeMaudeFuel, nativeMaudeChars, nativeMaudeHeadName, nativeTamarinName]
  | atom sort index => cases sort <;> simp [nativeMaudeFuel, nativeMaudeChars, nativeMaudeHeadName]
  | naturalAtom | nodeAtom | queryVariable => simp [nativeMaudeFuel, nativeMaudeChars, nativeMaudeHeadName]
  | naturalAdd _ _ left right | binary _ _ _ left right | cons _ _ left right =>
    simp only [nativeMaudeFuel, nativeMaudeChars, List.length_append, List.length_cons]; omega
  | unary _ _ inner | list _ inner =>
    simp only [nativeMaudeFuel, nativeMaudeChars, List.length_append, List.length_cons]; omega
  | kdf _ _ _ first second third =>
    simp only [nativeMaudeFuel, nativeMaudeChars, List.length_append, List.length_cons]; omega

theorem native_maude_parse_render (term : NativeQueryTerm) :
    nativeMaudeParse (nativeMaudeTerm term) = some term := by
  rw [nativeMaudeParse, nativeMaudeTerm, String.toList_ofList]
  have parsed := round_trip term ((nativeMaudeChars term).length + 1) []
    (by have := fuel_length term; omega) (.inl rfl)
  rw [List.append_nil] at parsed
  simp [parsed, nativeSkipSpaces]

theorem native_maude_term_injective {left right : NativeQueryTerm}
    (same : nativeMaudeTerm left = nativeMaudeTerm right) : left = right := by
  have parsed := native_maude_parse_render left
  rw [same, native_maude_parse_render] at parsed
  exact (Option.some.inj parsed).symm

/-! Rule templates: the six `[variant]` equations of the native module. -/

def nativeRuleVariable (index : Nat) : NativeQueryTerm := .queryVariable .message index

def nativeFlipARule : NativeQueryTerm × NativeQueryTerm := (.unary .flip .roleA, .roleB)
def nativeFlipBRule : NativeQueryTerm × NativeQueryTerm := (.unary .flip .roleB, .roleA)
def nativeFstRule : NativeQueryTerm × NativeQueryTerm :=
  (.unary .fst (.binary .pair (nativeRuleVariable 0) (nativeRuleVariable 1)), nativeRuleVariable 0)
def nativeKdecRule : NativeQueryTerm × NativeQueryTerm :=
  (.binary .kdec (.binary .kem (nativeRuleVariable 0) (.unary .pk (nativeRuleVariable 1)))
    (nativeRuleVariable 1), nativeRuleVariable 0)
def nativeSdecRule : NativeQueryTerm × NativeQueryTerm :=
  (.binary .sdec (.binary .senc (nativeRuleVariable 0) (nativeRuleVariable 1)) (nativeRuleVariable 1),
    nativeRuleVariable 0)
def nativeSndRule : NativeQueryTerm × NativeQueryTerm :=
  (.unary .snd (.binary .pair (nativeRuleVariable 0) (nativeRuleVariable 1)), nativeRuleVariable 1)

-- Listed in the module's lexicographic equation order.
def nativeRuleTemplates : List (NativeQueryTerm × NativeQueryTerm) :=
  [nativeFlipARule, nativeFlipBRule, nativeFstRule, nativeKdecRule, nativeSdecRule, nativeSndRule]

theorem native_rule_templates_sound (rule : NativeQueryTerm × NativeQueryTerm)
    (listed : rule ∈ nativeRuleTemplates) (assignment : QuerySort → Nat → NativeQueryTerm) :
    NativePrimitiveRewrite (substituteNativeQuery assignment rule.1)
      (substituteNativeQuery assignment rule.2) := by
  simp only [nativeRuleTemplates, List.mem_cons, List.not_mem_nil, or_false] at listed
  rcases listed with rfl | rfl | rfl | rfl | rfl | rfl <;> constructor

theorem native_rule_templates_complete :
    NativePrimitiveRewrite left right → ∃ rule ∈ nativeRuleTemplates,
      ∃ assignment : QuerySort → Nat → NativeQueryTerm,
        substituteNativeQuery assignment rule.1 = left ∧ substituteNativeQuery assignment rule.2 = right
  | .flipA => ⟨nativeFlipARule, by simp [nativeRuleTemplates], fun _ _ => .nil, rfl, rfl⟩
  | .flipB => ⟨nativeFlipBRule, by simp [nativeRuleTemplates], fun _ _ => .nil, rfl, rfl⟩
  | @NativePrimitiveRewrite.fst first second => ⟨nativeFstRule, by simp [nativeRuleTemplates],
      fun _ index => if index = 0 then first else second, rfl, rfl⟩
  | @NativePrimitiveRewrite.snd first second => ⟨nativeSndRule, by simp [nativeRuleTemplates],
      fun _ index => if index = 0 then first else second, rfl, rfl⟩
  | @NativePrimitiveRewrite.sdec payload key => ⟨nativeSdecRule, by simp [nativeRuleTemplates],
      fun _ index => if index = 0 then payload else key, rfl, rfl⟩
  | @NativePrimitiveRewrite.kdec payload key => ⟨nativeKdecRule, by simp [nativeRuleTemplates],
      fun _ index => if index = 0 then payload else key, rfl, rfl⟩

/-! Module text rendered from the head inventory and rule templates. -/

def nativeMaudeFunctionHeads : List NativeMaudeHead := [
  .binary .ext, .unary .flip, .unary .fst, .unary .hash, .binary .kdec, .kdf, .binary .kem,
  .binary .mac, .binary .pair, .unary .pk, .roleA, .roleB, .binary .sdec, .binary .senc, .unary .snd
]

def nativeMaudeArity : NativeMaudeHead → Nat
  | .unary _ | .list => 1
  | .binary _ | .add | .cons => 2
  | .kdf => 3
  | _ => 0

theorem native_maude_function_heads_complete :
    (∀ symbol, .unary symbol ∈ nativeMaudeFunctionHeads) ∧
      (∀ symbol, .binary symbol ∈ nativeMaudeFunctionHeads) ∧
      NativeMaudeHead.kdf ∈ nativeMaudeFunctionHeads ∧ NativeMaudeHead.roleA ∈ nativeMaudeFunctionHeads ∧
      NativeMaudeHead.roleB ∈ nativeMaudeFunctionHeads := by
  refine ⟨fun symbol => ?_, fun symbol => ?_, ?_, ?_, ?_⟩ <;>
    (try cases symbol) <;> simp [nativeMaudeFunctionHeads]

def nativeMaudeModule : String :=
  let declaration (head : NativeMaudeHead) : String :=
    s!"op {String.ofList (nativeMaudeHeadName head)} : " ++
      String.join (List.replicate (nativeMaudeArity head) "Msg ") ++ "-> Msg ."
  let equation (rule : NativeQueryTerm × NativeQueryTerm) : String :=
    s!"eq {nativeMaudeTerm rule.1} = {nativeMaudeTerm rule.2} [variant] ."
  let lines := [
    "fmod MSG is", "protecting NAT .", "sort Pub Fresh Msg Node TamNat TOP .",
    "subsort Pub < Msg .", "subsort Fresh < Msg .", "subsort TamNat < Msg .",
    "subsort Msg < TOP .", "subsort Node < TOP .",
    "op f : Nat -> Fresh .", "op p : Nat -> Pub .", "op c : Nat -> Msg .",
    "op n : Nat -> Node .", "op t : Nat -> TamNat .",
    "op list : TOP -> TOP .", "op cons : TOP TOP -> TOP .", "op nil : -> TOP .",
    "op tamXCtone : -> TamNat .", "op tamtplus : TamNat TamNat -> TamNat [comm assoc] ."
  ] ++ nativeMaudeFunctionHeads.map declaration ++ nativeRuleTemplates.map equation ++ ["endfm"]
  String.join (lines.map (· ++ "\n"))

#print axioms native_maude_parse_render
#print axioms native_maude_term_injective
#print axioms native_rule_templates_sound
#print axioms native_rule_templates_complete
#print axioms native_maude_function_heads_complete

end Cairn.Equations
