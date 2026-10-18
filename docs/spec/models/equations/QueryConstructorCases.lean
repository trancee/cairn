import QueryConstructorSystems
import QuerySystemBindings

namespace Cairn.Equations

example (left right first second : NativeQueryTerm)
    (equations : NativeEquationSystem) (variables : List (QuerySort × Nat))
    (family : List (QuerySort → Nat → NativeQueryTerm)) :
    NativeCompleteACSystemOn
      ((.binary .pair left right, .binary .pair first second) :: equations) variables family ↔
    NativeCompleteACSystemOn ((left, first) :: (right, second) :: equations) variables family :=
  native_system_binary_decomposition

example : WellFounded (fun right left : NativeEquationSystem =>
    NativeConstructorDecomposition left right) :=
  native_constructor_decomposition_termination

example (symbol : UnarySymbol) (left right : NativeQueryTerm)
    (equations : NativeEquationSystem) (variables : List (QuerySort × Nat))
    (family : List (QuerySort → Nat → NativeQueryTerm)) :
    NativeCompleteACSystemOn ((.unary symbol left, .unary symbol right) :: equations)
      variables family ↔ NativeCompleteACSystemOn ((left, right) :: equations) variables family :=
  native_system_unary_decomposition

example (first second third left middle right : NativeQueryTerm)
    (equations : NativeEquationSystem) (variables : List (QuerySort × Nat))
    (family : List (QuerySort → Nat → NativeQueryTerm)) :
    NativeCompleteACSystemOn ((.kdf first second third, .kdf left middle right) :: equations)
      variables family ↔
    NativeCompleteACSystemOn ((first, left) :: (second, middle) :: (third, right) :: equations)
      variables family := native_system_kdf_decomposition

example (left right : NativeQueryTerm) (equations : NativeEquationSystem)
    (variables : List (QuerySort × Nat)) (family : List (QuerySort → Nat → NativeQueryTerm)) :
    NativeCompleteACSystemOn ((.list left, .list right) :: equations) variables family ↔
      NativeCompleteACSystemOn ((left, right) :: equations) variables family :=
  native_system_list_decomposition

example (first second left right : NativeQueryTerm) (equations : NativeEquationSystem)
    (variables : List (QuerySort × Nat)) (family : List (QuerySort → Nat → NativeQueryTerm)) :
    NativeCompleteACSystemOn ((.cons first second, .cons left right) :: equations) variables family ↔
      NativeCompleteACSystemOn ((first, left) :: (second, right) :: equations) variables family :=
  native_system_cons_decomposition

example (left right : NativeQueryTerm) :
    NativeQueryAC (.unary .hash (.naturalAdd left right))
      (.unary .hash (.naturalAdd right left)) :=
  native_ac_unary_iff.mpr .commutative

example (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn
      ((.binary .pair .roleA .roleB, .binary .pair .roleB .roleA) :: equations) variables [] := by
  apply native_system_binary_decomposition.mpr
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn
      ((.unary .hash .roleA, .unary .pk .roleA) :: equations) variables [] := by
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn
      ((.atom .publicAtom 0, .atom .freshAtom 0) :: equations) variables [] := by
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn ((.naturalAtom 0, .naturalAtom 1) :: equations) variables [] := by
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn ((.nodeAtom 0, .nodeAtom 1) :: equations) variables [] := by
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn ((.nil, .list .nil) :: equations) variables [] := by
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn [(.queryVariable .message 0, .roleA)] variables
      [nativeBindingAssignment [((.message, 0), .roleA)]] :=
  native_system_single_binding_complete (.message rfl) (by decide) variables

example : ¬ NativeFixedHead (.queryVariable .message 0) := by
  intro impossible
  exact impossible

example : ¬ NativeQueryAC (.naturalAdd .naturalOne .naturalOne)
    (.naturalAdd .naturalOne (.naturalAdd .naturalOne .naturalOne)) := by
  intro equivalent
  have count := native_query_ac_preserves_count equivalent
  simp [nativeQueryFunctionCount] at count

example : NativeQueryAC (.naturalAdd .naturalOne (.naturalAtom 0))
    (.naturalAdd (.naturalAtom 0) .naturalOne) := .commutative

-- AC-only clashes do not assert unsatisfiability modulo the six rewrite equations.
example (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn [(.unary .flip .roleA, .roleB)] variables [] := by
  apply native_system_constructor_clash <;> first | trivial | (intro impossible; cases impossible)

example : NativePrimitiveRewrite (.unary .flip .roleA) .roleB := .flipA

example (equations : NativeEquationSystem) :
    nativeSystemFunctionCount
      ((.binary .pair .roleA .roleB, .binary .pair .roleB .roleA) :: equations) =
    nativeSystemFunctionCount ((.roleA, .roleB) :: (.roleB, .roleA) :: equations) + 2 := by
  simp [nativeSystemFunctionCount, nativeQueryFunctionCount]
  omega

end Cairn.Equations
