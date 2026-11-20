# Feature Specification: Workout Template Fixes

**Feature Branch**: `023-workout-template-fixes`

**Created**: 2026-11-20

**Status**: Implemented (device check open)

**Input**: Owner request, four fixes: (1) notes from earlier sessions are not carried into a workout
started from a template; (2) a template workout shows an "Add Set" button inside every exercise,
duplicating the set count in the exercise's plan; (3) exercise notes still look like they are being
typed (focused, blinking cursor) after entering them, instead of saved; (4) "Continue workout" after
the app was closed or backgrounded opens at the top of the workout instead of the current exercise.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Notes carry over in template workouts (Priority: P1)

The user keeps cues on an exercise ("seat 4", "slow negatives"). Starting the same template next
time, each exercise already shows the latest note written for it, so the cue is never lost.

**Independent Test**: Start a template, write a note on an exercise, finish. Start the template
again: the note is there and can be edited.

**Acceptance Scenarios**:

1. **Given** an earlier finished workout from template T with note "seat 4" on Bench press, **When**
   T is started again, **Then** Bench press shows "seat 4".
2. **Given** several earlier T workouts, **When** T is started, **Then** each exercise shows the note
   of its most recent earlier session that had a note (empty notes are skipped).
3. **Given** a note only in an ad-hoc workout or in another template, **When** T is started, **Then**
   it is not carried over.
4. **Given** the carried note is edited in the new workout, **Then** only the new workout's note
   changes; earlier workouts keep theirs.

---

### User Story 2 - One place to change the set count in template workouts (Priority: P2)

**Independent Test**: Start a template whose exercise has a plan: the exercise has no "Add Set"
button; "Edit plan" changes the number of set rows.

**Acceptance Scenarios**:

1. **Given** a workout exercise using its template's plan, **Then** no "Add Set" button is shown
   (live or when editing a finished workout).
2. **Given** an ad-hoc exercise, or a template exercise whose template entry was deleted (a live
   session is then unlinked and uses the exercise's own plan; a finished one is an orphan), **Then**
   "Add Set" is still shown when the card is editable.
3. **Given** a template exercise, **When** the target sets are changed in "Edit plan", **Then** the
   number of set rows follows.

---

### User Story 3 - Notes save on their own (Priority: P2)

**Independent Test**: Type a note on a workout exercise, tap Done on the keyboard: the keyboard
closes, no cursor blinks, and the note is stored.

**Acceptance Scenarios**:

1. **Given** the user types a note, **When** they pause typing, **Then** the note is saved without
   any other action.
2. **When** they tap the keyboard's Done key or tap outside the field, **Then** the note is saved,
   the field loses focus and the keyboard closes.
3. **When** they leave the screen while still typing, **Then** the note is saved.
4. **Given** the note is cleared, **Then** the exercise is stored with no note.

---

### User Story 4 - Continue where you left off (Priority: P1)

**Independent Test**: In a live workout of 5 exercises, log all sets of exercises 1–3, close the app,
reopen it and tap "Continue workout": the screen opens at exercise 4.

**Acceptance Scenarios**:

1. **Given** a live workout where the last exercise with logged sets still has planned sets to log,
   **When** the workout screen opens, **Then** it scrolls to that exercise.
2. **Given** the last exercise with logged sets has all planned sets logged and another exercise
   follows, **Then** it scrolls to the following exercise.
3. **Given** no logged sets, **Then** it opens at the top.
4. **Given** the user then scrolls or adds an exercise, **Then** the screen does not jump back.
5. **Given** a finished workout opened from History, **Then** it opens at the top.

### Edge Cases

- The last exercise with logged sets has no plan: it is the current exercise.
- The last exercise with sets is complete and is the last one: scroll to it.
- Exercises without logged sets before the last exercise with sets are not chosen (the user moved on).
- Notes made of spaces only count as no note.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Starting a workout from a template MUST give each exercise the note of the most
  recent earlier finished session of the same template exercise that has a non-empty note.
- **FR-002**: Notes from ad-hoc workouts or other templates MUST NOT be carried over.
- **FR-003**: A workout exercise that uses its template's plan MUST NOT show "Add Set"; the set
  count is changed through "Edit plan". Ad-hoc and orphaned exercises keep "Add Set".
- **FR-004**: An exercise note MUST save automatically shortly after typing stops, on the keyboard
  Done key, on tapping outside the field, and when the screen is left.
- **FR-005**: After Done or tapping outside, the note field MUST lose focus (no cursor, keyboard
  closed).
- **FR-006**: Opening a live workout MUST scroll once to the current exercise: the last exercise
  with logged sets, or the next exercise when that one has all planned sets logged. With no logged
  sets it opens at the top.
- **FR-007**: Finished workouts opened from History MUST open at the top.

### Key Entities

- **Workout exercise note**: free text per exercise in a workout; now pre-filled from the latest
  earlier note of the same template exercise.

## Success Criteria *(mandatory)*

- **SC-001**: In 100% of template starts, every exercise with an earlier note shows it.
- **SC-002**: A template workout exercise shows exactly one way to change its set count.
- **SC-003**: After Done, the note field shows no cursor and the note survives an app restart.
- **SC-004**: "Continue workout" shows the current exercise on screen without scrolling.

## Assumptions

- "Same template exercise" is the exercise's entry in the template; it is kept when the template is
  renamed, reordered or its plan is edited, and lost when the exercise is removed from the template.
- The carried note is the latest non-empty one, so a note cleared in one session reappears from an
  older session; clearing it in every session removes it.
- Debounce delay about 0.6 s. No change to how workout-level notes or activity notes work.
- "Opens" means the first time the live workout screen is shown in this visit (app start, Continue
  workout, or returning to it from Train).
