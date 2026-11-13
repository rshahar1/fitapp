---
description: "Task list for workout templates"
---

# Tasks: Workout Templates

**Input**: `/specs/003-workout-templates/` (plan, spec, research, data-model, contracts/templates.md, quickstart)

**Tests**: REQUIRED (constitution III).

## Phase 1: Setup

- [ ] T001 Capture the v1 schema dump with `dart run drift_dev make-migrations` into drift_schemas/fitapp/drift_schema_v1.json (done before any table change)

## Phase 2: Foundational (schema v2)

- [ ] T002 Add `Templates` (`name` trimmed 1–40 chars, `created_at`, `last_used_at` NULL, `updated_at`, `dirty`) and `TemplateExercises` (`template_id` ON DELETE CASCADE, `exercise_id`, `position`, `UNIQUE(template_id, exercise_id)`) in lib/data/db/tables.dart; register them in lib/data/db/app_database.dart
- [ ] T003 Bump `schemaVersion` to 2 with `onUpgrade` (from < 2: create both tables and `templates_name_ci` unique index on lower(name)); also create the index in `onCreate`; regenerate code and run `dart run drift_dev make-migrations` to produce v2 dump and test helpers
- [ ] T004 Migration test v1→v2 keeps existing workouts/sets and creates empty template tables in test/data/migration_test.dart

## Phase 3: User Story 1+2 – Templates data (P1)

- [ ] T005 [US2] Repository tests: create (trim, 1–40, unique ignoring case → DuplicateTemplateName, ≥1 exercise, duplicates dropped), update (rename, reorder, add/remove, pending_deletes for removed rows), delete (cascade + pending delete, workouts untouched), ordering by last_used_at desc then created_at desc — in test/data/template_repository_test.dart
- [ ] T006 [US1] Repository tests: startWorkout creates a live workout with the template's exercises in order, sets last_used_at, refuses with StateError when a workout is active, skips missing exercises, and a §11 progression scenario on a template-started workout matches the manual result — in test/data/template_repository_test.dart
- [ ] T007 [US1] Implement TemplateRepository + TemplateSummary per contracts/templates.md in lib/data/repositories/template_repository.dart and lib/data/models.dart; providers `templateRepositoryProvider`, `templatesProvider` in lib/data/providers.dart

## Phase 4: User Story 1 – Start from Train tab (P1)

- [ ] T008 [US1] Templates section on the Train tab (cards with name, exercise names, START; New action; empty hint; in-progress dialog with Continue) in lib/features/train/train_screen.dart; widget tests in test/features/templates_test.dart

## Phase 5: User Story 2 – Template editor (P1)

- [ ] T009 [US2] Picker selection mode returning the exercise id (`/pick-exercise`) in lib/features/exercises/exercise_picker_screen.dart and lib/app/router.dart
- [ ] T010 [US2] Template editor screen (name field max 40, reorderable list with drag handles, remove, Add exercise, Save with validation messages, Delete with confirmation, discard-changes dialog) in lib/features/templates/template_editor_screen.dart; routes `/template/new`, `/template/:id`; widget tests in test/features/templates_test.dart

## Phase 6: User Story 3 – Save as template (P2)

- [ ] T011 [US3] `saveFromWorkout` tests (order, distinct, empty workout rejected) in test/data/template_repository_test.dart
- [ ] T012 [US3] Workout screen ⋮ menu "Save as template" with name dialog (prefilled "Workout <d MMM>") and SnackBar in lib/features/workout/workout_screen.dart; widget test in test/features/templates_test.dart

## Phase 7: Polish

- [ ] T013 Update README.md (templates, schema v2), docs/ARCHITECTURE.md (tables, sync order), PRD roadmap note in specs/001-fitapp-v1/tasks.md is unchanged
- [ ] T014 Format/analyze/test; build APK; owner validates quickstart V1–V8 on the phone

## Dependencies

T001 → T002–T004 → T005–T007 → (T008 ∥ T009→T010 ∥ T011→T012) → T013–T014.
