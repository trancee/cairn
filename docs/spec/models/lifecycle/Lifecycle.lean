import Std

namespace Pqcble

inductive Phase where
  | available | reserved | running | finished
  deriving DecidableEq, Repr

inductive Action where
  | acquire | start | finish | release | stutter
  deriving DecidableEq, Repr

structure Event where
  time : Nat
  stage : Nat
  deriving DecidableEq, Repr

structure State where
  phase : Phase
  stage : Nat
  clock : Nat
  markers : List Event
  starts : List Event
  finishes : List Event
  deriving Repr

def initialAt (clock : Nat) : State :=
  ⟨.available, 1, clock + 1, [⟨clock, 1⟩], [], []⟩

def initial : State := initialAt 0

def step (state : State) (action : Action) : Option State :=
  let tick := { state with clock := state.clock + 1 }
  match action, state.phase with
  | .acquire, .available =>
      some { tick with
        phase := .reserved, stage := state.stage + 1,
        markers := ⟨state.clock, state.stage + 1⟩ :: state.markers }
  | .start, .reserved =>
      some { tick with
        phase := .running,
        starts := ⟨state.clock, state.stage⟩ :: state.starts }
  | .finish, .running =>
      some { tick with
        phase := .finished, stage := state.stage + 1,
        finishes := ⟨state.clock, state.stage + 1⟩ :: state.finishes }
  | .release, .finished =>
      some { tick with
        phase := .available,
        markers := ⟨state.clock, state.stage⟩ :: state.markers }
  | .stutter, _ => some tick
  | _, _ => none

def Serialized (state : State) : Prop :=
  ∀ first ∈ state.starts, ∀ second ∈ state.starts,
    first.time < second.time →
    ∃ completion ∈ state.finishes,
      first.time < completion.time ∧ completion.time < second.time

def MarkerOrder (state : State) : Prop :=
  ∀ first ∈ state.markers, ∀ second ∈ state.markers,
    first.time < second.time →
    ∃ previous ∈ state.markers,
      second.stage = previous.stage + 1 ∧
      first.time ≤ previous.time ∧ previous.time < second.time

def BeforeClock (events : List Event) (clock : Nat) : Prop :=
  ∀ event ∈ events, event.time < clock

def LatestMarker (state : State) : Prop :=
  ∃ latest ∈ state.markers,
    (∀ marker ∈ state.markers, marker.time ≤ latest.time) ∧
    (if state.phase = .running ∨ state.phase = .finished then
      latest.stage + (if state.phase = .finished then 1 else 0) = state.stage
    else latest.stage = state.stage)

def Ready (state : State) : Prop :=
  ∀ started ∈ state.starts,
    ∃ completion ∈ state.finishes, started.time < completion.time

structure Invariant (state : State) : Prop where
  serialized : Serialized state
  markerOrder : MarkerOrder state
  markersBefore : BeforeClock state.markers state.clock
  startsBefore : BeforeClock state.starts state.clock
  finishesBefore : BeforeClock state.finishes state.clock
  latestMarker : LatestMarker state
  ready : state.phase ≠ .running → Ready state

theorem initial_at_invariant (clock : Nat) : Invariant (initialAt clock) := by
  constructor
  · simp [Serialized, initialAt]
  · simp [MarkerOrder, initialAt]
  · simp [BeforeClock, initialAt]
  · simp [BeforeClock, initialAt]
  · simp [BeforeClock, initialAt]
  · simp [LatestMarker, initialAt]
  · simp [Ready, initialAt]

theorem initial_invariant : Invariant initial := initial_at_invariant 0

theorem tick_before {events : List Event} {clock : Nat}
    (bounded : BeforeClock events clock) : BeforeClock events (clock + 1) := by
  intro event member
  exact Nat.lt_succ_of_lt (bounded event member)

theorem prepend_before {events : List Event} {clock stage : Nat}
    (bounded : BeforeClock events clock) :
    BeforeClock (⟨clock, stage⟩ :: events) (clock + 1) := by
  intro event member
  simp only [List.mem_cons] at member
  rcases member with rfl | member
  · simp
  · exact Nat.lt_succ_of_lt (bounded event member)

theorem prepend_marker {state : State} {stage : Nat}
    (ordered : MarkerOrder state)
    (bounded : BeforeClock state.markers state.clock)
    (latest : ∃ previous ∈ state.markers,
      (∀ marker ∈ state.markers, marker.time ≤ previous.time) ∧
      stage = previous.stage + 1) :
    MarkerOrder { state with markers := ⟨state.clock, stage⟩ :: state.markers } := by
  intro first firstMember second secondMember timeOrder
  simp only [List.mem_cons] at firstMember secondMember
  rcases firstMember with rfl | firstMember
  · rcases secondMember with rfl | secondMember
    · omega
    · have := bounded second secondMember
      simp only at timeOrder
      omega
  · rcases secondMember with rfl | secondMember
    · obtain ⟨previous, member, maximum, successor⟩ := latest
      exact ⟨previous, List.mem_cons_of_mem _ member, successor,
        maximum first firstMember, bounded previous member⟩
    · obtain ⟨previous, member, successor, lower, upper⟩ :=
        ordered first firstMember second secondMember timeOrder
      exact ⟨previous, List.mem_cons_of_mem _ member, successor, lower, upper⟩

theorem new_latest {state : State} {phase : Phase} {stage : Nat}
    (bounded : BeforeClock state.markers state.clock)
    (notRunning : phase ≠ .running) (notFinished : phase ≠ .finished) :
    LatestMarker { state with
      phase := phase, stage := stage,
      markers := ⟨state.clock, stage⟩ :: state.markers } := by
  refine ⟨⟨state.clock, stage⟩, by simp, ?_, ?_⟩
  · intro marker member
    simp only [List.mem_cons] at member
    rcases member with rfl | member
    · exact Nat.le_refl _
    · exact Nat.le_of_lt (bounded marker member)
  · simp [notRunning, notFinished]

theorem prepend_start {state : State}
    (serialized : Serialized state) (ready : Ready state)
    (bounded : BeforeClock state.starts state.clock)
    (finished : BeforeClock state.finishes state.clock) :
    Serialized { state with starts := ⟨state.clock, state.stage⟩ :: state.starts } := by
  intro first firstMember second secondMember timeOrder
  simp only [List.mem_cons] at firstMember secondMember
  rcases firstMember with rfl | firstMember
  · rcases secondMember with rfl | secondMember
    · omega
    · have := bounded second secondMember
      simp only at timeOrder
      omega
  · rcases secondMember with rfl | secondMember
    · obtain ⟨completion, member, afterStart⟩ := ready first firstMember
      exact ⟨completion, member, afterStart, finished completion member⟩
    · exact serialized first firstMember second secondMember timeOrder

theorem step_invariant {state next : State} {action : Action}
    (invariant : Invariant state) (transition : step state action = some next) :
    Invariant next := by
  obtain ⟨serialized, markerOrder, markersBefore, startsBefore, finishesBefore,
    latestMarker, ready⟩ := invariant
  cases action <;> cases phaseEq : state.phase <;>
    simp [step, phaseEq] at transition <;> subst next
  all_goals try
    simpa only [phaseEq] using
      (show Invariant { state with clock := state.clock + 1 } from
        ⟨serialized, markerOrder, tick_before markersBefore, tick_before startsBefore,
          tick_before finishesBefore, latestMarker, ready⟩)
  · obtain ⟨latest, member, maximum, stageEq⟩ := latestMarker
    simp [phaseEq] at stageEq
    refine ⟨serialized, ?_, prepend_before markersBefore, tick_before startsBefore,
      tick_before finishesBefore, ?_, ?_⟩
    · exact prepend_marker markerOrder markersBefore
        ⟨latest, member, maximum, by omega⟩
    · exact new_latest markersBefore (by decide) (by decide)
    · intro _
      exact ready (by simp [phaseEq])
  · refine ⟨prepend_start serialized (ready (by simp [phaseEq])) startsBefore
      finishesBefore, markerOrder, tick_before markersBefore, prepend_before startsBefore,
      tick_before finishesBefore, ?_, ?_⟩
    · obtain ⟨latest, member, maximum, stageEq⟩ := latestMarker
      exact ⟨latest, member, maximum, by simpa [phaseEq] using stageEq⟩
    · simp
  · refine ⟨?_, markerOrder, tick_before markersBefore, tick_before startsBefore,
      prepend_before finishesBefore, ?_, ?_⟩
    · intro first firstMember second secondMember timeOrder
      obtain ⟨completion, member, lower, upper⟩ :=
        serialized first firstMember second secondMember timeOrder
      exact ⟨completion, List.mem_cons_of_mem _ member, lower, upper⟩
    · obtain ⟨latest, member, maximum, stageEq⟩ := latestMarker
      simp [phaseEq] at stageEq
      exact ⟨latest, member, maximum, by simp [stageEq]⟩
    · intro _ started member
      exact ⟨⟨state.clock, state.stage + 1⟩, by simp, startsBefore started member⟩
  · obtain ⟨latest, member, maximum, stageEq⟩ := latestMarker
    simp [phaseEq] at stageEq
    refine ⟨serialized, ?_, prepend_before markersBefore, tick_before startsBefore,
      tick_before finishesBefore, ?_, ?_⟩
    · exact prepend_marker markerOrder markersBefore
        ⟨latest, member, maximum, stageEq.symm⟩
    · exact new_latest markersBefore (by decide) (by decide)
    · intro _
      exact ready (by simp [phaseEq])

inductive Reachable : State → Prop where
  | initial : Reachable initial
  | next : Reachable state → step state action = some next → Reachable next

theorem reachable_invariant {state : State} (reachable : Reachable state) :
    Invariant state := by
  induction reachable with
  | initial => exact initial_invariant
  | next _ transition induction => exact step_invariant induction transition

theorem resume_serialized {state : State} (reachable : Reachable state) :
    Serialized state :=
  (reachable_invariant reachable).serialized

theorem lock_stage_order {state : State} (reachable : Reachable state) :
    MarkerOrder state :=
  (reachable_invariant reachable).markerOrder

theorem initial_resume_serialized {state : State} (reachable : Reachable state)
    (initiatorStarts : List Event)
    (sameEvent : ∀ event ∈ initiatorStarts, event ∈ state.starts) :
    ∀ first ∈ initiatorStarts, ∀ second ∈ initiatorStarts,
      first.time < second.time →
      ∃ completion ∈ state.finishes,
        first.time < completion.time ∧ completion.time < second.time := by
  intro first firstMember second secondMember ordered
  exact resume_serialized reachable first (sameEvent first firstMember)
    second (sameEvent second secondMember) ordered

theorem two_starts_executable :
    ∃ state, Reachable state ∧ state.starts.length = 2 ∧ state.finishes.length = 1 := by
  let reserved := (step initial .acquire).get (by decide)
  let running := (step reserved .start).get (by decide)
  let finished := (step running .finish).get (by decide)
  let available := (step finished .release).get (by decide)
  let reservedAgain := (step available .acquire).get (by decide)
  let runningAgain := (step reservedAgain .start).get (by decide)
  have first : Reachable reserved := .next .initial (show step initial .acquire = _ from rfl)
  have second : Reachable running := .next first (show step reserved .start = _ from rfl)
  have third : Reachable finished := .next second (show step running .finish = _ from rfl)
  have fourth : Reachable available := .next third (show step finished .release = _ from rfl)
  have fifth : Reachable reservedAgain := .next fourth (show step available .acquire = _ from rfl)
  have sixth : Reachable runningAgain := .next fifth (show step reservedAgain .start = _ from rfl)
  exact ⟨runningAgain, sixth, rfl, rfl⟩

#print axioms resume_serialized
#print axioms lock_stage_order
#print axioms initial_resume_serialized
#print axioms two_starts_executable

end Pqcble
