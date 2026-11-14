---
description: "Task list for library deletion, hub cleanup and duration input"
---

# Tasks: Library deletion, hub cleanup, faster duration input

**Input**: `/specs/012-library-hub-cleanup/` (spec, plan). **Tests**: REQUIRED. `[P]` = parallel.

## Phase 1: Setup

- [x] T001 Spec-kit documents on branch `012-library-hub-cleanup`; `CLAUDE.md` active feature → 012

## Phase 2: Foundational — data (tests first)

- [x] T002 Tests: delete custom/built-in hides from list + trained; history kept; seed keeps deleted; templates pruned, empty template deleted; restore by name; updateCustom on deleted throws — test/data/exercise_repository_test.dart
- [x] T003 Schema v7 `exercises.deleted_at`, `from6To7`, regenerate, make-migrations; migration test v6→v7
- [x] T004 Implement repository changes until T002 passes — lib/data/repositories/exercise_repository.dart, template_repository.dart
- [x] T005 Milestone gate: format, analyze, test; commit

## Phase 3: UI

- [x] T006 [US1] Library delete action + confirmation; title "Gym Exercise Library" — lib/features/exercises/exercise_library_screen.dart; tests in test/features/exercise_library_test.dart
- [x] T007 [P] [US2] You row label — lib/features/you/you_screen.dart
- [x] T008 [P] [US3] Hub: only Continue, all sports, Log a past session — lib/features/start/start_hub_sheet.dart; update test/features/start_hub_test.dart and other tests relying on hub Gym/template/More sports rows
- [x] T009 [P] [US4] `DurationPicker` widget + use in activity sheet — lib/widgets/duration_picker.dart, lib/features/activities/activity_sheet.dart; widget tests
- [x] T010 Milestone gate: format, analyze, test; commit
