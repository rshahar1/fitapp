---
description: "Task list for workout flow fixes, exercise library and history calendar"
---

# Tasks: Workout Flow Fixes, Exercise Library and History Calendar

**Input**: `/specs/007-workout-flow-library/` (spec, plan, data-model)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Foundational (domain + data, tests first)

- [x] T001 Domain tests first: `shiftToDay` (keeps local time, same day no-op), `liveDuration`; calendar `monthGrid` (Monday start, leading/trailing days, 4–6 weeks), `weekDays`, `dayKey` — test/domain/workout_dates_test.dart, test/domain/calendar_test.dart
- [x] T002 Implement lib/domain/workout_dates.dart and lib/domain/calendar.dart
- [x] T003 Repository tests first — test/data/workout_flow_test.dart: start writes live record; resume any finished workout when none live; resumed duration = prior + live; finish applies chosen day; backdated older session never rewrites base; newest backdated session may progress; setWorkoutDay shifts both timestamps without base change; discard/finish/delete clear the record
- [x] T004 Live-session store + WorkoutRepository/TemplateRepository changes + `liveSessionProvider`
- [x] T005 Exercise repository tests first (create with category, invalid category rejected, updateCustom rename/duplicate/case-only rename, built-in update rejected) then implement — test/data/exercise_repository_test.dart, lib/data/repositories/exercise_repository.dart

## Phase 2: US1 + US2 + US5 — workout screen (P1/P2)

- [x] T006 [US2] Live workout menu "Discard workout" with confirmation (stronger copy for resumed workouts) in lib/features/workout/workout_screen.dart
- [x] T007 [US1] Resume on finish summary (lib/features/workout/widgets/finish_summary_sheet.dart) and on the finished screen for any finished workout
- [x] T008 [US5] Date row on live and finished workout screens; live duration uses the live session; Train "Started … ago" uses it
- [x] T009 Widget tests in test/features/workout_flow_ui_test.dart

## Phase 3: US3 + US4 — exercise library (P1/P2)

- [x] T010 [US4] Category selector + edit mode in lib/features/exercises/custom_exercise_sheet.dart
- [x] T011 [US3] lib/features/exercises/exercise_library_screen.dart, route `/exercises`, entry from Train and Progress, Edit action on exercise detail for custom exercises
- [x] T012 Widget tests in test/features/exercise_library_test.dart

## Phase 4: US6 — history calendar (P2)

- [x] T013 [US6] lib/features/history/history_calendar.dart (Month/Week, arrows, month/year picker, Today, day icons + "+N", day list) and List/Calendar switch in history_screen.dart
- [x] T014 Widget tests in test/features/history_calendar_test.dart

## Phase 5: Polish

- [x] T015 README / PRD / ARCHITECTURE / constitution notes; CLAUDE.md active feature
- [x] T016 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` green; commit
