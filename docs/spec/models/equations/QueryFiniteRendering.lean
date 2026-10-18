import QuerySourceTerms

namespace Cairn.Equations

theorem native_mapM_exact (source : List α) (render : α → Option β) (value : α → β)
    (defined : ∀ item ∈ source, render item = some (value item)) :
    source.mapM render = some (source.map value) := by
  induction source with
  | nil => rfl
  | cons item rest induction =>
    rw [List.mapM_cons, defined item (by simp),
      induction (fun next member => defined next (by simp [member]))]
    rfl

theorem native_mapM_exists (source : List α) (render : α → Option β)
    (defined : ∀ item ∈ source, ∃ value, render item = some value) :
    ∃ values, source.mapM render = some values := by
  induction source with
  | nil => exact ⟨[], rfl⟩
  | cons item rest induction =>
    obtain ⟨value, rendered⟩ := defined item (by simp)
    obtain ⟨values, remaining⟩ :=
      induction (fun next member => defined next (by simp [member]))
    exact ⟨value :: values, by rw [List.mapM_cons, rendered, remaining]; rfl⟩

theorem native_mapM_member {source : List α} {render : α → Option β} {values : List β}
    (rendered : source.mapM render = some values)
    (member : item ∈ source) : ∃ value ∈ values, render item = some value := by
  induction source generalizing values with
  | nil => simp at member
  | cons first rest induction =>
    cases head : render first with
    | none => simp [List.mapM_cons, head] at rendered
    | some value =>
      cases tail : rest.mapM render with
      | none => simp [List.mapM_cons, head, tail] at rendered
      | some remaining =>
        have same : value :: remaining = values := by
          simpa [List.mapM_cons, head, tail] using rendered
        subst values
        rcases List.mem_cons.mp member with rfl | member
        · exact ⟨value, by simp, head⟩
        · obtain ⟨next, included, result⟩ := induction tail member
          exact ⟨next, List.mem_cons_of_mem _ included, result⟩

theorem native_mapM_preserve (source : List α) (first second : α → Option β)
    (preserves : ∀ item ∈ source, ∀ value, first item = some value → second item = some value)
    (rendered : source.mapM first = some values) :
    source.mapM second = some values := by
  induction source generalizing values with
  | nil => exact rendered
  | cons item rest induction =>
    cases head : first item with
    | none => simp [List.mapM_cons, head] at rendered
    | some value =>
      cases tail : rest.mapM first with
      | none => simp [List.mapM_cons, head, tail] at rendered
      | some remaining =>
        have same : value :: remaining = values := by
          simpa [List.mapM_cons, head, tail] using rendered
        subst values
        rw [List.mapM_cons, preserves item (by simp) value head,
          induction (fun next included => preserves next (by simp [included])) tail]
        rfl

theorem native_marker_removal_shorter {marker : Nat} {available : List Nat}
    (member : marker ∈ available) :
    (available.filter (fun index => index != marker)).length < available.length := by
  induction available with
  | nil => simp at member
  | cons first rest induction =>
    by_cases same : first = marker
    · subst first
      simpa using Nat.lt_succ_of_le (List.length_filter_le (fun index => index != marker) rest)
    · have included : marker ∈ rest := (List.mem_cons.mp member).resolve_left (Ne.symm same)
      simpa [List.filter_cons, same] using Nat.succ_lt_succ (induction included)

theorem native_filterMap_congr (source : List α) (first second : α → Option β)
    (agree : ∀ item ∈ source, first item = second item) :
    source.filterMap first = source.filterMap second := by
  induction source with
  | nil => rfl
  | cons item rest induction =>
    rw [List.filterMap_cons, List.filterMap_cons, agree item (by simp),
      induction (fun next member => agree next (by simp [member]))]

theorem native_mapM_congr (source : List α) (first second : α → Option β)
    (agree : ∀ item ∈ source, first item = second item) :
    source.mapM first = source.mapM second := by
  induction source with
  | nil => rfl
  | cons item rest induction =>
    rw [List.mapM_cons, List.mapM_cons, agree item (by simp),
      induction (fun next member => agree next (by simp [member]))]

theorem native_find_congr (source : List α) (first second : α → Bool)
    (agree : ∀ item ∈ source, first item = second item) :
    source.find? first = source.find? second := by
  induction source with
  | nil => rfl
  | cons item rest induction =>
    rw [List.find?_cons, List.find?_cons, agree item (by simp),
      induction (fun next member => agree next (by simp [member]))]

#print axioms native_mapM_exact
#print axioms native_mapM_exists
#print axioms native_mapM_member
#print axioms native_mapM_preserve
#print axioms native_marker_removal_shorter
#print axioms native_filterMap_congr
#print axioms native_mapM_congr
#print axioms native_find_congr

end Cairn.Equations
