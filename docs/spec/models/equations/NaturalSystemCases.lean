import NaturalSystemCompleteness

namespace Cairn.Equations

example :
    (nativeNaturalSystemBindingFamily
      [(NaturalTerm.add (.variable 0) (.variable 0),
        NaturalTerm.add (.variable 2) (.add (.variable 2) (.variable 2)))]).length = 1 := by decide

example :
    ((nativeNaturalSystemBindingFamily
      [(.variable 0, .one)]).map (fun bindings =>
        match nativeBindingAssignment bindings .natural 0 with
        | .naturalOne => true
        | _ => false)) = [true] := by decide

example :
    ((nativeNaturalSystemBindingFamily
      [(.variable 0, .variable 1)]).map (fun bindings =>
        match nativeBindingAssignment bindings .natural 0 with
        | .naturalAtom 0 => true
        | _ => false)) = [true] := by decide

example :
    (nativeNaturalSystemBindingFamily [(.add (.variable 0) (.variable 0), .one)]).length = 0 :=
  by decide

example :
    (nativeNaturalSystemBindingFamily [(.add (.variable 0) .one, .one)]).length = 0 := by decide

example :
    (nativeNaturalSystemBindingFamily [(.add (.variable 0) .one, .variable 2)]).length = 2 := by decide

example :
    (nativeNaturalSystemBindingFamily
      [(.add (.variable 0) (.variable 2), .add (.variable 4) (.variable 6))]).length = 7 := by decide

example :
    (nativeNaturalSystemBindingFamily [(.one, .variable 1)]).length = 0 := by decide

example :
    ((nativeNaturalSystemBindingFamily []).map List.length) = [0] := by decide

example :
    ((nativeNaturalSystemBindingFamily
      [(.add (.variable 0) (.variable 0), .add (.variable 2) (.add (.variable 2) (.variable 2)))]).all
      (fun bindings =>
        (nativeQueryVariables (nativeBindingAssignment bindings .natural 0)).length == 3 &&
        (nativeQueryVariables (nativeBindingAssignment bindings .natural 1)).length == 2 &&
        (nativeQueryVariables (nativeBindingAssignment bindings .natural 0) ++
          nativeQueryVariables (nativeBindingAssignment bindings .natural 1)).all
            (fun key => decide (key.1 = .natural ∧ 2 ≤ key.2)))) = true := by decide

example (equations : NaturalEquationSystem) :
    NativeCompleteACSystemOn (encodeNativeNaturalSystem equations)
      (nativeSystemVariables (encodeNativeNaturalSystem equations))
      ((nativeNaturalSystemBindingFamily equations).map nativeBindingAssignment) :=
  native_natural_system_family_complete equations

end Cairn.Equations
