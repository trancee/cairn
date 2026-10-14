import QueryImage

open Cairn.Equations

example : encodeNativeMessage (.atom .publicAtom 14) = .queryVariable .publicAtom 7 := rfl

example : encodeNativeMessage (.atom .publicAtom 15) = .atom .publicAtom 7 := rfl

example : encodeNativeNatural (.variable 14) = .queryVariable .natural 7 := rfl

example : encodeNativeNatural (.variable 15) = .naturalAtom 7 := rfl

example : decodeNativeMessage (.queryVariable .node 7) = none := rfl

example : decodeNativeMessage (.unary .hash (.list .nil)) = none := rfl

example : decodeNativeNatural
    (.naturalAdd (.naturalOne) (.queryVariable .message 7)) = none := rfl

example : encodeNativeNatural (.variable 1) = .naturalAtom 0 := rfl
