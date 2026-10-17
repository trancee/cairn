import QueryTypedInstances

namespace Cairn.Equations

-- These predicates specify coverage of all sorted solutions, not a generator.
def NativeCompleteACUnifiers (left right : NativeQueryTerm)
    (family : List (QuerySort → Nat → NativeQueryTerm)) : Prop :=
  (∀ candidate ∈ family, NativeACUnifier left right candidate) ∧
    ∀ solution, NativeACUnifier left right solution →
      ∃ candidate ∈ family,
        NativeACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
          candidate solution

def QueryCompleteACUnifiers (solves : QuerySubstitution → Prop)
    (variables : List (QuerySort × Nat)) (family : List QuerySubstitution) : Prop :=
  (∀ candidate ∈ family, solves candidate) ∧
    ∀ solution, solves solution →
      ∃ candidate ∈ family, QueryACInstanceOn variables candidate solution

def NativeMostGeneralACUnifier (left right : NativeQueryTerm)
    (candidate : QuerySort → Nat → NativeQueryTerm) : Prop :=
  NativeACUnifier left right candidate ∧
    ∀ solution, NativeACUnifier left right solution →
      NativeACInstanceOn (nativeQueryVariables left ++ nativeQueryVariables right)
        candidate solution

def QueryMostGeneralACUnifier (solves : QuerySubstitution → Prop)
    (variables : List (QuerySort × Nat)) (candidate : QuerySubstitution) : Prop :=
  solves candidate ∧
    ∀ solution, solves solution → QueryACInstanceOn variables candidate solution

theorem native_singleton_complete_iff :
    NativeCompleteACUnifiers left right [candidate] ↔
      NativeMostGeneralACUnifier left right candidate := by
  simp [NativeCompleteACUnifiers, NativeMostGeneralACUnifier]

theorem query_singleton_complete_iff :
    QueryCompleteACUnifiers solves variables [candidate] ↔
      QueryMostGeneralACUnifier solves variables candidate := by
  simp [QueryCompleteACUnifiers, QueryMostGeneralACUnifier]

private theorem complete_unifiers_transport (left right : NativeQueryTerm)
    (solves : QuerySubstitution → Prop)
    (solutionIff : ∀ typed, NativeACUnifier left right (nativeQueryAssignment typed) ↔ solves typed)
    (family : List QuerySubstitution) :
    QueryCompleteACUnifiers solves
      (nativeQueryVariables left ++ nativeQueryVariables right) family ↔
        NativeCompleteACUnifiers left right (family.map nativeQueryAssignment) := by
  constructor
  · intro complete
    constructor
    · intro candidate nativeMember
      obtain ⟨typed, typedMember, rfl⟩ := List.mem_map.mp nativeMember
      exact (solutionIff typed).mpr (complete.1 typed typedMember)
    · intro solution solved
      obtain ⟨typed, compatible⟩ := native_sorted_assignment_representation solved.1
      have typedSolution : solves typed := (solutionIff typed).mp (by
        rw [compatible]; exact solved)
      obtain ⟨candidate, member, factorization⟩ := complete.2 typed typedSolution
      refine ⟨nativeQueryAssignment candidate, List.mem_map.mpr ⟨candidate, member, rfl⟩, ?_⟩
      rw [← compatible]
      exact (native_query_ac_instance_iff _ _ _).mpr factorization
  · intro complete
    constructor
    · intro candidate member
      exact (solutionIff candidate).mp
        (complete.1 _ (List.mem_map.mpr ⟨candidate, member, rfl⟩))
    · intro solution solved
      obtain ⟨candidate, nativeMember, factorization⟩ :=
        complete.2 (nativeQueryAssignment solution) ((solutionIff solution).mpr solved)
      obtain ⟨typed, typedMember, rfl⟩ := List.mem_map.mp nativeMember
      exact ⟨typed, typedMember, (native_query_ac_instance_iff _ _ _).mp factorization⟩

theorem native_message_complete_unifiers_iff (left right : MessageTerm)
    (family : List QuerySubstitution) :
    NativeCompleteACUnifiers (encodeNativeMessage left) (encodeNativeMessage right)
      (family.map nativeQueryAssignment) ↔
        QueryCompleteACUnifiers
          (fun assignment => MessageAC (substituteQueryMessage assignment left)
            (substituteQueryMessage assignment right))
          (nativeQueryVariables (encodeNativeMessage left) ++
            nativeQueryVariables (encodeNativeMessage right)) family :=
  (complete_unifiers_transport _ _ _ (fun typed => native_message_ac_unifier_iff typed left right)
    family).symm

theorem native_natural_complete_unifiers_iff (left right : NaturalTerm)
    (family : List QuerySubstitution) :
    NativeCompleteACUnifiers (encodeNativeNatural left) (encodeNativeNatural right)
      (family.map nativeQueryAssignment) ↔
        QueryCompleteACUnifiers
          (fun assignment => NaturalAC (substituteQueryNatural assignment left)
            (substituteQueryNatural assignment right))
          (nativeQueryVariables (encodeNativeNatural left) ++
            nativeQueryVariables (encodeNativeNatural right)) family :=
  (complete_unifiers_transport _ _ _ (fun typed => native_natural_ac_unifier_iff typed left right)
    family).symm

theorem native_message_most_general_iff (left right : MessageTerm) (candidate : QuerySubstitution) :
    NativeMostGeneralACUnifier (encodeNativeMessage left) (encodeNativeMessage right)
      (nativeQueryAssignment candidate) ↔
        QueryMostGeneralACUnifier
          (fun assignment => MessageAC (substituteQueryMessage assignment left)
            (substituteQueryMessage assignment right))
          (nativeQueryVariables (encodeNativeMessage left) ++
            nativeQueryVariables (encodeNativeMessage right)) candidate := by
  rw [← native_singleton_complete_iff, ← query_singleton_complete_iff]
  exact native_message_complete_unifiers_iff left right [candidate]

theorem native_natural_most_general_iff (left right : NaturalTerm) (candidate : QuerySubstitution) :
    NativeMostGeneralACUnifier (encodeNativeNatural left) (encodeNativeNatural right)
      (nativeQueryAssignment candidate) ↔
        QueryMostGeneralACUnifier
          (fun assignment => NaturalAC (substituteQueryNatural assignment left)
            (substituteQueryNatural assignment right))
          (nativeQueryVariables (encodeNativeNatural left) ++
            nativeQueryVariables (encodeNativeNatural right)) candidate := by
  rw [← native_singleton_complete_iff, ← query_singleton_complete_iff]
  exact native_natural_complete_unifiers_iff left right [candidate]

#print axioms native_singleton_complete_iff
#print axioms query_singleton_complete_iff
#print axioms native_message_complete_unifiers_iff
#print axioms native_natural_complete_unifiers_iff
#print axioms native_message_most_general_iff
#print axioms native_natural_most_general_iff

end Cairn.Equations
