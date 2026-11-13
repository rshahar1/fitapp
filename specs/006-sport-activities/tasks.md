---
description: "Task list for logging other sport activities"
---

# Tasks: Log Other Sport Activities

**Input**: `/specs/006-sport-activities/` (plan, spec, research, data-model, contracts/activities.md, quickstart)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [ ] T001 Confirm drift_schemas/fitapp/drift_schema_v3.json exists before any table change

## Phase 2: Foundational

- [ ] T002 Registry tests first (four types in order, stable ids, lookup, unknown id → null, validation limits for duration 1–1440 and note ≤ 200) in test/domain/activity_types_test.dart
- [ ] T003 Implement `ActivityType` registry and `validateActivity` in lib/domain/activity_types.dart
- [ ] T004 `Activities` table (id, type_id, started_at, duration_minutes?, notes?, updated_at, dirty) + schemaVersion 4 with stepByStep `from3To4` and index on started_at in lib/data/db/tables.dart and lib/data/db/app_database.dart; regenerate; `dart run drift_dev make-migrations` → drift_schema_v4.json + test helpers
- [ ] T005 Migration test v3→v4 keeps workouts, templates and plans and creates an empty activities table in test/drift/fitapp/migration_test.dart

## Phase 3: User Story 1 — log an activity (P1)

- [ ] T006 [US1] Repository tests first: create (validation, trimming, UUID, dirty), update, delete (pending_deletes), list newest first, future dates rejected — test/data/activity_repository_test.dart
- [ ] T007 [US1] `ActivityRepository` + providers in lib/data/repositories/activity_repository.dart and lib/data/providers.dart
- [ ] T008 [US1] Activity sheet (type chips with icons, date picker defaulting to today, optional duration stepper, optional note, Save; edit mode with Delete + confirmation) in lib/features/activities/activity_sheet.dart and icon map lib/features/activities/activity_icons.dart
- [ ] T009 [US1] Train tab "Log activity" action in lib/features/train/train_screen.dart; widget test in test/features/activities_test.dart

## Phase 4: User Story 2 — history and stats (P1)

- [ ] T010 [US2] Stats tests first: This week / streak / weekly bars include activity dates; Total excludes them — test/data/activity_stats_test.dart
- [ ] T011 [US2] Include activity dates in `homeStats` and `watchWorkoutsPerWeek` in lib/data/repositories/workout_repository.dart
- [ ] T012 [US2] `HistoryEntry` model + merged `historyEntriesProvider`; History rows with leading icon (gym icon for workouts, type icon for activities; empty state only when both are empty) in lib/data/models.dart, lib/data/providers.dart, lib/features/history/history_screen.dart; widget tests in test/features/history_screen_test.dart

## Phase 5: User Story 3 — edit/delete (P2)

- [ ] T013 [US3] Tapping an activity in History opens the sheet pre-filled; Save updates; Delete asks to confirm — widget tests in test/features/activities_test.dart

## Phase 6: Polish

- [ ] T014 Constitution 1.2.0 (IV lists ActivityRepository; VII: activities in scope, no sport metrics); PRD v2.3 (§3, §5.4 History, §5.5 Train, §5.6 Progress, §7, §15, §17); README; docs/ARCHITECTURE.md
- [ ] T015 Gates: format, analyze, `flutter test -j 1`
- [ ] T016 On-phone validation per quickstart.md (owner)
