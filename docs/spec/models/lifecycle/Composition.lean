import Refinement

namespace Cairn

abbrev Key := Nat × Bool

structure World where
  clock : Nat
  locals : Key → Option State

def WorldInvariant (world : World) : Prop :=
  ∀ key state, world.locals key = some state →
    Invariant state ∧ state.clock = world.clock

def tickLocal (entry : Option State) : Option State :=
  entry.map fun state => { state with clock := state.clock + 1 }

def create (world : World) (keys : List Key) : World :=
  ⟨world.clock + 1, fun key =>
    if key ∈ keys then some (initialAt world.clock) else tickLocal (world.locals key)⟩

def advance (world : World) (key : Key) (next : State) : World :=
  ⟨world.clock + 1, fun other =>
    if other = key then some next else tickLocal (world.locals other)⟩

def stutter (world : World) : World :=
  ⟨world.clock + 1, fun key => tickLocal (world.locals key)⟩

theorem stutter_records_no_actions (state : State) :
    tickLocal (some state) =
      some { state with clock := state.clock + 1 } := by
  rfl

theorem fresh_creation_preserves_existing {world : World} {keys : List Key}
    (fresh : ∀ key ∈ keys, world.locals key = none)
    {key : Key} {state : State} (existing : world.locals key = some state) :
    (create world keys).locals key =
      some { state with clock := state.clock + 1 } := by
  have absent : key ∉ keys := by
    intro member
    have conflict := fresh key member
    rw [existing] at conflict
    contradiction
  simp [create, absent, existing, tickLocal]

theorem tick_invariant {world : World} (invariant : WorldInvariant world)
    {key : Key} {next : State} (found : tickLocal (world.locals key) = some next) :
    Invariant next ∧ next.clock = world.clock + 1 := by
  cases previous : world.locals key with
  | none => simp [tickLocal, previous] at found
  | some state =>
    simp [tickLocal, previous] at found
    subst next
    obtain ⟨localInvariant, clockEq⟩ := invariant key state previous
    exact ⟨step_invariant localInvariant (show step state .stutter = _ from rfl),
      by simp [clockEq]⟩

theorem create_invariant {world : World} (invariant : WorldInvariant world)
    (keys : List Key) : WorldInvariant (create world keys) := by
  intro key state found
  by_cases member : key ∈ keys
  · simp [create, member] at found
    subst state
    exact ⟨initial_at_invariant _, rfl⟩
  · simp [create, member] at found
    exact tick_invariant invariant found

theorem advance_invariant {world : World} (invariant : WorldInvariant world)
    {key : Key} {state next : State} {action : Action}
    (existing : world.locals key = some state)
    (transition : step state action = some next) :
    WorldInvariant (advance world key next) := by
  intro other result found
  by_cases same : other = key
  · subst other
    simp [advance] at found
    subst result
    obtain ⟨localInvariant, clockEq⟩ := invariant key state existing
    exact ⟨step_invariant localInvariant transition,
      by simpa [advance, clockEq] using (step_records_actions transition).2.2.2⟩
  · simp [advance, same] at found
    exact tick_invariant invariant found

inductive GlobalTrace : World → Prop where
  | empty : GlobalTrace ⟨0, fun _ => none⟩
  | stutter : GlobalTrace world → GlobalTrace (Cairn.stutter world)
  | pair : GlobalTrace world →
      (∀ key ∈ keys, world.locals key = none) →
      GlobalTrace (create world keys)
  | next : GlobalTrace world →
      world.locals key = some state →
      Enabled (inventory state) action stage →
      step state action = some next →
      GlobalTrace (advance world key next)

theorem global_invariant {world : World} (trace : GlobalTrace world) :
    WorldInvariant world := by
  induction trace with
  | empty => intro key state found; simp at found
  | stutter _ induction => exact fun _ _ found => tick_invariant induction found
  | pair _ _ induction => exact create_invariant induction _
  | next _ existing _ transition induction =>
      exact advance_invariant induction existing transition

theorem all_pairs_serialized {world : World} (trace : GlobalTrace world)
    {key : Key} {state : State} (found : world.locals key = some state) :
    Serialized state ∧ MarkerOrder state := by
  have invariant := (global_invariant trace key state found).1
  exact ⟨invariant.serialized, invariant.markerOrder⟩

theorem global_linear_step {world : World} (trace : GlobalTrace world)
    {key : Key} {state : State} {action : Action} {stage : Nat}
    (existing : world.locals key = some state)
    (enabled : Enabled (inventory state) action stage) :
    ∃ next, GlobalTrace (advance world key next) ∧
      inventory next = rewrite (inventory state) action stage := by
  obtain ⟨next, transition, inventoryEq⟩ := linear_step_simulates enabled
  exact ⟨next, .next trace existing enabled transition, inventoryEq⟩

theorem global_fresh_pair {world : World} (trace : GlobalTrace world)
    (pid : Nat) (fresh : ∀ role, world.locals (pid, role) = none) :
    GlobalTrace (create world [(pid, false), (pid, true)]) := by
  apply GlobalTrace.pair trace
  intro key member
  simp only [List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl
  · exact fresh false
  · exact fresh true

theorem global_stutter {world : World} (trace : GlobalTrace world) :
    GlobalTrace (stutter world) :=
  .stutter trace

#print axioms all_pairs_serialized
#print axioms global_linear_step
#print axioms fresh_creation_preserves_existing
#print axioms global_fresh_pair
#print axioms global_stutter
#print axioms stutter_records_no_actions

end Cairn
