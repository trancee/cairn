import QueryRawPlans
import QuerySortedGeneration

namespace Cairn.Equations

def nativeRawRenderBindings (equations : NativeEquationSystem) (label : NativeQueryTerm → Nat)
    (bindings : NativeBindingList) : Option NativeBindingList := do
  let source := nativeSystemSubterms equations
  let assignment := nativeBindingAssignment bindings
  let markers := nativeRawMarkers source label
  let render := nativeRawRenderMarker source label assignment markers
  let _ ← markers.mapM render
  let _ ← (List.range source.length).mapM (fun index =>
    nativeRenderNatural render (assignment .natural index))
  (nativeSystemVariables equations).mapM (fun key => do
    let value ← nativeRenderNatural render (assignment .natural (label (.queryVariable key.1 key.2)))
    return (key, value))

def nativeRawACSystemBindingFamily (equations : NativeEquationSystem) : List NativeBindingList :=
  let source := nativeSystemSubterms equations
  (nativeRawLabelWords source.length).flatMap (fun labels =>
    let label := nativeRawLabel source labels
    if NativeRawPlanConsistent equations label then
      (nativeNaturalSystemBindingFamily (nativeRawNaturalSystem equations label)).filterMap
        (nativeRawRenderBindings equations label)
    else [])

def nativeSortedACSystemBindingFamily (equations : NativeEquationSystem) : List NativeBindingList :=
  nativeSortedBindingFamily (nativeSystemVariables equations) (nativeRawACSystemBindingFamily equations)

end Cairn.Equations
