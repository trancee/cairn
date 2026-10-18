import QuerySortRefinement

namespace Cairn.Equations

example :
    nativeSortRequirements .natural (.queryVariable .message 0) =
      some [((.message, 0), .natural)] := by decide

example :
    nativeSortRequirements .message
      (.naturalAdd (.queryVariable .message 0) (.queryVariable .natural 1)) =
        some [((.message, 0), .natural), ((.natural, 1), .natural)] := by decide

example :
    nativeSortRequirements .natural (.queryVariable .freshAtom 0) = none := by decide

example :
    nativeSortRequirements .message (.queryVariable .node 0) = none := by decide

example (symbol : UnarySymbol) :
    nativeSortRequirements .message (.unary symbol (.queryVariable .freshAtom 0)) =
      some [((.freshAtom, 0), .freshAtom)] := by rfl

example :
    nativeSortRequirements .message (.list (.queryVariable .message 0)) = none := by decide

example :
    nativeSortRequirements .publicAtom .roleA = none := by decide

example (assignment : QuerySort → Nat → NativeQueryTerm)
    (sorted : NativeSortedAssignment assignment) (sort : QuerySort) (term : NativeQueryTerm) :
    NativeSortedValue sort (substituteNativeQuery assignment term) ↔
      NativeSortRequirementsHold (nativeSortRequirements sort term) assignment :=
  native_sort_requirements_iff assignment sorted sort term

end Cairn.Equations
