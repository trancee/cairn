import Lifecycle

namespace Pqcble

inductive Token where
  | slot (stage : Nat)
  | permit (stage : Nat)
  | busy (stage : Nat)
  | attempt (stage : Nat)
  | finish (stage : Nat)
  deriving DecidableEq, Repr

abbrev Bag := Token → Nat

def countTokens (tokens : List Token) : Bag :=
  fun token => tokens.count token

def inventory (state : State) : Bag :=
  countTokens (match state.phase with
    | .available => [.slot state.stage]
    | .reserved => [.permit state.stage, .busy state.stage]
    | .running => [.attempt state.stage, .busy state.stage]
    | .finished => [.finish state.stage])

def inputs (action : Action) (stage : Nat) : List Token :=
  match action with
  | .acquire => [.slot stage]
  | .start => [.permit stage]
  | .finish => [.busy stage, .attempt stage]
  | .release => [.finish stage]
  | .stutter => []

def outputs (action : Action) (stage : Nat) : List Token :=
  match action with
  | .acquire => [.permit (stage + 1), .busy (stage + 1)]
  | .start => [.attempt stage]
  | .finish => [.finish (stage + 1)]
  | .release => [.slot stage]
  | .stutter => []

def Enabled (bag : Bag) (action : Action) (stage : Nat) : Prop :=
  ∀ token, countTokens (inputs action stage) token ≤ bag token

def rewrite (bag : Bag) (action : Action) (stage : Nat) : Bag :=
  fun token => bag token - countTokens (inputs action stage) token +
    countTokens (outputs action stage) token

def observation (action : Action) (stage : Nat) : Option Nat × Option Nat × Option Nat :=
  match action with
  | .acquire => (some (stage + 1), none, none)
  | .start => (none, some stage, none)
  | .finish => (none, none, some (stage + 1))
  | .release => (some stage, none, none)
  | .stutter => (none, none, none)

def recordEvent (event : Option Nat) (clock : Nat) (history : List Event) : List Event :=
  match event with
  | some ordinal => ⟨clock, ordinal⟩ :: history
  | none => history

theorem step_records_actions {state next : State} {action : Action}
    (transition : step state action = some next) :
    next.markers = recordEvent (observation action state.stage).1 state.clock state.markers ∧
    next.starts = recordEvent (observation action state.stage).2.1 state.clock state.starts ∧
    next.finishes = recordEvent (observation action state.stage).2.2 state.clock state.finishes ∧
    next.clock = state.clock + 1 := by
  cases action <;> cases phaseEq : state.phase <;>
    simp [step, phaseEq] at transition <;> subst next <;>
    simp [observation, recordEvent]

theorem enabled_phase {state : State} {action : Action} {stage : Nat}
    (enabled : Enabled (inventory state) action stage) :
    action = .stutter ∨
      (stage = state.stage ∧
        ((action = .acquire ∧ state.phase = .available) ∨
         (action = .start ∧ state.phase = .reserved) ∨
         (action = .finish ∧ state.phase = .running) ∨
         (action = .release ∧ state.phase = .finished))) := by
  cases action with
  | stutter => exact Or.inl rfl
  | acquire =>
    have witness := enabled (.slot stage)
    cases phaseEq : state.phase <;>
      simp [inventory, inputs, countTokens, phaseEq] at witness
    exact Or.inr ⟨witness, Or.inl ⟨rfl, rfl⟩⟩
  | start =>
    have witness := enabled (.permit stage)
    cases phaseEq : state.phase <;>
      simp [inventory, inputs, countTokens, phaseEq] at witness
    exact Or.inr ⟨witness, Or.inr (Or.inl ⟨rfl, rfl⟩)⟩
  | finish =>
    have witness := enabled (.attempt stage)
    cases phaseEq : state.phase <;>
      simp [inventory, inputs, countTokens, phaseEq] at witness
    exact Or.inr ⟨witness, Or.inr (Or.inr (Or.inl ⟨rfl, rfl⟩))⟩
  | release =>
    have witness := enabled (.finish stage)
    cases phaseEq : state.phase <;>
      simp [inventory, inputs, countTokens, phaseEq] at witness
    exact Or.inr ⟨witness, Or.inr (Or.inr (Or.inr ⟨rfl, rfl⟩))⟩

theorem linear_step_simulates {state : State} {action : Action} {stage : Nat}
    (enabled : Enabled (inventory state) action stage) :
    ∃ next, step state action = some next ∧
      inventory next = rewrite (inventory state) action stage := by
  rcases enabled_phase enabled with rfl | ⟨rfl, phases⟩
  · refine ⟨{ state with clock := state.clock + 1 }, by simp [step], ?_⟩
    funext token
    simp [inventory, rewrite, inputs, outputs, countTokens]
  · rcases phases with ⟨rfl, phaseEq⟩ | ⟨rfl, phaseEq⟩ |
      ⟨rfl, phaseEq⟩ | ⟨rfl, phaseEq⟩
    all_goals
      simp only [step, phaseEq]
      refine ⟨_, rfl, ?_⟩
      funext token
      cases token <;>
        simp [inventory, rewrite, inputs, outputs, countTokens, phaseEq, List.count_cons]
    all_goals split <;> simp_all

inductive LinearTrace : Bag → List (Action × Nat) → Prop where
  | initial : LinearTrace (inventory initial) []
  | next : LinearTrace bag actions →
      Enabled bag action stage →
      LinearTrace (rewrite bag action stage) ((action, stage) :: actions)

inductive Execution : List (Action × Nat) → State → Prop where
  | initial : Execution [] initial
  | next : Execution actions state →
      step state action = some next →
      (action = .stutter ∨ stage = state.stage) →
      Execution ((action, stage) :: actions) next

theorem projected_trace_simulates {bag : Bag} {actions : List (Action × Nat)}
    (trace : LinearTrace bag actions) :
    ∃ state, Execution actions state ∧ Reachable state ∧ inventory state = bag := by
  induction trace with
  | initial => exact ⟨initial, .initial, .initial, rfl⟩
  | @next bag actions action stage _ enabled induction =>
    obtain ⟨state, execution, reachable, inventoryEq⟩ := induction
    rw [← inventoryEq] at enabled ⊢
    obtain ⟨next, transition, nextInventory⟩ := linear_step_simulates enabled
    have stageEq : action = Action.stutter ∨ stage = state.stage := by
      rcases enabled_phase enabled with stutter | ⟨sameStage, _⟩
      · exact Or.inl stutter
      · exact Or.inr sameStage
    exact ⟨next, .next execution transition stageEq,
      .next reachable transition, nextInventory⟩

theorem projected_serialization {bag : Bag} {actions : List (Action × Nat)}
    (trace : LinearTrace bag actions) :
    ∃ state, Execution actions state ∧ inventory state = bag ∧
      Serialized state ∧ MarkerOrder state := by
  obtain ⟨state, execution, reachable, inventoryEq⟩ := projected_trace_simulates trace
  exact ⟨state, execution, inventoryEq, resume_serialized reachable,
    lock_stage_order reachable⟩

#print axioms linear_step_simulates
#print axioms step_records_actions
#print axioms projected_trace_simulates
#print axioms projected_serialization

end Pqcble
