# Feature Specification: Read-only workout history & rest between exercises

**Feature Branch**: `020-history-readonly-rest`
**Created**: 2026-11-17
**Status**: Implemented
**Input**: "Opening a strength workout from History defaults to Edit Mode; default it to read-only like
cycling/running, with Edit and Delete in the top-right. Change the rest timer between different
exercises from 1 minute to 2 minutes and make it a saved global setting."

## User Scenarios & Testing

### User Story 1 - Review a past strength workout (Priority: P1)

Opening a finished strength workout from History shows its full summary (duration, volume, sets,
date, every exercise with its sets, notes and the "compared to previous" card) read-only. Edit and
Delete icons sit in the app bar's top-right, like the activity detail screen.

**Acceptance Scenarios**:
1. **Given** a finished workout, **When** it is opened from History, **Then** no set, note, date,
   plan or exercise can be changed and no "Add Exercise"/"Add Set" controls are shown.
2. **Given** the read-only view, **When** Edit is tapped, **Then** the existing edit mode appears
   (auto-saving, as before) and the Edit icon becomes "Done editing", which returns to read-only.
3. **Given** either mode, **When** Delete is tapped and confirmed, **Then** the workout is deleted
   (same confirmation and weight roll-back as before).
4. The live workout screen is unchanged.
5. **(Amended 2026-11-17)** A finished workout has no bottom bar: no Done, Resume or Delete buttons
   there. Back leaves the screen; "Resume workout" is in the app bar's options menu (shown only
   when resuming is possible), next to "Save as template".

### User Story 2 - Longer rest before the next exercise (Priority: P1)

**Acceptance Scenarios**:
1. **Given** a live workout, **When** the last planned set of an exercise is logged (all planned
   sets done), **Then** the rest timer starts with the "rest between exercises" time (default 2:00).
2. **When** any other set is logged, **Then** the timer uses the exercise's own rest time or the
   default rest time (default 1:00), as before.
3. **Given** Settings › Rest timer, **When** "Rest between exercises" is changed (10 s–10 min, 5 s
   steps), **Then** it is saved, synced with the other rest settings, and used for the next
   exercise change.

## Requirements
- **FR-001**: Finished workouts open read-only; edit mode only after tapping Edit.
- **FR-002**: Edit and Delete actions in the app bar top-right; finished workouts have no bottom
  bar (Resume moves to the options menu, Done is replaced by back).
- **FR-003**: New setting `rest_between_exercises_seconds`, default 120, same bounds/steps as the
  default rest; part of the synced settings whitelist and wiped with the other rest settings.
- **FR-004**: Logging the set that completes an exercise's planned sets starts the between-exercises
  rest; exercises without a plan keep the per-set rest.
