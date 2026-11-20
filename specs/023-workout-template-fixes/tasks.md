---
description: "Task list for workout template fixes"
---

# Tasks: Workout Template Fixes

**Input**: `/specs/023-workout-template-fixes/` (spec, plan)

**Tests**: REQUIRED (constitution II, III): domain and data tests are written first and fail.

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature — specs/023-workout-template-fixes/, CLAUDE.md

## Phase 2: Foundational

None: the four stories touch separate code paths.

## Phase 3: Notes carry over (US1, P1)

**Goal**: a template start pre-fills each exercise's latest earlier note (FR-001, FR-002).
**Independent test**: template note written, finished, template started again → note shown.

- [x] T002 [US1] Failing tests: latest non-empty note of the same template exercise carried over;
  empty/blank notes skipped; ad-hoc and other-template notes ignored; live (unfinished) workouts
  ignored; editing the new note leaves the old one — test/data/template_repository_test.dart
- [x] T003 [US1] `_lastNote(templateExerciseId)` and `notes: Value(...)` in `startWorkout` —
  lib/data/repositories/template_repository.dart

## Phase 4: Continue where you left off (US4, P1)

**Goal**: a live workout opens at the current exercise (FR-006, FR-007).
**Independent test**: exercises 1–3 complete, reopen → exercise 4 visible at the top.

- [x] T004 [P] [US4] Failing tests for `resumeExerciseIndex`: none logged → null; partial last →
  that index; complete with next → next; complete and last → itself; no plan → itself; gaps before
  the last logged exercise ignored — test/domain/workout_progress_test.dart
- [x] T005 [US4] `ExerciseProgress`, `resumeExerciseIndex` (pure Dart) —
  lib/domain/workout_progress.dart
- [x] T006 [US4] Scroll controller, per-card keys, one-time `ensureVisible` for live workouts;
  `SingleChildScrollView` + `Column` body — lib/features/workout/workout_screen.dart
- [x] T007 [US4] Widget tests: live workout with progress opens scrolled to the current card;
  no progress and finished workouts stay at the top — test/features/workout_screen_test.dart

## Phase 5: One set-count control (US2, P2)

**Goal**: no "Add Set" on template-plan exercises (FR-003).

- [x] T008 [P] [US2] Hide Add Set when `planSource == PlanSourceKind.template` —
  lib/features/workout/widgets/exercise_card.dart
- [x] T009 [US2] Widget tests: template exercise has no Add Set, ad-hoc and template-deleted-mid-session (unlinked to ad-hoc) keep it; Edit
  plan target sets changes the rows — test/features/template_progression_ui_test.dart

## Phase 6: Notes save on their own (US3, P2)

**Goal**: notes auto-save and leave edit state (FR-004, FR-005).

- [x] T010 [US3] `_NotesField`: 600 ms debounce save, Done → save + unfocus, tap outside →
  unfocus, save on dispose — lib/features/workout/widgets/exercise_card.dart
- [x] T011 [US3] Widget tests: typing saves after the debounce; Done unfocuses and saves; clearing
  stores null; leaving the screen while typing saves — test/features/exercise_notes_test.dart

## Phase 7: Polish

- [x] T012 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`; spec status;
  commit (940 green)

## Dependencies

- T002 → T003; T004 → T005 → T006 → T007; T008 → T009; T010 → T011 (T008 and T010 share
  exercise_card.dart: one writer at a time).
- US1, US4 and US2+US3 are independent of each other and can run in parallel (different files).

## Parallel example

- Writer A: T002–T003 (template repository). Writer B: T004–T007 (domain + workout screen).
  Writer C: T008–T011 (exercise card).

## Implementation strategy

MVP is US1 + US4 (P1). US2 and US3 are small UI follow-ons; all four ship together in this branch.
