import QueryNaturalInterpretation
import QueryFiniteRendering

namespace Cairn.Equations

def nativeRenderNatural (rigid : Nat → Option NativeQueryTerm) :
    NativeQueryTerm → Option NativeQueryTerm
  | .naturalOne => some .naturalOne
  | .naturalAtom index => rigid index
  | .queryVariable .natural index => some (.queryVariable .message index)
  | .naturalAdd left right => do
    let first ← nativeRenderNatural rigid left
    let second ← nativeRenderNatural rigid right
    return .naturalAdd first second
  | .atom _ _ | .nodeAtom _ | .queryVariable .publicAtom _ |
      .queryVariable .freshAtom _ | .queryVariable .message _ | .queryVariable .node _ |
      .roleA | .roleB | .unary _ _ | .binary _ _ _ | .kdf _ _ _ |
      .list _ | .cons _ _ | .nil => none

theorem native_render_natural_interpretation
    {rigid : Nat → Option NativeQueryTerm} {total : Nat → NativeQueryTerm}
    (agrees : ∀ index value, rigid index = some value → total index = value)
    (rendered : nativeRenderNatural rigid word = some value) :
    nativeNaturalInterpret total (fun index => .queryVariable .message index) word = value := by
  induction word generalizing value with
  | naturalOne => exact Option.some.inj rendered
  | naturalAtom index => exact agrees index value rendered
  | queryVariable sort index =>
    cases sort <;> simp_all [nativeRenderNatural, nativeNaturalInterpret]
  | naturalAdd left right first second =>
    cases leftValue : nativeRenderNatural rigid left with
    | none => simp [nativeRenderNatural, leftValue] at rendered
    | some leftResult =>
      cases rightValue : nativeRenderNatural rigid right with
      | none => simp [nativeRenderNatural, leftValue, rightValue] at rendered
      | some rightResult =>
        have same : NativeQueryTerm.naturalAdd leftResult rightResult = value := by
          simpa [nativeRenderNatural, leftValue, rightValue] using rendered
        rw [nativeNaturalInterpret, first leftValue, second rightValue, same]
  | atom | nodeAtom | roleA | roleB | unary | binary | kdf | list | cons | nil =>
    simp [nativeRenderNatural] at rendered

theorem native_render_natural_preserve
    {rigid larger : Nat → Option NativeQueryTerm}
    (preserves : ∀ index value, rigid index = some value → larger index = some value)
    (rendered : nativeRenderNatural rigid word = some value) :
    nativeRenderNatural larger word = some value := by
  induction word generalizing value with
  | naturalOne => exact rendered
  | naturalAtom index => exact preserves index value rendered
  | queryVariable sort index =>
    cases sort <;> simp_all [nativeRenderNatural]
  | naturalAdd left right first second =>
    cases leftValue : nativeRenderNatural rigid left with
    | none => simp [nativeRenderNatural, leftValue] at rendered
    | some leftResult =>
      cases rightValue : nativeRenderNatural rigid right with
      | none => simp [nativeRenderNatural, leftValue, rightValue] at rendered
      | some rightResult =>
        simpa [nativeRenderNatural, first leftValue, second rightValue, leftValue, rightValue]
          using rendered
  | atom | nodeAtom | roleA | roleB | unary | binary | kdf | list | cons | nil =>
    simp [nativeRenderNatural] at rendered

theorem native_render_natural_exists
    {rigid : Nat → Option NativeQueryTerm}
    (proper : NativeSortedValue .natural word)
    (defined : ∀ index ∈ nativeNaturalRigidIndices word, ∃ value, rigid index = some value) :
    ∃ value, nativeRenderNatural rigid word = some value := by
  cases proper with
  | @natural _ term decoded =>
    rw [← native_natural_recognition _ decoded] at defined ⊢
    clear decoded
    induction term with
    | one => exact ⟨.naturalOne, rfl⟩
    | «variable» label =>
      by_cases even : label % 2 = 0
      · exact ⟨.queryVariable .message (label / 2), by
          simp [encodeNativeNatural, even, nativeRenderNatural]⟩
      · simpa [encodeNativeNatural, even, nativeNaturalRigidIndices, nativeRenderNatural] using
          defined (label / 2) (by simp [encodeNativeNatural, even, nativeNaturalRigidIndices])
    | add left right first second =>
      obtain ⟨leftValue, leftResult⟩ := first
        (fun index member => defined index (List.mem_append.mpr (.inl member)))
      obtain ⟨rightValue, rightResult⟩ := second
        (fun index member => defined index (List.mem_append.mpr (.inr member)))
      exact ⟨.naturalAdd leftValue rightValue, by
        simp [encodeNativeNatural, nativeRenderNatural, leftResult, rightResult]⟩

theorem native_render_natural_unique {first second : Nat → Option NativeQueryTerm}
    (unique : ∀ index left right, first index = some left → second index = some right → left = right)
    (leftRendered : nativeRenderNatural first word = some left)
    (rightRendered : nativeRenderNatural second word = some right) : left = right := by
  induction word generalizing left right with
  | naturalOne => exact (Option.some.inj leftRendered).symm.trans (Option.some.inj rightRendered)
  | naturalAtom index => exact unique index left right leftRendered rightRendered
  | queryVariable sort index =>
    cases sort <;> simp_all [nativeRenderNatural]
  | naturalAdd leftWord rightWord firstInduction secondInduction =>
    cases firstLeft : nativeRenderNatural first leftWord <;>
      cases firstRight : nativeRenderNatural first rightWord <;>
      cases secondLeft : nativeRenderNatural second leftWord <;>
      cases secondRight : nativeRenderNatural second rightWord <;>
      simp_all [nativeRenderNatural]
  | atom | nodeAtom | roleA | roleB | unary | binary | kdf | list | cons | nil =>
    simp [nativeRenderNatural] at leftRendered

#print axioms native_render_natural_interpretation
#print axioms native_render_natural_preserve
#print axioms native_render_natural_exists
#print axioms native_render_natural_unique

end Cairn.Equations
