import QueryConstructors
import QuerySystems

namespace Cairn.Equations

private theorem complete_iff_solutions
    (solutions : ∀ assignment,
      NativeACSystemUnifier first assignment ↔ NativeACSystemUnifier second assignment) :
    NativeCompleteACSystemOn first variables family ↔
      NativeCompleteACSystemOn second variables family := by
  unfold NativeCompleteACSystemOn
  simp only [solutions]

theorem native_system_unary_decomposition :
    NativeCompleteACSystemOn ((.unary symbol left, .unary symbol right) :: equations)
      variables family ↔ NativeCompleteACSystemOn ((left, right) :: equations) variables family := by
  apply complete_iff_solutions
  intro assignment
  simp only [native_system_cons_iff, NativeACUnifier, substituteNativeQuery, native_ac_unary_iff]

theorem native_system_binary_decomposition :
    NativeCompleteACSystemOn
      ((.binary symbol firstLeft secondLeft, .binary symbol firstRight secondRight) :: equations)
      variables family ↔
    NativeCompleteACSystemOn ((firstLeft, firstRight) :: (secondLeft, secondRight) :: equations)
      variables family := by
  apply complete_iff_solutions
  intro assignment
  simp only [native_system_cons_iff, NativeACUnifier, substituteNativeQuery, native_ac_binary_iff]
  constructor
  · rintro ⟨⟨sorted, first, second⟩, rest⟩
    exact ⟨⟨sorted, first⟩, ⟨sorted, second⟩, rest⟩
  · rintro ⟨⟨sorted, first⟩, ⟨_, second⟩, rest⟩
    exact ⟨⟨sorted, first, second⟩, rest⟩

theorem native_system_kdf_decomposition :
    NativeCompleteACSystemOn
      ((.kdf firstLeft secondLeft thirdLeft, .kdf firstRight secondRight thirdRight) :: equations)
      variables family ↔
    NativeCompleteACSystemOn
      ((firstLeft, firstRight) :: (secondLeft, secondRight) :: (thirdLeft, thirdRight) :: equations)
      variables family := by
  apply complete_iff_solutions
  intro assignment
  simp only [native_system_cons_iff, NativeACUnifier, substituteNativeQuery, native_ac_kdf_iff]
  constructor
  · rintro ⟨⟨sorted, first, second, third⟩, rest⟩
    exact ⟨⟨sorted, first⟩, ⟨sorted, second⟩, ⟨sorted, third⟩, rest⟩
  · rintro ⟨⟨sorted, first⟩, ⟨_, second⟩, ⟨_, third⟩, rest⟩
    exact ⟨⟨sorted, first, second, third⟩, rest⟩

theorem native_system_list_decomposition :
    NativeCompleteACSystemOn ((.list left, .list right) :: equations) variables family ↔
      NativeCompleteACSystemOn ((left, right) :: equations) variables family := by
  apply complete_iff_solutions
  intro assignment
  simp only [native_system_cons_iff, NativeACUnifier, substituteNativeQuery, native_ac_list_iff]

theorem native_system_cons_decomposition :
    NativeCompleteACSystemOn ((.cons firstLeft secondLeft, .cons firstRight secondRight) :: equations)
      variables family ↔
    NativeCompleteACSystemOn ((firstLeft, firstRight) :: (secondLeft, secondRight) :: equations)
      variables family := by
  apply complete_iff_solutions
  intro assignment
  simp only [native_system_cons_iff, NativeACUnifier, substituteNativeQuery, native_ac_cons_iff]
  constructor
  · rintro ⟨⟨sorted, first, second⟩, rest⟩
    exact ⟨⟨sorted, first⟩, ⟨sorted, second⟩, rest⟩
  · rintro ⟨⟨sorted, first⟩, ⟨_, second⟩, rest⟩
    exact ⟨⟨sorted, first, second⟩, rest⟩

def NativeFixedHead : NativeQueryTerm → Prop
  | .queryVariable _ _ => False
  | .atom _ _ | .naturalAtom _ | .nodeAtom _ | .naturalOne | .naturalAdd _ _
  | .roleA | .roleB | .unary _ _ | .binary _ _ _ | .kdf _ _ _ | .list _ | .cons _ _ | .nil => True

theorem native_substitution_fixed_head (fixed : NativeFixedHead term) :
    nativeQueryHead (substituteNativeQuery assignment term) = nativeQueryHead term := by
  cases term <;> simp_all [NativeFixedHead, nativeQueryHead, substituteNativeQuery]

theorem native_system_constructor_clash
    (leftFixed : NativeFixedHead left) (rightFixed : NativeFixedHead right)
    (different : nativeQueryHead left ≠ nativeQueryHead right)
    (equations : NativeEquationSystem) (variables : List (QuerySort × Nat)) :
    NativeCompleteACSystemOn ((left, right) :: equations) variables [] := by
  refine ⟨by simp, ?_⟩
  intro solution solved
  have heads := native_query_ac_head (native_system_cons_iff.mp solved).1.2
  rw [native_substitution_fixed_head leftFixed, native_substitution_fixed_head rightFixed] at heads
  exact (different heads).elim

inductive NativeConstructorDecomposition : NativeEquationSystem → NativeEquationSystem → Prop where
  | unary : NativeConstructorDecomposition
      ((.unary symbol left, .unary symbol right) :: equations) ((left, right) :: equations)
  | binary : NativeConstructorDecomposition
      ((.binary symbol firstLeft secondLeft, .binary symbol firstRight secondRight) :: equations)
      ((firstLeft, firstRight) :: (secondLeft, secondRight) :: equations)
  | kdf : NativeConstructorDecomposition
      ((.kdf firstLeft secondLeft thirdLeft, .kdf firstRight secondRight thirdRight) :: equations)
      ((firstLeft, firstRight) :: (secondLeft, secondRight) :: (thirdLeft, thirdRight) :: equations)
  | list : NativeConstructorDecomposition
      ((.list left, .list right) :: equations) ((left, right) :: equations)
  | cons : NativeConstructorDecomposition
      ((.cons firstLeft secondLeft, .cons firstRight secondRight) :: equations)
      ((firstLeft, firstRight) :: (secondLeft, secondRight) :: equations)

def nativeSystemFunctionCount : NativeEquationSystem → Nat
  | [] => 0
  | (left, right) :: equations =>
    nativeQueryFunctionCount left + nativeQueryFunctionCount right + nativeSystemFunctionCount equations

theorem native_constructor_decomposition_complete
    (step : NativeConstructorDecomposition original reduced) :
    NativeCompleteACSystemOn original variables family ↔
      NativeCompleteACSystemOn reduced variables family := by
  cases step with
  | unary => exact native_system_unary_decomposition
  | binary => exact native_system_binary_decomposition
  | kdf => exact native_system_kdf_decomposition
  | list => exact native_system_list_decomposition
  | cons => exact native_system_cons_decomposition

theorem native_constructor_decomposition_decreases
    (step : NativeConstructorDecomposition original reduced) :
    nativeSystemFunctionCount reduced < nativeSystemFunctionCount original := by
  cases step <;> simp only [nativeSystemFunctionCount, nativeQueryFunctionCount] <;> omega

theorem native_constructor_decomposition_termination :
    WellFounded (fun right left : NativeEquationSystem => NativeConstructorDecomposition left right) := by
  apply Subrelation.wf (r := (measure nativeSystemFunctionCount).rel) _
    (measure nativeSystemFunctionCount).wf
  intro right left step
  exact native_constructor_decomposition_decreases step

#print axioms native_system_unary_decomposition
#print axioms native_system_binary_decomposition
#print axioms native_system_kdf_decomposition
#print axioms native_system_list_decomposition
#print axioms native_system_cons_decomposition
#print axioms native_substitution_fixed_head
#print axioms native_system_constructor_clash
#print axioms native_constructor_decomposition_complete
#print axioms native_constructor_decomposition_decreases
#print axioms native_constructor_decomposition_termination

end Cairn.Equations
