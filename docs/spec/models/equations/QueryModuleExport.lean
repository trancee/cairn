import QueryModule
import QueryInstances
import QueryPrincipalSort
import QueryKind
import QueryACCanonical
import QuerySyntacticUnification
import QueryNormalization
import QueryVariantCertificate

namespace Cairn.Equations

/-! The Lean-rendered native module followed by the recognizer differential corpus.

`ACCEPT` lines carry the expected sort, variables and atoms of a rendered term: its proper Maude
sort, or else its controlled kind (`KindNatural`, `KindMessage`, `KindFraming`) under
`kindAbstraction`, which reads `Fresh` as natural. `REJECT` lines are rendered terms with neither,
and single-character deletions that `nativeMaudeParse` rejects; by `native_maude_parse_render`
none of the deletions is the rendering of any query term. Flattened n-ary sums appear as Maude
prints them, classified by the right-nested term `nativeMaudeParse` reads. -/

def nativeFramedCheck : NativeQueryTerm → Bool
  | .nodeAtom _ | .queryVariable .node _ | .nil => true
  | .list argument => nativeFramedCheck argument
  | .cons first rest => nativeFramedCheck first && nativeFramedCheck rest
  | term => (decodeNativeMessage term).isSome

def nativeExpectedSort (term : NativeQueryTerm) : Option String :=
  match nativePrincipalSort term with
  | some sort => some (String.ofList (nativeMaudeSortName sort))
  | none => if nativeFramedCheck term then some "TOP" else none

def nativeExpectedKind (term : NativeQueryTerm) : Option String :=
  match nativeExpectedSort term with
  | some sort => some sort
  | none =>
    let abstracted := relabelNative kindAbstraction term
    if (decodeNativeNatural abstracted).isSome then some "KindNatural"
    else if (decodeNativeMessage abstracted).isSome then some "KindMessage"
    else if nativeFramedCheck abstracted then some "KindFraming"
    else none

def nativeQueryAtoms : NativeQueryTerm → List String
  | .atom .publicAtom index => [s!"p:{index}"]
  | .atom .freshAtom index => [s!"f:{index}"]
  | .atom .messageAtom index => [s!"c:{index}"]
  | .naturalAtom index => [s!"t:{index}"]
  | .nodeAtom index => [s!"n:{index}"]
  | .queryVariable _ _ | .naturalOne | .roleA | .roleB | .nil => []
  | .unary _ argument | .list argument => nativeQueryAtoms argument
  | .naturalAdd left right | .binary _ left right | .cons left right =>
    nativeQueryAtoms left ++ nativeQueryAtoms right
  | .kdf first second third =>
    nativeQueryAtoms first ++ nativeQueryAtoms second ++ nativeQueryAtoms third

private def field (entries : List String) : String :=
  if entries.isEmpty then "-" else " ".intercalate entries.eraseDups

private def message (index : Nat) : NativeQueryTerm := .queryVariable .message index
private def natural (index : Nat) : NativeQueryTerm := .queryVariable .natural index

def nativeSyntaxCorpus : List NativeQueryTerm :=
  let indices := [0, 7, 10, 105]
  let leaves := indices.flatMap fun index => [
    .atom .publicAtom index, .atom .freshAtom index, .atom .messageAtom index,
    .naturalAtom index, .nodeAtom index,
    .queryVariable .publicAtom index, .queryVariable .freshAtom index,
    .queryVariable .message index, .queryVariable .natural index, .queryVariable .node index
  ]
  let unaries := [UnarySymbol.flip, .fst, .hash, .pk, .snd].map fun symbol =>
    NativeQueryTerm.unary symbol (message 3)
  let binaries := [BinarySymbol.ext, .kdec, .kem, .mac, .pair, .sdec, .senc].map fun symbol =>
    NativeQueryTerm.binary symbol (.atom .publicAtom 12) (natural 4)
  let composites : List NativeQueryTerm := [
    .naturalOne, .roleA, .roleB, .nil,
    .naturalAdd (natural 0) .naturalOne,
    .naturalAdd (.naturalAtom 2) (.naturalAdd (natural 1) .naturalOne),
    .naturalAdd (.naturalAdd (natural 1) (natural 2)) (.naturalAtom 30),
    .unary .flip .roleA,
    .kdf (message 0) (.naturalAdd (natural 1) .naturalOne) (.unary .hash (.atom .freshAtom 9)),
    .binary .sdec (.binary .senc (message 0) (message 1)) (message 1),
    .binary .kdec (.binary .kem (message 0) (.unary .pk (message 1))) (message 1),
    .list (message 0), .list .nil,
    .list (.cons (.unary .fst (message 0)) (.cons (.nodeAtom 4) (.cons (.queryVariable .node 2) .nil))),
    .cons (.nodeAtom 0) (.list (.atom .messageAtom 3))
  ]
  leaves ++ unaries ++ binaries ++ composites ++
    nativeRuleTemplates.flatMap (fun rule => [rule.1, rule.2])

private def fresh (index : Nat) : NativeQueryTerm := .queryVariable .freshAtom index

-- Fresh operands of natural sums and every context above them.
def nativeKindCorpus : List NativeQueryTerm :=
  let sums : List NativeQueryTerm := [
    .naturalAdd (fresh 0) (natural 1), .naturalAdd (.atom .freshAtom 2) .naturalOne,
    .naturalAdd (natural 0) (.naturalAdd (fresh 1) (.naturalAtom 5)),
    .naturalAdd (fresh 0) (fresh 0)
  ]
  sums ++ sums.flatMap fun sum => [
    .unary .hash sum, .binary .pair (message 0) sum, .kdf sum (message 1) .roleA,
    .unary .fst (.binary .senc sum (message 2)), .list sum, .cons sum .nil,
    .list (.cons (.nodeAtom 1) (.cons (.unary .pk sum) .nil))
  ]

-- Parse-valid terms with neither a proper sort nor a controlled kind.
def nativeIllSortedCorpus : List NativeQueryTerm := [
  .naturalAdd (message 0) (natural 1), .naturalAdd (.atom .publicAtom 0) .naturalOne,
  .naturalAdd (.queryVariable .node 0) (natural 1), .naturalAdd .roleA (natural 1),
  .naturalAdd (.unary .hash (natural 0)) (natural 1), .naturalAdd .nil (natural 0),
  .naturalAdd (.naturalAdd (fresh 0) (.unary .hash (fresh 1))) .naturalOne,
  .unary .hash .nil, .unary .hash (.nodeAtom 0), .unary .hash (.queryVariable .node 0),
  .unary .fst (.list (message 0)), .binary .pair (message 0) (.cons (message 1) .nil),
  .kdf (message 0) (message 1) (.nodeAtom 2),
  .unary .hash (.naturalAdd (fresh 0) (.atom .publicAtom 1)),
  .list (.naturalAdd (message 0) .naturalOne), .cons (.unary .hash .nil) .nil
]

-- Flattened AC sums as Maude prints them; `nativeMaudeParse` right-nests them.
def nativeFlatSumTexts : List String := [
  "tamtplus(x0:TamNat,x1:TamNat,tamXCtone)",
  "tamtplus(tamXCtone,tamXCtone,tamXCtone,tamXCtone)",
  "tamtplus(t(3),x0:TamNat,tamXCtone,x0:TamNat)",
  "tamtplus(x0:Fresh,x1:TamNat,tamXCtone)",
  "tamtplus(x0:TamNat,x1:TamNat,f(4))",
  "tamXCh(tamtplus(x0:TamNat,tamXCtone,x1:Fresh))",
  "tamXCkdf(x0:Msg,tamtplus(x1:TamNat,tamXCtone,tamXCtone),tamXCroleA)",
  "list(tamtplus(x0:TamNat,x1:TamNat,x2:TamNat))",
  "tamtplus(x0:TamNat,x1:TamNat,x2:Msg)",
  "tamtplus(x0:TamNat,tamXCtone,nil)",
  "tamtplus(x0:Fresh,x1:TamNat,tamXCh(x2:TamNat))",
  "tamtplus(x0:TamNat,tamXCtone,x1:Node)"
]

def nativeFlatSumCorpus : List (String × NativeQueryTerm) :=
  nativeFlatSumTexts.filterMap fun text => (nativeMaudeParse text).map (text, ·)

private def deletions (characters : List Char) : List (List Char) :=
  (List.range characters.length).map characters.eraseIdx

private def leftSum : List NativeQueryTerm → NativeQueryTerm
  | [] => .naturalOne
  | first :: rest => rest.foldl .naturalAdd first

private def arrangements (terms : List NativeQueryTerm) : List NativeQueryTerm :=
  [nativeACRebuild terms, leftSum terms, nativeACRebuild terms.reverse,
    leftSum (terms.rotateLeft 1), nativeACRebuild (terms.rotateRight 1)].eraseDups

-- Summand multisets whose bracketings and orders are compared in every context.
private def nativeACSumGroups : List (List NativeQueryTerm) := [
  [natural 0, natural 1], [natural 0, natural 1, .naturalOne],
  [natural 0, natural 0, .naturalOne], [natural 0, .naturalOne, .naturalOne],
  [natural 0, natural 1, natural 2, .naturalOne], [fresh 0, natural 1, .naturalOne],
  [.naturalAtom 3, natural 0, .naturalOne],
  [.unary .hash (.naturalAdd (natural 0) (natural 1)), natural 2],
  [.unary .hash (.naturalAdd (natural 1) (natural 0)), natural 2, natural 2]
]

private def nativeACContexts : List (NativeQueryTerm → NativeQueryTerm) := [
  id, .unary .hash, (.binary .pair · (message 0)), (.kdf (message 0) · .roleA), .list,
  (.cons · .nil), (.naturalAdd · (natural 9))
]

private def nativeACNearMisses : List (NativeQueryTerm × NativeQueryTerm) := [
  (.naturalAdd (.unary .hash (.naturalAdd (natural 0) (natural 1))) (natural 2),
    .naturalAdd (natural 2) (.unary .hash (.naturalAdd (natural 1) (natural 0)))),
  (.binary .pair (natural 0) (natural 1), .binary .pair (natural 1) (natural 0)),
  (.naturalAdd (.unary .hash (natural 0)) (natural 1),
    .naturalAdd (.unary .hash (natural 1)) (natural 0)),
  (.naturalAdd (natural 0) (natural 0), natural 0),
  (.naturalAdd (natural 0) (.naturalAdd (natural 0) (natural 1)),
    .naturalAdd (natural 1) (.naturalAdd (natural 1) (natural 0))),
  (.kdf (.naturalAdd (natural 0) (natural 1)) (message 0) (message 1),
    .kdf (message 0) (.naturalAdd (natural 1) (natural 0)) (message 1)),
  (.cons (.naturalAdd (natural 0) .naturalOne) .nil, .cons (.naturalAdd .naturalOne (natural 0)) .nil),
  (.naturalAdd (natural 0) .naturalOne, .naturalAdd (natural 0) (.naturalAtom 1))
]

private def acLine (left : String) (right : String) (verdict : Bool) : String :=
  s!"{if verdict then "EQUAL" else "DISTINCT"}\t{left}\t{right}"

-- AC pairs whose verdicts are `nativeACEqual`, decided by `native_ac_equal_iff`.
def nativeACPairLines : List String :=
  let firsts := nativeACSumGroups.filterMap fun group => (arrangements group).head?
  let terms : List (NativeQueryTerm × NativeQueryTerm) := nativeACContexts.flatMap fun context =>
    (nativeACSumGroups.flatMap fun group =>
      let options := arrangements group
      options.flatMap fun left => (options.dropWhile (· != left)).drop 1 |>.map fun right =>
        (context left, context right)) ++
    (firsts.zip (firsts.drop 1)).map fun (left, right) => (context left, context right)
  let rendered := (terms ++ nativeACNearMisses).map fun (left, right) =>
    acLine (nativeMaudeTerm left) (nativeMaudeTerm right) (nativeACEqual left right)
  let flat := nativeFlatSumCorpus.flatMap fun (text, term) =>
    let shorter := nativeACRebuild (nativeACSummands term).tail
    [acLine text (nativeMaudeTerm (nativeACCanonical term)) true,
      acLine text (nativeMaudeTerm shorter) (nativeACEqual term shorter)]
  rendered ++ flat

private def resultLine (tag problem : String) : NativeSyntacticResult → String
  | .solved bindings => s!"{tag}\t{problem}\tSOLVED\t" ++ (if bindings.isEmpty then "-" else
      " ; ".intercalate (bindings.map fun (key, value) =>
        s!"{nativeMaudeTerm (.queryVariable key.1 key.2)} --> {nativeMaudeTerm value}"))
  | .failed => s!"{tag}\t{problem}\tFAILED\t-"
  | .unsupported => s!"{tag}\t{problem}\tUNSUPPORTED\t-"

private def problemText (relation : String) (pairs : List (NativeQueryTerm × NativeQueryTerm)) :
    String :=
  " /\\ ".intercalate (pairs.map fun (left, right) =>
    s!"{nativeMaudeTerm left} {relation} {nativeMaudeTerm right}")

private def publicVariable (index : Nat) : NativeQueryTerm := .queryVariable .publicAtom index
private def nodeVariable (index : Nat) : NativeQueryTerm := .queryVariable .node index

-- Small terms of every sort whose pairwise problems cover variable/variable sort combinations.
private def nativeSyntacticTerms : List NativeQueryTerm := [
  publicVariable 0, fresh 0, message 0, natural 0, nodeVariable 0, message 1,
  .atom .publicAtom 0, .atom .freshAtom 0, .atom .messageAtom 0, .naturalAtom 0, .nodeAtom 0,
  .naturalOne, .roleA, .unary .hash (message 0), .binary .pair (message 1) (.atom .messageAtom 0),
  .naturalAdd (natural 0) .naturalOne, .nil, .list .nil, .cons (nodeVariable 0) .nil
]

-- Sums sharing, lacking and nesting summands exercise every cancellation remainder.
private def nativeSumTerms : List NativeQueryTerm :=
  let one := NativeQueryTerm.naturalOne
  [ one, natural 0, .naturalAtom 0,
    .naturalAdd one one, .naturalAdd one (.naturalAdd one one), .naturalAdd (.naturalAdd one one) one,
    .naturalAdd (natural 0) one, .naturalAdd one (natural 0), .naturalAdd (natural 0) (.naturalAdd one one),
    .naturalAdd (natural 1) one, .naturalAdd (natural 0) (natural 1), .naturalAdd (.naturalAtom 0) one,
    .naturalAdd (.naturalAtom 0) (.naturalAtom 1), .naturalAdd (natural 0) (.naturalAtom 0),
    .naturalAdd (.naturalAdd (.naturalAtom 0) one) (natural 1), .naturalAdd (fresh 0) one,
    .naturalAdd one (.naturalAdd (.naturalAtom 0) one) ]

private def allPairs (terms : List NativeQueryTerm) : List (List (NativeQueryTerm × NativeQueryTerm)) :=
  terms.flatMap fun left => terms.map fun right => [(left, right)]

def nativeUnifySystems : List NativeEquationSystem :=
  allPairs nativeSyntacticTerms ++ allPairs nativeSumTerms ++ [
    [(.binary .pair (message 0) (message 1), .binary .pair (.atom .messageAtom 1) (.unary .hash (message 0)))],
    [(.binary .pair (message 0) (message 1), .binary .senc (message 0) (message 1))],
    [(.unary .hash (message 0), message 1)],
    [(message 0, message 1), (message 1, .atom .messageAtom 2)],
    [(message 0, .binary .pair (message 1) (message 2)), (message 1, .binary .pair (message 0) (message 2))],
    [(.list (.cons (nodeVariable 0) .nil), .list (.cons (.nodeAtom 1) .nil))],
    [(.cons (message 0) .nil, .cons (nodeVariable 1) .nil)],
    [(message 0, .naturalAdd (message 1) .naturalOne)],
    [(natural 0, .naturalAdd (message 1) .naturalOne)],
    [(publicVariable 0, message 1), (message 1, .atom .freshAtom 0)],
    [(message 0, publicVariable 1), (message 0, .atom .publicAtom 3)],
    [(.kdf (message 0) (natural 1) .roleA, .kdf (.unary .pk (message 2)) .naturalOne (message 3))],
    [(.kdf (message 0) (natural 1) .roleA, .kdf (message 2) (fresh 3) (message 3))],
    [(.binary .pair (message 0) (message 0), .binary .pair (message 1) (.unary .hash (message 1)))],
    [(message 0, message 0), (natural 1, .naturalAtom 2)],
    [(message 0, message 1), (message 1, message 2), (message 2, message 3), (message 3, .roleB)],
    [(.naturalAdd (natural 0) (natural 1), .naturalAdd (natural 0) (natural 1))],
    [(.unary .hash (.naturalAdd (natural 0) .naturalOne), .unary .hash (message 1))],
    [(.unary .hash (.naturalAdd (natural 0) .naturalOne), .unary .hash (.naturalAdd .naturalOne (natural 0)))]
  ]

def nativeMatchProblems : List (List (NativeQueryTerm × NativeQueryTerm)) :=
  allPairs nativeSyntacticTerms ++ allPairs nativeSumTerms ++ [
    [(.binary .pair (message 0) (message 0), .binary .pair (message 1) (message 1))],
    [(.binary .pair (message 0) (message 0), .binary .pair (message 1) (message 2))],
    [(.binary .pair (message 0) (message 0), .binary .pair (.naturalAdd (natural 1) .naturalOne)
      (.naturalAdd .naturalOne (natural 1)))],
    [(.binary .pair (message 0) (message 0), .binary .pair (.naturalAdd (natural 1) .naturalOne)
      (.naturalAdd .naturalOne (natural 2)))],
    [(message 0, message 1), (message 0, message 1)],
    [(message 0, message 1), (message 0, message 2)],
    [(publicVariable 0, .atom .publicAtom 1), (message 1, .unary .hash (publicVariable 0))],
    [(.list (.cons (nodeVariable 0) (.cons (nodeVariable 1) .nil)), .list (.cons (.nodeAtom 1) (.cons (.nodeAtom 2) .nil)))],
    [(.kdf (message 0) (natural 1) .roleA, .kdf (.unary .pk (message 2)) .naturalOne .roleA)],
    [(.kdf (message 0) (natural 1) .roleA, .kdf (message 2) (fresh 3) .roleA)]
  ]

def nativeSyntacticLines : List String :=
  nativeUnifySystems.map (fun system => resultLine "UNIFY" (problemText "=?" system)
    (nativeSyntacticUnify nativeSyntacticFuel system)) ++
  nativeMatchProblems.map fun pairs => resultLine "MATCH" (problemText "<=?" pairs)
    (nativeSyntacticMatch nativeSyntacticFuel pairs [])

-- Root redex shapes over proper and improper arguments, AC-equal and distinct keys, nesting
-- and near-miss shapes, so every guard of every rule both fires and blocks.
private def nativeReduceArguments : List NativeQueryTerm := [
  message 0, .atom .publicAtom 1, fresh 2, .naturalAdd (natural 0) .naturalOne,
  .roleA, .nodeAtom 0, .nil, .naturalAdd (fresh 0) .naturalOne ]

private def nativeReduceKeys : List NativeQueryTerm := [
  message 1, .atom .freshAtom 1, .naturalAdd (.naturalAtom 0) .naturalOne,
  .naturalAdd .naturalOne (.naturalAtom 0), .nodeAtom 1 ]

private def nativeReduceFlips : List NativeQueryTerm :=
  (nativeReduceArguments ++ [NativeQueryTerm.roleB, .unary .flip .roleA]).map (.unary .flip ·)

private def nativeReduceProjections : List NativeQueryTerm :=
  nativeReduceArguments.flatMap fun left => nativeReduceArguments.flatMap fun right =>
    [UnarySymbol.fst, .snd].map fun symbol => .unary symbol (.binary .pair left right)

private def nativeReduceDecryptions : List NativeQueryTerm :=
  nativeReduceArguments.flatMap fun payload => nativeReduceKeys.flatMap fun first =>
    nativeReduceKeys.flatMap fun second => [
      .binary .sdec (.binary .senc payload first) second,
      .binary .kdec (.binary .kem payload (.unary .pk first)) second ]

private def nativeReduceNested : List NativeQueryTerm := [
  .unary .hash (.unary .fst (.binary .pair (.unary .flip .roleB) (.unary .snd (message 0)))),
  .unary .fst (.binary .pair (.unary .fst (.binary .pair (message 0) (message 1))) (message 2)),
  .binary .sdec (.binary .senc (.unary .snd (.binary .pair (message 0) (message 1))) (message 2))
    (.unary .fst (.binary .pair (message 2) .roleA)),
  .binary .kdec (.binary .kem (message 0) (.unary .pk (.unary .flip .roleA))) .roleB,
  .list (.cons (.unary .flip .roleA) (.cons (.nodeAtom 0) .nil)),
  .kdf (.unary .flip .roleB) (.naturalAdd (natural 0) .naturalOne)
    (.unary .fst (.binary .pair .roleA .roleB)),
  .unary .fst (.binary .pair (.list .nil) (message 0)),
  .unary .flip (.unary .hash .roleA),
  .unary .fst (.binary .senc (message 0) (message 1)),
  .binary .sdec (.binary .kem (message 0) (message 1)) (message 1),
  .binary .kdec (.binary .kem (message 0) (message 1)) (message 1),
  .binary .kdec (.binary .kem (message 0) (.unary .hash (message 1))) (message 1),
  .binary .pair (message 0) (.binary .pair (.unary .hash (message 1)) (.unary .hash (message 2))) ]

def nativeReduceLines : List String :=
  (nativeReduceFlips ++ nativeReduceProjections ++ nativeReduceDecryptions ++ nativeReduceNested).map
    fun term => s!"REDUCE\t{nativeMaudeTerm term}\t{nativeMaudeTerm (nativeSortedNormalize term)}"

private def nativeReduceChanges (term : NativeQueryTerm) : Bool :=
  nativeMaudeTerm (nativeSortedNormalize term) != nativeMaudeTerm term

-- Destructors over every argument sort, nested and inside the `list(cons(...))` frames Tamarin
-- sends, so schemes are solved, failed and unsupported.
private def nativeVariantTerms : List NativeQueryTerm :=
  let sum := NativeQueryTerm.naturalAdd (natural 0) (natural 1)
  [ .unary .hash (message 0), .unary .flip (message 0), .unary .flip .roleA,
    .unary .flip (.unary .flip (message 0)), .unary .flip (publicVariable 0),
    .unary .fst (message 0), .unary .snd (message 0), .unary .fst (.unary .snd (message 0)),
    .unary .fst (fresh 0), .unary .snd (.binary .pair (message 0) (message 1)),
    .binary .sdec (message 0) (message 1), .binary .sdec (message 0) (fresh 1),
    .binary .sdec (.binary .senc (message 0) (message 1)) (message 1),
    .binary .sdec (.binary .senc (message 2) sum) (.naturalAdd (natural 3) (natural 4)),
    .binary .sdec (.binary .senc (message 2) sum) (.naturalAdd (natural 1) (natural 0)),
    .binary .sdec (message 2) (.naturalAdd (natural 0) .naturalOne),
    .binary .kdec (message 0) (fresh 1), .binary .kdec (.binary .kem (message 0) (message 1)) (message 2),
    .binary .kdec (.unary .hash (message 0)) (message 1),
    .binary .pair (.unary .flip (message 0)) (.unary .fst (message 1)),
    .kdf (.unary .flip (message 0)) (natural 1) (.binary .kdec (message 2) (fresh 3)),
    .list (.cons (.atom .publicAtom 0) (.cons (.unary .flip (message 1)) (.cons (.nodeAtom 0) .nil))),
    .list (.cons (fresh 2) (.cons (.binary .kdec (message 3) (fresh 2)) (.cons (message 4) .nil))),
    .list (.cons (message 0) (.cons (.unary .hash (message 1)) .nil)) ]

def nativeVariantLines : List String :=
  nativeVariantTerms.flatMap fun term => (nativeVariantSchemeResults term).map fun (scheme, result) =>
    resultLine s!"VARIANT\t{nativeMaudeTerm term}\t{nativeMaudeTerm scheme.1}"
      (problemText "=?" (nativeVariantSystem term scheme)) result

def nativeSyntaxLines : List String :=
  let accepted := (nativeSyntaxCorpus ++ nativeKindCorpus).filterMap fun term =>
    (nativeExpectedKind term).map fun sort =>
      s!"ACCEPT\t{sort}\t{nativeMaudeTerm term}\t" ++
        s!"{field ((nativeQueryVariables term).map fun entry =>
          nativeMaudeTerm (.queryVariable entry.1 entry.2))}\t{field (nativeQueryAtoms term)}"
  let flat := nativeFlatSumCorpus.map fun (text, term) =>
    match nativeExpectedKind term with
    | some sort => s!"ACCEPT\t{sort}\t{text}\t" ++
        s!"{field ((nativeQueryVariables term).map fun entry =>
          nativeMaudeTerm (.queryVariable entry.1 entry.2))}\t{field (nativeQueryAtoms term)}"
    | none => s!"REJECT\t{text}"
  let illSorted := nativeIllSortedCorpus.map fun term => s!"REJECT\t{nativeMaudeTerm term}"
  let rejected := ((nativeSyntaxCorpus ++ nativeKindCorpus).flatMap (fun term =>
      deletions (nativeMaudeChars term)) ++
      nativeFlatSumTexts.flatMap fun text => deletions text.toList).filterMap
    fun characters =>
      let text := String.ofList characters
      if (nativeMaudeParse text).isNone then some s!"REJECT\t{text}" else none
  accepted.eraseDups ++ flat ++ illSorted ++ rejected.eraseDups ++ nativeACPairLines ++
    nativeSyntacticLines ++ nativeReduceLines ++ nativeVariantLines

#guard nativeSyntaxCorpus.all fun term => (nativeExpectedSort term).isSome
#guard nativeKindCorpus.all fun term =>
  (nativeExpectedSort term).isNone && (nativeExpectedKind term).isSome
#guard nativeFlatSumCorpus.length == nativeFlatSumTexts.length
#guard nativeFlatSumCorpus.all fun (text, term) => String.ofList (nativeMaudeChars term) != text
#guard (nativeFlatSumCorpus.filter fun entry => (nativeExpectedKind entry.2).isNone).length == 4
#guard nativeIllSortedCorpus.all fun term => (nativeExpectedKind term).isNone
#guard nativeACSumGroups.all fun group =>
  (arrangements group).length ≥ 2 && (arrangements group).all fun term =>
    nativeACEqual term (nativeACRebuild group)
#guard (nativeACPairLines.filter (·.startsWith "EQUAL")).length ≥ 300
#guard (nativeACPairLines.filter (·.startsWith "DISTINCT")).length ≥ 60
#guard nativeFlatSumCorpus.all fun (_, term) =>
  !nativeACEqual term (nativeACRebuild (nativeACSummands term).tail)
#guard ["UNIFY", "MATCH"].all fun tag => ["SOLVED", "FAILED", "UNSUPPORTED"].all fun status =>
  nativeSyntacticLines.any fun line => line.startsWith tag && (line.splitOn "\t")[2]? == some status
#guard [true, false].all fun solved => (allPairs nativeSumTerms).any fun system =>
  match system, nativeSyntacticUnify nativeSyntacticFuel system with
  | [(.naturalAdd _ _, .naturalAdd _ _)], .solved (_ :: _) => solved
  | [(.naturalAdd _ _, .naturalAdd _ _)], .failed => !solved
  | _, _ => false
#guard [true, false].all fun solved => (allPairs nativeSumTerms).any fun pairs =>
  match pairs, nativeSyntacticMatch nativeSyntacticFuel pairs [] with
  | [(.naturalAdd _ _, .naturalAdd _ _)], .solved (_ :: _) => solved
  | [(.naturalAdd _ _, .naturalAdd _ _)], .failed => !solved
  | _, _ => false
#guard (nativeUnifySystems.filter fun system =>
  match nativeSyntacticUnify nativeSyntacticFuel system with
  | .unsupported => false
  | _ => true).length ≥ 300

#guard [nativeReduceFlips, nativeReduceProjections, nativeReduceDecryptions, nativeReduceNested].all
  fun terms => terms.any nativeReduceChanges && terms.any (!nativeReduceChanges ·)
#guard [true, false].all fun changes => nativeReduceDecryptions.any fun term => match term with
  | .binary .sdec _ (.naturalAdd _ _) => nativeReduceChanges term == changes
  | _ => false
#guard [true, false].all fun changes => nativeReduceDecryptions.any fun term => match term with
  | .binary .kdec _ (.naturalAdd _ _) => nativeReduceChanges term == changes
  | _ => false

#guard ["SOLVED", "FAILED", "UNSUPPORTED"].all fun status =>
  nativeVariantLines.any (·.splitOn "\t" |>.contains status)
#guard nativeVariantTerms.all fun term => (nativeExpectedKind term).isSome
#guard (nativeVariantTerms.filter fun term => (nativeVariantSchemeResults term).length ≥ 3).length ≥ 8

#eval do
  IO.print nativeMaudeModule
  nativeSyntaxLines.forM fun line => IO.println line

end Cairn.Equations
