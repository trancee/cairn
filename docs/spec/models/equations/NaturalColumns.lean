import NaturalLinearization
import IntegerWordLinear

namespace Cairn.Equations

inductive NaturalColumn where
  | queryVariable (index : Nat)
  | rigidAtom (code : Nat)
  deriving DecidableEq

abbrev NaturalEquationSystem : Type := List (NaturalTerm × NaturalTerm)

def naturalTemplateColumns : NaturalTerm → List NaturalColumn
  | .one => [.rigidAtom 0]
  | .variable label =>
    if label % 2 = 0 then [.queryVariable (label / 2)] else [.rigidAtom (label + 1)]
  | .add left right => naturalTemplateColumns left ++ naturalTemplateColumns right

def naturalSystemColumns (equations : NaturalEquationSystem) : List NaturalColumn :=
  (equations.flatMap (fun equation =>
    naturalTemplateColumns equation.1 ++ naturalTemplateColumns equation.2)).eraseDups

def naturalSystemRows (equations : NaturalEquationSystem) : List (NaturalColumn → Int) :=
  equations.map (fun equation column =>
    ((naturalTemplateColumns equation.1).count column : Int) -
      ((naturalTemplateColumns equation.2).count column : Int))

def naturalSystemVariableIndices (columns : List NaturalColumn) : List Nat :=
  columns.filterMap (fun column =>
    match column with
    | .queryVariable index => some index
    | .rigidAtom _ => none)

def naturalSystemRigidColumns (columns : List NaturalColumn) : List (NaturalColumn × Nat) :=
  columns.filterMap (fun column =>
    match column with
    | .queryVariable _ => none
    | .rigidAtom code => some (column, code))

def naturalColumnValues (assignment : QuerySubstitution) : NaturalColumn → List Nat
  | .queryVariable index => naturalAtomCodes (assignment.naturals index)
  | .rigidAtom code => [code]

theorem natural_column_values_nonempty (assignment : QuerySubstitution) (column : NaturalColumn) :
    naturalColumnValues assignment column ≠ [] := by
  cases column with
  | queryVariable => exact natural_atom_codes_nonempty _
  | rigidAtom => simp [naturalColumnValues]

theorem natural_template_column_substitution (assignment : QuerySubstitution) (term : NaturalTerm) :
    naturalAtomCodes (substituteQueryNatural assignment term) =
      (naturalTemplateColumns term).flatMap (naturalColumnValues assignment) := by
  induction term with
  | one => rfl
  | «variable» label =>
    by_cases even : label % 2 = 0 <;>
      simp [substituteQueryNatural, naturalAtomCodes, naturalTemplateColumns,
        naturalColumnValues, even]
  | add left right first second =>
    simp [substituteQueryNatural, naturalAtomCodes, naturalTemplateColumns,
      List.flatMap_append, first, second]

theorem natural_system_columns_scope (equations : NaturalEquationSystem) (equation)
    (member : equation ∈ equations) (column)
    (occurs : column ∈ naturalTemplateColumns equation.1 ++ naturalTemplateColumns equation.2) :
    column ∈ naturalSystemColumns equations := by
  simp only [naturalSystemColumns, List.mem_eraseDups]
  exact List.mem_flatMap.mpr ⟨equation, member, occurs⟩

theorem natural_system_columns_unique (equations : NaturalEquationSystem) :
    (naturalSystemColumns equations).Nodup :=
  integer_word_erase_duplicates_unique _

theorem natural_system_rigid_scope (columns : List NaturalColumn)
    (member : binding ∈ naturalSystemRigidColumns columns) : binding.1 ∈ columns := by
  obtain ⟨column, occurs, selected⟩ := List.mem_filterMap.mp member
  cases column with
  | queryVariable => simp at selected
  | rigidAtom code =>
    simp only [Option.some.injEq] at selected
    subst binding
    exact occurs

theorem natural_system_rigid_values (assignment : QuerySubstitution) (columns : List NaturalColumn)
    (member : binding ∈ naturalSystemRigidColumns columns) :
    naturalColumnValues assignment binding.1 = [binding.2] := by
  obtain ⟨column, _, selected⟩ := List.mem_filterMap.mp member
  cases column with
  | queryVariable => simp at selected
  | rigidAtom code =>
    simp only [Option.some.injEq] at selected
    subst binding
    rfl

private theorem equation_counts (equations : NaturalEquationSystem) (assignment : QuerySubstitution)
    (equation) (member : equation ∈ equations) (atom : Nat) :
    integerWordSum
      (fun column => ((naturalTemplateColumns equation.1).count column : Int) -
        ((naturalTemplateColumns equation.2).count column : Int))
      (integerWordTranspose (naturalSystemColumns equations) (naturalColumnValues assignment) atom) =
        (naturalMultiplicity atom (substituteQueryNatural assignment equation.1) : Int) -
          (naturalMultiplicity atom (substituteQueryNatural assignment equation.2) : Int) := by
  rw [integer_word_equation_counts _ _ _ _ (natural_system_columns_unique equations)
    (fun column occurs => natural_system_columns_scope equations equation member column
      (List.mem_append.mpr (.inl occurs)))
    (fun column occurs => natural_system_columns_scope equations equation member column
      (List.mem_append.mpr (.inr occurs)))]
  rw [← natural_template_column_substitution, ← natural_template_column_substitution]
  rfl

theorem natural_system_rows_iff (equations : NaturalEquationSystem) (assignment : QuerySubstitution) :
    (∀ row ∈ naturalSystemRows equations, ∀ atom,
      integerWordSum row
        (integerWordTranspose (naturalSystemColumns equations)
          (naturalColumnValues assignment) atom) = 0) ↔
      ∀ equation ∈ equations,
        NaturalAC (substituteQueryNatural assignment equation.1)
          (substituteQueryNatural assignment equation.2) := by
  constructor
  · intro balanced equation member
    apply natural_ac_multiplicity_iff.mpr
    intro atom
    have zero := balanced _ (List.mem_map.mpr ⟨equation, member, rfl⟩) atom
    rw [equation_counts equations assignment equation member atom] at zero
    omega
  · intro solved row member atom
    obtain ⟨equation, occurs, rfl⟩ := List.mem_map.mp member
    rw [equation_counts equations assignment equation occurs atom]
    have equal := natural_ac_multiplicity_iff.mp (solved equation occurs) atom
    omega

#print axioms natural_column_values_nonempty
#print axioms natural_template_column_substitution
#print axioms natural_system_columns_scope
#print axioms natural_system_columns_unique
#print axioms natural_system_rigid_scope
#print axioms natural_system_rigid_values
#print axioms natural_system_rows_iff

end Cairn.Equations
