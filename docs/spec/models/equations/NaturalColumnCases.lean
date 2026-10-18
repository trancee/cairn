import NaturalColumns

namespace Cairn.Equations

example (equations : NaturalEquationSystem) (assignment : QuerySubstitution) :
    (∀ row ∈ naturalSystemRows equations, ∀ atom,
      integerWordSum row
        (integerWordTranspose (naturalSystemColumns equations)
          (naturalColumnValues assignment) atom) = 0) ↔
      ∀ equation ∈ equations,
        NaturalAC (substituteQueryNatural assignment equation.1)
          (substituteQueryNatural assignment equation.2) :=
  natural_system_rows_iff equations assignment

end Cairn.Equations
