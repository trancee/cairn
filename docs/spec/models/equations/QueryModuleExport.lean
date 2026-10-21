import QueryModule
import QueryInstances
import QueryPrincipalSort

namespace Cairn.Equations

/-! The Lean-rendered native module followed by the recognizer differential corpus.

`ACCEPT` lines carry the expected Maude sort, variables and atoms of a well-sorted rendered term.
`REJECT` lines are single-character deletions that `nativeMaudeParse` rejects; by
`native_maude_parse_render` none of them is the rendering of any query term. -/

def nativeFramedCheck : NativeQueryTerm → Bool
  | .nodeAtom _ | .queryVariable .node _ | .nil => true
  | .list argument => nativeFramedCheck argument
  | .cons first rest => nativeFramedCheck first && nativeFramedCheck rest
  | term => (decodeNativeMessage term).isSome

def nativeExpectedSort (term : NativeQueryTerm) : Option String :=
  match nativePrincipalSort term with
  | some sort => some (String.ofList (nativeMaudeSortName sort))
  | none => if nativeFramedCheck term then some "TOP" else none

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

private def deletions (characters : List Char) : List (List Char) :=
  (List.range characters.length).map characters.eraseIdx

def nativeSyntaxLines : List String :=
  let accepted := nativeSyntaxCorpus.filterMap fun term =>
    (nativeExpectedSort term).map fun sort =>
      s!"ACCEPT\t{sort}\t{nativeMaudeTerm term}\t" ++
        s!"{field ((nativeQueryVariables term).map fun entry =>
          nativeMaudeTerm (.queryVariable entry.1 entry.2))}\t{field (nativeQueryAtoms term)}"
  let rejected := (nativeSyntaxCorpus.flatMap fun term => deletions (nativeMaudeChars term)).filterMap
    fun characters =>
      let text := String.ofList characters
      if (nativeMaudeParse text).isNone then some s!"REJECT\t{text}" else none
  accepted.eraseDups ++ rejected.eraseDups

#guard nativeSyntaxCorpus.all fun term => (nativeExpectedSort term).isSome

#eval do
  IO.print nativeMaudeModule
  nativeSyntaxLines.forM fun line => IO.println line

end Cairn.Equations
