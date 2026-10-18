import QueryACWords
import NaturalSystemCompleteness

namespace Cairn.Equations

def nativeNaturalInterpret (rigid variables : Nat → NativeQueryTerm) :
    NativeQueryTerm → NativeQueryTerm
  | .naturalAtom index => rigid index
  | .queryVariable .natural index => variables index
  | .naturalAdd left right =>
    .naturalAdd (nativeNaturalInterpret rigid variables left) (nativeNaturalInterpret rigid variables right)
  | .unary symbol argument => .unary symbol (nativeNaturalInterpret rigid variables argument)
  | .binary symbol left right =>
    .binary symbol (nativeNaturalInterpret rigid variables left) (nativeNaturalInterpret rigid variables right)
  | .kdf first second third =>
    .kdf (nativeNaturalInterpret rigid variables first) (nativeNaturalInterpret rigid variables second)
      (nativeNaturalInterpret rigid variables third)
  | .list argument => .list (nativeNaturalInterpret rigid variables argument)
  | .cons first second =>
    .cons (nativeNaturalInterpret rigid variables first) (nativeNaturalInterpret rigid variables second)
  | term@(.atom _ _) | term@(.nodeAtom _) | term@(.queryVariable .publicAtom _) |
      term@(.queryVariable .freshAtom _) | term@(.queryVariable .message _) |
      term@(.queryVariable .node _) | term@(.naturalOne) |
      term@(.roleA) | term@(.roleB) | term@(.nil) => term

theorem native_natural_interpret_ac (rigid variables : Nat → NativeQueryTerm)
    (equivalent : NativeQueryAC left right) :
    NativeQueryAC (nativeNaturalInterpret rigid variables left)
      (nativeNaturalInterpret rigid variables right) := by
  induction equivalent with
  | reflexive => exact .reflexive
  | symmetric _ induction => exact .symmetric induction
  | transitive _ _ first second => exact .transitive first second
  | associative => exact .associative
  | commutative => exact .commutative
  | naturalAdd _ _ first second => exact .naturalAdd first second
  | unary _ induction => exact .unary induction
  | binary _ _ first second => exact .binary first second
  | kdf _ _ _ first second third => exact .kdf first second third
  | list _ induction => exact .list induction
  | cons _ _ first second => exact .cons first second

theorem native_natural_interpret_substitution
    (rigid variables : Nat → NativeQueryTerm) (assignment : QuerySort → Nat → NativeQueryTerm)
    (proper : NativeSortedValue .natural word) :
    nativeNaturalInterpret rigid variables (substituteNativeQuery assignment word) =
      nativeNaturalInterpret rigid
        (fun index => nativeNaturalInterpret rigid variables (assignment .natural index)) word := by
  cases proper with
  | @natural _ term decoded =>
    rw [← native_natural_recognition _ decoded]
    clear decoded
    induction term with
    | one => rfl
    | «variable» label =>
      by_cases even : label % 2 = 0 <;>
        simp [encodeNativeNatural, even, substituteNativeQuery, nativeNaturalInterpret]
    | add _ _ first second =>
      simp only [encodeNativeNatural, substituteNativeQuery, nativeNaturalInterpret, first, second]

def nativeNaturalRigidIndices : NativeQueryTerm → List Nat
  | .naturalAtom index => [index]
  | .naturalAdd left right => nativeNaturalRigidIndices left ++ nativeNaturalRigidIndices right
  | .atom _ _ | .nodeAtom _ | .queryVariable _ _ | .naturalOne | .roleA | .roleB |
      .unary _ _ | .binary _ _ _ | .kdf _ _ _ | .list _ | .cons _ _ | .nil => []

theorem native_natural_rigid_codes (term : NaturalTerm) (index : Nat) :
    index ∈ nativeNaturalRigidIndices (encodeNativeNatural term) ↔
      2 * index + 2 ∈ naturalAtomCodes term := by
  induction term with
  | one => simp [encodeNativeNatural, nativeNaturalRigidIndices, naturalAtomCodes]
  | «variable» label =>
    by_cases even : label % 2 = 0
    · simp [encodeNativeNatural, even, nativeNaturalRigidIndices, naturalAtomCodes] <;> omega
    · simp [encodeNativeNatural, even, nativeNaturalRigidIndices, naturalAtomCodes] <;> omega
  | add _ _ first second =>
    simp only [encodeNativeNatural, nativeNaturalRigidIndices, naturalAtomCodes,
      List.mem_append, first, second]

theorem native_natural_rigid_weight (rigid variables : Nat → NativeQueryTerm)
    (member : index ∈ nativeNaturalRigidIndices word) :
    nativeQueryFunctionCount (rigid index) ≤
      nativeQueryFunctionCount (nativeNaturalInterpret rigid variables word) := by
  induction word with
  | naturalAtom position =>
    have same := List.mem_singleton.mp member
    subst position
    exact Nat.le_refl _
  | naturalAdd _ _ first second =>
    rcases List.mem_append.mp member with left | right
    · have bound := first left
      simp only [nativeNaturalInterpret, nativeQueryFunctionCount]
      omega
    · have bound := second right
      simp only [nativeNaturalInterpret, nativeQueryFunctionCount]
      omega
  | atom | nodeAtom | queryVariable | naturalOne | roleA | roleB |
      unary | binary | kdf | list | cons | nil => simp [nativeNaturalRigidIndices] at member

#print axioms native_natural_interpret_ac
#print axioms native_natural_interpret_substitution
#print axioms native_natural_rigid_codes
#print axioms native_natural_rigid_weight

end Cairn.Equations
