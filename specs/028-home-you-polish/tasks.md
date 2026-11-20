---
description: "Task list for Home, Progress and You polish"
---

# Tasks: Home, Progress and You Polish

**Input**: `/specs/028-home-you-polish/` (spec, plan)

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature — specs/028-home-you-polish/, CLAUDE.md

## Phase 2: Domain — tests first

- [x] T002 [US2] `isSameMonth`, `activeTypes` tests then code — test/domain/training_breakdown_test.dart,
  lib/domain/training_breakdown.dart
- [x] T003 [US1] `displayWeight` tests then code — test/domain/stats_test.dart, lib/domain/stats.dart

## Phase 3: Data

- [x] T004 [US1] `currentWeight` on trained exercises + provider; repository tests —
  lib/data/repositories/exercise_repository.dart, lib/data/models.dart, lib/data/providers.dart,
  test/data/exercise_repository_test.dart
- [x] T005 [US2] `HomeStats.thisMonth`, mixed `recent`, drop `streak`; tests —
  lib/data/repositories/workout_repository.dart, test/data/home_stats_test.dart,
  test/data/activity_stats_test.dart

## Phase 4: UI

- [x] T006 [US1] Progress rows and detail tile use current weight — lib/features/progress/
- [x] T007 [US2] Home tiles, active By type, mixed Recent, no *New* — lib/features/train/train_screen.dart
- [x] T008 [P] [US3] Gym Templates screen, route, You row; widget test — lib/features/templates/templates_screen.dart,
  lib/app/router.dart, lib/features/you/you_screen.dart, test/features/

## Phase 5: Docs

- [x] T009 PRD §5.5, §5.6, §5.9, changelog 2.14 — docs/PRD-fitapp-flutter.md
