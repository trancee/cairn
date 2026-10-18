import NaturalResiduals
import NaturalColumns
import QuerySystems

namespace Cairn.Equations

def naturalSystemAtomCode (indices : List Nat) (basis : List (List NaturalColumn)) :
    Sum Nat (List NaturalColumn) → Nat
  | .inl code => code
  | .inr generator => 2 * naturalResidualIndex indices basis generator + 1

def naturalSystemCandidateBindings (indices : List Nat) (basis : List (List NaturalColumn))
    (candidate : NaturalColumn → List (Sum Nat (List NaturalColumn))) :
    Option (List ((QuerySort × Nat) × NativeQueryTerm)) :=
  indices.mapM (fun index =>
    (naturalTermFromAtomCodes
      ((candidate (.queryVariable index)).map (naturalSystemAtomCode indices basis))).map
      (fun term => ((QuerySort.natural, index), encodeNativeNatural term)))

def nativeNaturalSystemBindingFamily (equations : NaturalEquationSystem) :
    List (List ((QuerySort × Nat) × NativeQueryTerm)) :=
  let columns := naturalSystemColumns equations
  let rows := naturalSystemRows equations
  let indices := naturalSystemVariableIndices columns
  let basis := (integerMatrixWordBasis columns rows).eraseDups
  (integerRigidWordFamily columns rows (naturalSystemRigidColumns columns)).filterMap
    (naturalSystemCandidateBindings indices basis)

def encodeNativeNaturalSystem (equations : NaturalEquationSystem) : NativeEquationSystem :=
  equations.map (fun equation => (encodeNativeNatural equation.1, encodeNativeNatural equation.2))

theorem natural_system_residual_code_fresh (indices : List Nat) (basis : List (List NaturalColumn))
    (generator : List NaturalColumn) (member : index ∈ indices) :
    naturalSystemAtomCode indices basis (.inr generator) ≠ 2 * index + 1 := by
  have fresh := natural_residual_index_fresh indices basis generator member
  simp only [naturalSystemAtomCode]
  omega

#print axioms natural_system_residual_code_fresh

end Cairn.Equations
