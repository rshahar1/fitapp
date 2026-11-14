# Feature Specification: Library deletion, hub cleanup, faster duration input

**Feature Branch**: `012-library-hub-cleanup`
**Created**: 2026-11-14
**Status**: Implemented

**Input**: (1) delete custom exercises; (2) delete built-in exercises too; (3) rename "Exercise
Library" on the You tab to "Gym Exercise Library"; (4) the `+` menu no longer starts gym workouts
or templates (those stay on the main Train screen), shows only sports/activities, and shows all
of them without a "More sports" button; (5) entering a long duration when logging a past activity
(e.g. 4 hours) must not take dozens of +5 taps.

## User Scenarios & Testing

### User Story 1 — Delete an exercise from the library (P1)

A user opens You → Gym Exercise Library and deletes any exercise, custom or built-in, that they
never want to see again.

**Acceptance Scenarios**

1. **Given** a custom exercise, **When** the user taps its delete action and confirms, **Then** it
   disappears from the library, the exercise picker and the Progress list.
2. **Given** a built-in exercise, **When** the user deletes it and confirms, **Then** the same
   happens, and it stays gone after the app restarts (the built-in library refresh does not bring
   it back).
3. **Given** the exercise was logged in finished workouts, **When** it is deleted, **Then** those
   past workouts still show it with its name and sets.
4. **Given** the exercise belongs to templates, **When** the user asks to delete it, **Then** the
   confirmation names those templates; after confirming it is removed from them, and a template
   left with no exercises is deleted (the confirmation says so).
5. **Given** the user cancels the confirmation, **Then** nothing changes.
6. **Given** a deleted exercise named "X", **When** the user creates an exercise named "x",
   **Then** the deleted exercise comes back (restored, with its history and plan) instead of an
   error; for a custom one, the new settings are applied.

### User Story 2 — "Gym Exercise Library" label (P3)

On the You tab the row reads "Gym Exercise Library", and the screen it opens has the same title.

### User Story 3 — `+` menu shows only sports, all at once (P1)

**Acceptance Scenarios**

1. **Given** the `+` menu is open, **Then** it has no "Gym workout" row and no template rows.
2. **Then** every sport is listed immediately (live-GPS sports first, then all others), with no
   "More sports" button.
3. **Given** a session is in progress, **Then** the "Continue …" row is still shown (resuming is
   not starting a new workout).
4. "Log a past session" stays under "Earlier".
5. The Train screen still starts empty workouts and templates as before.

### User Story 4 — Quick long durations (P1)

**Acceptance Scenarios**

1. **Given** the past-session form with duration "Set", **Then** quick-pick options (15 min,
   30 min, 45 min, 1 h, 1 h 30, 2 h, 3 h, 4 h) set the duration in one tap.
2. **When** the user taps the duration value, **Then** an hours + minutes picker opens (hours
   0–24, minutes in steps of 5) so any value up to the maximum is reachable in a few gestures.
3. Fine adjustment with −/+ 5 min remains available.
4. Editing an existing activity shows its stored duration, including values that are not a
   multiple of 5.

### Edge Cases

- Deleting an exercise that is part of the workout in progress: the running workout keeps it;
  it disappears from the library for future use.
- Duration is never below 5 minutes nor above the 24 h maximum; picking 0 h 0 min is not
  possible (minimum 5 min).
- Restoring by name works for built-in exercises too (their built-in settings are kept).

## Requirements

### Functional Requirements

- **FR-001**: Any exercise (custom or built-in) can be deleted from the library after a
  confirmation.
- **FR-002**: Deletion is a soft delete: past workout history, sets and the exercise's own plan
  are kept; the exercise is hidden from the library, the picker, templates and Progress.
- **FR-003**: Deleted built-in exercises are not re-added by the library refresh on app start.
- **FR-004**: Deleting removes the exercise from all templates; templates left empty are deleted.
  The confirmation lists affected templates.
- **FR-005**: Creating an exercise with the name of a deleted one restores it.
- **FR-006**: The You tab row and library screen title read "Gym Exercise Library".
- **FR-007**: The `+` menu offers: Continue (if a session is in progress), every sport (live-GPS
  sports start tracking, others open the log form preselected), and "Log a past session". No gym
  or template rows, no "More sports".
- **FR-008**: The duration input offers one-tap presets, an hours/minutes picker and ±5 min
  steps, within 5 min – 24 h.

### Key Entities

- **Exercise**: gains a "deleted at" timestamp (null = active).

## Success Criteria

- **SC-001**: Entering a 4-hour duration takes at most 1 tap after choosing "Set" (was 46 taps).
- **SC-002**: Any duration up to 24 h is reachable in at most 3 interactions.
- **SC-003**: Every sport is reachable from `+` in one tap (was two for non-GPS sports).
- **SC-004**: Deleting an exercise never removes any finished workout or set.

## Assumptions

- No undo snackbar; the confirmation dialog plus restore-by-name cover mistakes.
- The `+` hub keeps "Continue" because it resumes rather than starts a session.
