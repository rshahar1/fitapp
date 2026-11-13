# Feature Specification: Workout Templates

**Feature Branch**: `003-workout-templates`

**Created**: 2026-11-13

**Status**: Draft

**Input**: User description: "Workout templates (user-created routines). Start a workout from a
template instead of adding exercises one by one. Only templates the user creates. Create from
scratch, save a finished or live workout as a template, edit (rename, add/remove/reorder) and delete
(with confirmation), start a workout from a template with exercises pre-added in order using their
current plans. Listed on the Train tab, start in one tap. Blocked while another workout is in
progress (offer Continue). Offline, local, sync-ready. Out of scope: built-in routines, folders,
sharing, per-template set/rep overrides, scheduling."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start a workout from a template (Priority: P1)

The lifter trains the same few routines (e.g. "Push", "Pull", "Legs"). On the Train tab they see
their templates and tap "Push": a live workout opens with Bench Press, Incline Dumbbell Bench Press,
Overhead Press and Triceps Pushdown already added in order, each prescribed from its current plan,
ready for one-tap logging.

**Why this priority**: This is the value of the feature: no more adding the same exercises every
session.

**Independent Test**: With one saved template of 3 exercises, tap it on the Train tab: a live
workout opens containing exactly those 3 exercises in the template's order, with set tables
prescribed from their plans.

**Acceptance Scenarios**:

1. **Given** a template "Push" with 4 exercises and no workout in progress, **When** the user taps
   Start on it, **Then** a live workout starts with those 4 exercises in the same order.
2. **Given** an exercise in the template has a plan, **Then** its set table is prescribed from the
   current plan exactly as when added manually (progression unchanged).
3. **Given** an exercise in the template has no plan yet, **Then** it shows the plan setup card as
   today.
4. **Given** a workout is already in progress, **When** the user tries to start from a template,
   **Then** the app does not start a second workout and offers "Continue workout" instead.
5. **Given** a workout started from a template, **Then** the user can still add, remove and log
   exercises freely; the template itself is not changed.

---

### User Story 2 - Create and manage templates (Priority: P1)

The lifter creates "Legs" by naming it and picking exercises from the library (including custom
ones), reorders them, and later renames the template, removes an exercise, adds another, or deletes
the template.

**Why this priority**: Templates must exist before they can be used; this is the primary way to
make them.

**Independent Test**: Create "Legs" with Squat, Romanian Deadlift, Leg Curl; reorder Leg Curl to
the top; rename to "Leg day"; it appears on the Train tab with 3 exercises in the new order.
Delete it after confirming: it disappears.

**Acceptance Scenarios**:

1. **Given** the Train tab, **When** the user chooses "New template", enters a name and adds
   exercises, **Then** the template is saved and listed.
2. **Given** a template editor, **When** the user drags an exercise to a new position, **Then** the
   new order is saved.
3. **Given** a template editor, **When** the user removes an exercise, **Then** it is removed
   without confirmation (it can be re-added); **when** the user deletes the whole template, **then**
   a confirmation is required.
4. **Given** a name that is empty or only spaces, **Then** the template cannot be saved.
5. **Given** a name already used by another template (ignoring case), **Then** the user is told the
   name is taken.
6. **Given** a template with no exercises, **Then** it cannot be saved ("Add at least one
   exercise").
7. **Given** the same exercise is added twice, **Then** it appears only once (duplicates are
   ignored).

---

### User Story 3 - Save a workout as a template (Priority: P2)

After a good session the lifter saves it as "Upper A" so next time they can start it in one tap.

**Why this priority**: Fastest way to build templates from real workouts, but creating from scratch
already covers the need.

**Independent Test**: Open a finished workout with 3 exercises, choose "Save as template", name it:
a template with those 3 exercises in workout order appears on the Train tab.

**Acceptance Scenarios**:

1. **Given** a finished workout in History, **When** the user picks "Save as template" from its
   menu and enters a name, **Then** a template with the workout's exercises in order is created.
2. **Given** a live workout with exercises, **When** the user picks "Save as template", **Then** the
   same happens without affecting the live workout.
3. **Given** a workout with no exercises, **Then** "Save as template" is unavailable.
4. **Given** the suggested name, **Then** it defaults to the workout's date (e.g. "Workout 13 Nov")
   and can be edited.

---

### Edge Cases

- An exercise used in templates is a custom exercise: it works like any other.
- Templates list is empty: the Train tab shows a short hint and a "New template" action.
- Many templates (20+): the list stays usable (scrolls; most recently used first).
- A template's exercise no longer exists (future sync/deletion): it is skipped when starting, and the
  editor shows only existing exercises.
- Starting from a template while the app was killed mid-start: either the full workout exists or
  none (no half-created workout).
- Long template names (up to 40 characters) display without breaking layout.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to create a template with a name (1–40 characters after trimming,
  unique ignoring case) and an ordered list of at least one distinct exercise from the library or
  their custom exercises.
- **FR-002**: Users MUST be able to rename a template, add exercises, remove exercises, and change
  their order; every change is saved.
- **FR-003**: Users MUST be able to delete a template after confirming; deleting a template never
  affects workouts or history.
- **FR-004**: Users MUST be able to save any finished or live workout that has at least one exercise
  as a new template containing its exercises in workout order (no sets, weights or plans copied).
- **FR-005**: The Train tab MUST list the user's templates (most recently used first, then newest),
  each showing its name and the exercise names, with a one-tap Start action.
- **FR-006**: Starting from a template MUST create the live workout with all of the template's
  existing exercises in order, as one all-or-nothing action, and open the live workout screen.
- **FR-007**: Starting from a template MUST be refused when a workout is already in progress, with
  an option to continue that workout.
- **FR-008**: Workouts started from a template MUST behave exactly like manually built workouts
  (plans, prescriptions, progression, editing, history); changes to the workout never change the
  template.
- **FR-009**: The app MUST record when a template was last used to order the list.
- **FR-010**: Templates MUST be stored locally, work offline, and use the same sync-ready
  conventions as other user data (stable ids, change tracking, delete queue).
- **FR-011**: All template actions MUST be accessible with screen readers and use 48 dp tap targets;
  delete asks for confirmation.

### Key Entities

- **Template**: a named routine owned by the user; name, creation time, last-used time.
- **Template exercise**: an exercise in a template with its position; references an exercise from
  the library or the user's custom exercises.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From the Train tab, a workout with all of a template's exercises is ready to log in
  1 tap (vs. 1 tap per exercise plus search today).
- **SC-002**: A 5-exercise template can be created from scratch in under 60 seconds.
- **SC-003**: Saving a workout as a template takes at most 3 taps plus typing a name.
- **SC-004**: 100% of workouts started from templates contain exactly the template's exercises in
  order.
- **SC-005**: Progression results for exercises in template-started workouts are identical to
  manually built workouts in all existing progression scenarios.

## Assumptions

- Templates store exercises only; sets, reps and weights always come from each exercise's current
  plan (per-template overrides are out of scope).
- No built-in or starter templates are shipped (owner decision, 2026-11-13).
- "Most recently used first" ordering is sufficient; no folders or manual ordering of templates.
- Templates appear on the Train tab; a separate tab is not needed.
- Duplicated exercises within one template are not allowed (one entry per exercise).
