# Feature Specification: Templates That Carry Their Own Progression

**Feature Branch**: `005-template-progression`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "A template should also save progress for that specific type of
workout. Example: in a chest template, Cable Fly at 20 kg, set 1 = 10/10 reps and set 2 = 10/10
reps → the template must update so the next workout from that template starts at 22.5 kg (base +
the chosen increment). The last ('power'/overload) set never matters; only if the working sets hit
the target does the template's weight go up."

## Clarifications

### Session 2026-11-13

- Q: Which progression rule? → A: The owner's rule, **everywhere** (template and ad-hoc
  workouts): only the working sets 1..N−1 decide (each logged at ≥ base weight with ≥ target reps);
  the last (overload) set never gates or sets the result; next base = base + increment (rounded to
  0.25 kg). No "jump" to a heavier overload weight.
- Q: Where does progress live? → A: **Per template.** Each exercise in a template has its own plan
  (base weight, target reps, sets, increment, optional rest), seeded from the exercise's current
  plan when it is added. Workouts started from a template progress only that template's plans.
  Ad-hoc workouts (and exercises added ad hoc to a template workout) keep using the exercise's own
  plan.
- Q: Should a template workout also update the exercise's own plan? → A: **No.**
- Q: Was "template" the right word? → A: Yes; per-template progress means Cable Fly in "Chest" can
  be at 22.5 kg while Cable Fly in another template (or ad hoc) stays at 20 kg.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progress depends only on the working sets (Priority: P1)

The lifter's Cable Fly plan is 3 × 10 @ 20 kg, +2.5. They log 20×10, 20×10 and then fail the last
heavy set (22.5×4), or skip it. Because the working sets hit the target, the next prescription is
22.5 kg. If they miss a rep on a working set, the weight stays.

**Why this priority**: This is the owner's corrected rule and changes every finish.

**Independent Test**: With plan base 20, reps 10, sets 3, inc 2.5: finish 20×10, 20×10 with no set 3
→ next base 22.5. Finish 20×10, 20×9, 22.5×10 → base stays 20.

**Acceptance Scenarios**:

1. **Given** plan 20 / 10 reps / 3 sets / +2.5, **When** sets 20×10, 20×10, 22.5×6 are finished,
   **Then** the next base is 22.5 (progressed).
2. **Given** the same plan, **When** sets 20×10, 20×10 are finished and set 3 is not logged,
   **Then** the next base is 22.5.
3. **Given** the same plan, **When** sets 20×10, 20×10, 25×3 are finished, **Then** the next base is
   22.5 (the overload weight never sets the result).
4. **Given** the same plan, **When** set 2 is 20×8, **Then** the base stays 20 ("missed reps").
5. **Given** the same plan, **When** set 1 is 17.5×10, **Then** the base stays 20 (lighter than base
   does not count).
6. **Given** the same plan, **When** only set 1 is logged, **Then** the base stays 20
   ("incomplete").
7. **Given** a 2-set plan, **When** set 1 hits the target, **Then** it progresses.

---

### User Story 2 - Each template keeps its own weights (Priority: P1)

The lifter has a "Chest" template with Cable Fly and also does Cable Fly in "Upper". After a Chest
workout where Cable Fly progressed, the next Chest workout prescribes 22.5 kg, while Upper (and an
ad-hoc Cable Fly) still prescribe 20 kg.

**Why this priority**: This is the owner's request: progress saved for that specific type of
workout.

**Independent Test**: Create templates A and B both containing Cable Fly (plan 20 kg). Start from A,
hit the working sets, finish: A's Cable Fly is 22.5, B's is 20, the exercise's own plan is 20.

**Acceptance Scenarios**:

1. **Given** an exercise is added to a template, **Then** the template's plan for it starts as a
   copy of the exercise's current plan (or "no plan yet" if the exercise has none).
2. **Given** a workout started from a template, **Then** each template exercise's set table,
   plan summary and rest time come from the template's plan.
3. **Given** that workout is finished and an exercise progressed, **Then** only that template's
   plan goes up; other templates and the exercise's own plan are unchanged.
4. **Given** a template exercise has no plan yet, **When** it appears in the workout, **Then** the
   plan setup card is shown and the plan entered is saved to that template.
5. **Given** a template workout, **When** "Edit plan" is chosen on a template exercise, **Then** the
   template's plan is edited.
6. **Given** an exercise added ad hoc to a template workout, **Then** it uses and progresses the
   exercise's own plan.
7. **Given** an ad-hoc workout (not from a template), **Then** behavior is as before, using the
   exercise's own plan with the new rule.
8. **Given** the finish summary, **Then** each exercise shows from → to (or "stays at") for the
   plan it progressed.

---

### User Story 3 - Edit a template's plans (Priority: P2)

In the template editor the lifter sees each exercise with its plan ("3 × 10 @ 20 kg · +2.5") and
taps it to change base weight, reps, sets, increment or rest for this template only.

**Why this priority**: Lets the user set up or correct a template's weights without starting a
workout.

**Independent Test**: Open "Chest", tap Cable Fly, set 25 kg / 8 reps / 4 sets, save the template:
the next Chest workout prescribes 25, 25, 25, 27.5 × 8.

**Acceptance Scenarios**:

1. **Given** the template editor, **Then** each exercise row shows its plan summary or "No plan
   yet".
2. **Given** the user edits a row's plan and saves the template, **Then** the plan is stored for
   this template only.
3. **Given** the user discards the editor, **Then** plan edits are discarded too.
4. **Given** a new template created from scratch or saved from a workout, **Then** plans are seeded
   from the plan each exercise used (template plan for template exercises, otherwise the
   exercise's own plan).

---

### User Story 4 - History edits stay safe per plan (Priority: P1)

The lifter finishes a Chest workout by mistake, resumes it, edits a finished one, or deletes one.
The template's weight is corrected only when that workout is the latest one for that template
exercise and the weight still equals what it produced; otherwise history is corrected but the plan
stays.

**Why this priority**: A wrong base weight is the worst bug (constitution II).

**Independent Test**: PRD §11 scenarios 4–8 pass for a template plan and for an exercise's own
plan, and never cross-affect the other.

**Acceptance Scenarios**:

1. **Given** the latest Chest workout progressed Cable Fly 20 → 22.5, **When** it is resumed,
   **Then** Chest's Cable Fly is back to 20; finishing again re-applies the rule.
2. **Given** that workout, **When** set 2 is edited to 9 reps, **Then** Chest's Cable Fly is 20;
   back to 10 → 22.5.
3. **Given** two Chest workouts (20 → 22.5 → 25), **When** the first is edited to fail, **Then**
   its stored result becomes 20 but the plan stays 25.
4. **Given** the user set Chest's Cable Fly to 30 by hand after finishing, **When** the workout is
   resumed and re-finished, **Then** the plan stays 30.
5. **Given** the latest Chest workout is deleted, **Then** its increase is undone; deleting an
   older one leaves the plan unchanged.
6. **Given** a template workout is edited, resumed or deleted, **Then** the exercise's own plan and
   other templates are never changed, and vice versa.

### Edge Cases

- **Template deleted, or an exercise removed from a template**: finished workouts that came from it
  keep their history and remain editable, but no plan is changed by those edits. A workout in
  progress from it continues with the exercise's own plan for the affected exercises (a resumed
  workout keeps the plan it was done with and changes no plan when finished again).
- **Exercise removed from a template and later re-added**: it gets a fresh plan seeded from the
  exercise's own plan (the old template progress is not restored).
- **Upgrading the app**: existing templates get plans copied from each exercise's current plan;
  existing finished workouts count as ad-hoc history (their exercise's own plan).
- **Editing an old session after the update** re-evaluates it with the new rule.
- **Same exercise twice in a template** is still impossible (one plan per template exercise).
- **Prescription is unchanged**: the last set is still prescribed at base + increment and marked
  as the overload set; it just no longer decides progression.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The evaluation MUST progress a session when, and only when, every working set
  1..N−1 is logged with weight ≥ base and reps ≥ target; the result is base + increment rounded to
  0.25 kg. The overload set MUST NOT affect the outcome.
- **FR-002**: Outcomes MUST be one of: progressed, missed reps (a working set short on reps or
  lighter than base), incomplete (a working set not logged).
- **FR-003**: Each exercise in a template MUST have its own optional plan (base, reps, sets ≥ 2,
  increment > 0, optional rest), validated like any plan.
- **FR-004**: When an exercise is added to a template (create, edit, save from workout, or app
  upgrade), its template plan MUST be seeded from the plan that exercise currently uses in that
  context; with no plan available it stays empty.
- **FR-005**: A workout started from a template MUST remember, per workout exercise, which template
  exercise it came from.
- **FR-006**: Prescription, plan summary, rest time, plan setup and Edit plan for such a workout
  exercise MUST use the template plan; exercises added ad hoc use the exercise's own plan.
- **FR-007**: Finishing, editing, resuming and deleting MUST apply and undo progression on the plan
  the session used (template plan or exercise plan), never on another plan.
- **FR-008**: The history-safety rule MUST be evaluated per plan: rewrite only if the workout is the
  latest finished session for that plan and the plan's base equals the session's stored result.
- **FR-009**: A session whose template plan no longer exists MUST never change any plan.
- **FR-010**: The template editor MUST show and edit each exercise's template plan; edits are
  saved or discarded with the template.
- **FR-011**: The data upgrade MUST preserve all existing data and seed template plans from current
  exercise plans.
- **FR-012**: Everything MUST work offline; all multi-row writes are atomic.

### Key Entities

- **Template exercise plan**: base weight, target reps, sets, increment, optional rest, belonging
  to one exercise in one template.
- **Workout exercise → template exercise link**: which template exercise (if any) a session came
  from; decides which plan the session progresses.
- **Exercise plan** (existing): used by ad-hoc sessions.

## Success Criteria *(mandatory)*

- **SC-001**: In 100% of the owner's example sessions (working sets hit, last set anything), the
  next workout from the same template prescribes base + increment.
- **SC-002**: Progressing an exercise in one template never changes its weight in another template
  or in ad-hoc workouts (verified by automated scenario tests).
- **SC-003**: All PRD §11 history scenarios pass for both template and exercise plans.
- **SC-004**: After the update, 100% of existing workouts, sets, templates and plans are still
  present, and each template's weights match what the user had before.
- **SC-005**: Editing a template exercise's plan takes at most 3 taps from the template editor.

## Assumptions

- The overload set is still prescribed and marked (the owner's "power set"); only its role in
  evaluation changes.
- The exercise detail page keeps showing and editing the exercise's own plan (used by ad-hoc
  workouts).
- Template workouts started before this update cannot be identified, so they count as ad-hoc.
- No sync is built (Phase 2); new data stays sync-ready.
