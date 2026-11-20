# Implementation Plan: Workout Template Fixes

**Branch**: `023-workout-template-fixes` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Four fixes in the gym workout: carry exercise notes into template workouts, drop the per-exercise
"Add Set" button for template-plan exercises, make exercise notes save and unfocus on their own, and
open a live workout at the current exercise. No schema, dependency or sync change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)

**New dependencies**: none

**Storage**: drift (unchanged schema). Notes already live in `workout_exercises.notes`; template
sessions already store `templateExerciseId`.

**Testing**: domain test for the resume rule first; data test for note carry-over first; widget
tests for Add Set, notes and resume scroll.

## Research (Phase 0)

- **Which note carries over** — Decision: the latest non-empty note of a finished session with the
  same `templateExerciseId`, ordered by workout `startedAt` desc. Rationale: the template-exercise
  id is stable across rename, reorder and plan edits (`_writeExercises` keeps kept rows) and scopes
  notes to "that template". Alternatives: match by exercise id (would leak ad-hoc and other
  template notes, rejected by FR-002); latest session even when empty (loses notes from sessions
  logged before this feature, against "always persist").
- **Where to hide Add Set** — Decision: `planSource == PlanSourceKind.template`. Rationale: those
  exercises always have "Edit plan" to change target sets. Orphaned template exercises have no plan
  and no Edit plan, so hiding Add Set would leave them with no rows to log; ad-hoc keeps its
  behaviour.
- **Notes auto-save** — Decision: debounce 600 ms on change, plus save on `onSubmitted`
  (`TextInputAction.done`), `onTapOutside` (unfocus) and `dispose`. A single `_save` skips when the
  text equals the last saved value. Rationale: Flutter built-ins only; matches "Changes save
  automatically" used in edit mode. Alternative: explicit Save button (adds a tap, against V).
- **Resume scroll** — Decision: pure rule `resumeExerciseIndex` in `lib/domain/`; the live workout
  body becomes a `SingleChildScrollView` + `Column` so every card has a laid-out `GlobalKey`, and
  `Scrollable.ensureVisible` runs once in a post-frame callback on the first data build. Rationale:
  a lazily built `ListView` has no element for cards far below the viewport; a workout holds ~4–12
  cards, so building all is cheap. Alternative: persisting a scroll offset (breaks when card heights
  change, extra storage).

## Design (Phase 1)

1. **Notes carry-over** — `TemplateRepository.startWorkout`: for each template item, look up
   `_lastNote(item.id)` (join `workout_exercises` × `workouts`, `templateExerciseId = item.id`,
   `endedAt` not null, notes not null, newest `startedAt` first, first with `trim().isNotEmpty`) and
   insert it as `notes`. Same transaction.
2. **Add Set** — `ExerciseCard`: show the Add Set button only when
   `d.planSource != PlanSourceKind.template`; the TargetHitPill row stays.
3. **Notes field** — `_NotesField` in `exercise_card.dart`: `Timer` debounce, `textInputAction:
   done`, `onSubmitted` → save + unfocus, `onTapOutside` → unfocus (focus listener saves), save in
   `dispose` (repository read before `super.dispose`), track `_saved` text.
4. **Resume** — `lib/domain/workout_progress.dart`:
   `ExerciseProgress({required Set<int> loggedSetNos, int? plannedSets})`,
   `int? resumeExerciseIndex(List<ExerciseProgress>)`:
   last index with any logged set → if complete (`plannedSets > 0` and 1..plannedSets all logged)
   and not last → index + 1; else that index; none → null.
   `workout_screen.dart`: `_WorkoutBodyState` owns `ScrollController`, per-exercise `GlobalKey`s and
   `_autoScrolled`; for a live workout on its first data build, computes the index and calls
   `Scrollable.ensureVisible(alignment: 0)` after the frame. Finished workouts never scroll.

### Data model

No change. `workout_exercises.notes` is now pre-filled at template start (see Research).

### Contracts

UI only: no external interface changes.

### Quickstart (validation)

1. `flutter test test/domain/workout_progress_test.dart test/data/template_repository_test.dart`
2. `flutter test test/features/workout_screen_test.dart test/features/template_progression_ui_test.dart`
3. On device: start a template, add a note, finish; start again → note shown. Template exercise has
   no Add Set. Type a note, tap Done → keyboard closes, no cursor. Log exercises 1–2 fully, kill the
   app, reopen, Continue workout → exercise 3 is at the top of the screen.

## Constitution Check

- II: resume rule is pure Dart in `lib/domain/` with tests first. Progression untouched.
- III: failing domain and data tests before code; format, analyze, test gates at the end.
- IV: repository owns the note copy; widgets only call providers; theme tokens only.
- V: notes need no extra tap; no layout jump after a tap (scroll happens only on open).
- VI, VII: no new data leaves the device; no scope growth.

Pass (pre- and post-design).
