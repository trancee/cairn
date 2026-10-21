import QueryVariants

namespace Cairn.Equations

def nativeMaudeSort : QuerySort → String
  | .publicAtom => "Pub"
  | .freshAtom => "Fresh"
  | .message => "Msg"
  | .natural => "TamNat"
  | .node => "Node"

def nativeMaudeUnary : UnarySymbol → String
  | .flip => "tamXCflip"
  | .fst => "tamXCfst"
  | .hash => "tamXCh"
  | .pk => "tamXCpk"
  | .snd => "tamXCsnd"

def nativeMaudeBinary : BinarySymbol → String
  | .ext => "tamXCext"
  | .kdec => "tamXCkdec"
  | .kem => "tamXCkem"
  | .mac => "tamXCmac"
  | .pair => "tamXCpair"
  | .sdec => "tamXCsdec"
  | .senc => "tamXCsenc"

def nativeMaudeTerm : NativeQueryTerm → String
  | .atom .publicAtom index => s!"p({index})"
  | .atom .freshAtom index => s!"f({index})"
  | .atom .messageAtom index => s!"c({index})"
  | .naturalAtom index => s!"t({index})"
  | .nodeAtom index => s!"n({index})"
  | .queryVariable sort index => s!"x{index}:{nativeMaudeSort sort}"
  | .naturalOne => "tamXCtone"
  | .naturalAdd left right => s!"tamtplus({nativeMaudeTerm left},{nativeMaudeTerm right})"
  | .roleA => "tamXCroleA"
  | .roleB => "tamXCroleB"
  | .unary symbol argument => s!"{nativeMaudeUnary symbol}({nativeMaudeTerm argument})"
  | .binary symbol left right =>
    s!"{nativeMaudeBinary symbol}({nativeMaudeTerm left},{nativeMaudeTerm right})"
  | .kdf first second third =>
    s!"tamXCkdf({nativeMaudeTerm first},{nativeMaudeTerm second},{nativeMaudeTerm third})"
  | .list argument => s!"list({nativeMaudeTerm argument})"
  | .cons first rest => s!"cons({nativeMaudeTerm first},{nativeMaudeTerm rest})"
  | .nil => "nil"

-- One record per scheme: its value and the exact `nativeVariantSystem` handed to unification.
def nativeVariantExport (term : NativeQueryTerm) : String :=
  let variables := (nativeQueryVariables term).eraseDups.map fun entry =>
    nativeMaudeTerm (.queryVariable entry.1 entry.2)
  let schemes := (nativeVariantSchemes term (nativeFreshBase term)).map fun scheme =>
    s!"SCHEME {nativeMaudeTerm scheme.1}\n" ++ String.join
      ((nativeVariantSystem term scheme).map fun equation =>
        s!"EQUATION {nativeMaudeTerm equation.1} =? {nativeMaudeTerm equation.2}\n")
  s!"CASE {nativeMaudeTerm term}\nVARS {" ".intercalate variables}\n" ++ String.join schemes

private def message (index : Nat) : NativeQueryTerm := .queryVariable .message index
private def natural (index : Nat) : NativeQueryTerm := .queryVariable .natural index
private def publicKey (index : Nat) : NativeQueryTerm := .queryVariable .publicAtom index
private def node (index : Nat) : NativeQueryTerm := .queryVariable .node index
private def unary (symbol : UnarySymbol) (argument : NativeQueryTerm) : NativeQueryTerm :=
  .unary symbol argument
private def binary (symbol : BinarySymbol) (left right : NativeQueryTerm) : NativeQueryTerm :=
  .binary symbol left right

def nativeVariantCorpus : List NativeQueryTerm := [
  unary .fst (message 0),
  unary .snd (message 0),
  unary .flip (message 0),
  binary .sdec (message 0) (message 1),
  binary .kdec (message 0) (message 1),
  unary .snd (unary .fst (message 0)),
  binary .sdec (message 0) (unary .fst (message 1)),
  unary .fst (binary .sdec (message 0) (message 1)),
  unary .flip (unary .flip (message 0)),
  unary .hash (binary .sdec (message 0) (unary .hash (message 1))),
  binary .kdec (message 0) (message 0),
  binary .pair (unary .fst (message 0)) (unary .snd (message 0)),
  binary .sdec (binary .senc (message 0) (message 1)) (message 2),
  binary .kdec (binary .kem (message 0) (unary .pk (message 1))) (message 2),
  binary .sdec (message 0) (.naturalAdd (natural 1) .naturalOne),
  binary .sdec (binary .senc (message 0) (.naturalAdd (natural 1) (natural 2)))
    (.naturalAdd (natural 3) .naturalOne),
  binary .kdec (message 0) (publicKey 1),
  binary .sdec (message 0) (.atom .publicAtom 0),
  .kdf (unary .fst (message 0)) (unary .snd (message 1)) (binary .sdec (message 2) (message 3)),
  .list (.cons (unary .fst (message 0)) (.cons (node 1) .nil)),
  binary .ext (binary .sdec (message 0) (message 1)) (binary .sdec (message 0) (message 2))
]

#eval nativeVariantCorpus.forM fun term => IO.print (nativeVariantExport term)

end Cairn.Equations
