import QueryVariants
import QueryModule

namespace Cairn.Equations

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
