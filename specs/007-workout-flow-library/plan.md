# Implementation Plan: Workout Flow Fixes, Exercise Library and History Calendar

**Branch**: `007-workout-flow-library` | **Date**: 2026-11-13 | **Spec**: [spec.md](spec.md)

## Summary

Six UX changes on top of the existing layers, **with no schema change**:

1. Resume: `canResume` allows any finished workout while none is live; the finish summary and the
   finished-workout screen offer Resume. A resumed workout keeps its earlier duration.
2. Discard: the live workout menu gets "Discard workout" (confirm) → existing `discardWorkout`.
3. + 4. Exercise library screen (`/exercises`) and a category selector in the create/edit sheet;
   `ExerciseRepository.createCustom(muscleGroup:)` and new `updateCustom`.
5. Workout date: a Date row on the workout screen. For a live workout the chosen day is kept in the
   local live-session record and applied on finish; for a finished workout `setWorkoutDay` shifts
   start and end by whole days. Finishing progresses a plan only when the workout is the newest
   session for that plan.
6. History calendar (Month / Week) built on a pure `lib/domain/calendar.dart`.

## Technical Context

Flutter stable, Dart 3, Riverpod 3, go_router, drift (schema v4, unchanged), Material 3 built-ins
(`showDatePicker`, `SegmentedButton`). No new packages.

## Key design: the live-session record

Settings key `live_workout` (JSON, device-local like the persisted rest timer):
`{workoutId, liveSince (UTC ISO), priorSeconds, day (yyyy-MM-dd or null)}`.

- Written by `WorkoutRepository.startWorkout`, `TemplateRepository.startWorkout` (priorSeconds 0)
  and `resumeWorkout` (priorSeconds = endedAt − startedAt).
- Cleared by finish, discard and delete of that workout.
- Finish (one transaction): `duration = priorSeconds + (now − liveSince)`;
  `startedAt' = shiftToDay(startedAt, day)` (pure, keeps local time of day);
  `endedAt = startedAt' + duration`. No record (legacy) → `endedAt = now`, start unchanged.
- Base weights: finish now marks the workout finished **first** and then rewrites a plan's base
  only when `_isLatestSession(source, workoutId)` and the current base equals the plan used
  (constitution II). Older backdated or resumed sessions therefore never move a newer base.
- `setWorkoutDay` on a finished workout shifts both timestamps by the day delta; it never rewrites
  any base.
- `watchLiveSession()` exposes the record so the UI shows the real elapsed time and chosen day.

## Constitution Check

- I Offline-first: all local; multi-row writes in transactions; no migration needed. PASS
- II Pure domain: `shiftToDay`, `liveDuration`, calendar grid in `lib/domain/` with tests first;
  `canRewriteBase` respected on resume/finish. PASS
- III Tests first: domain + repository tests before code; widget tests for each screen. PASS
- IV Layering: widgets use providers; writes via repositories; theme tokens only. PASS
- V UX: Discard confirms; 48 dp targets; Semantics labels on new controls. PASS
- VII Scope: no new categories, no exercise deletion, no time-of-day picker. PASS

## Project Structure (touched)

```text
lib/domain/workout_dates.dart        (new) shiftToDay, liveDuration
lib/domain/calendar.dart             (new) monthGrid, weekDays, dayKey
lib/data/repositories/live_session_store.dart (new) LiveSession + AppDatabase extension
lib/data/repositories/workout_repository.dart  resume/finish/discard/delete/setWorkoutDay/live
lib/data/repositories/template_repository.dart startWorkout writes the record
lib/data/repositories/exercise_repository.dart createCustom(muscleGroup), updateCustom
lib/data/providers.dart              liveSessionProvider
lib/features/workout/...             Date row, Discard menu, live duration, Resume on summary
lib/features/exercises/exercise_library_screen.dart (new), custom_exercise_sheet.dart (category, edit)
lib/features/history/history_calendar.dart (new), history_screen.dart (List/Calendar switch)
lib/app/router.dart                  /exercises
```
