---
description: "Task list for Pilates and manual distance"
---

# Tasks: Pilates and Manual Distance

**Input**: `/specs/009-pilates-distance/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [x] T001 Confirm drift_schemas/fitapp/drift_schema_v4.json exists before the table change

## Phase 2: Foundational (domain + schema)

- [x] T002 Domain tests first in test/domain/activity_types_test.dart: five types in order with pilates last; `hasDistance` only for running and cycling; distance validation (1..1,000,000, rejected on non-distance known types, allowed with `allowUnknownType`); `parseDistanceKm` (`5.2`, `5,2`, `10`, `0.004`→null, `0`→null, `abc`→null, `1000.01`→null, rounding to 10 m); `formatDistanceKm`; `formatPace(5200, 28)` = `5:23 /km`; `formatSpeed(36750, 90)` = `24.5 km/h`
- [x] T003 Implement the registry change and helpers in lib/domain/activity_types.dart; Pilates icon in lib/features/activities/activity_icons.dart
- [x] T004 `distanceMeters` nullable column + schemaVersion 5 with `from4To5` (`addColumn`) in lib/data/db/tables.dart and lib/data/db/app_database.dart; regenerate; `dart run drift_dev make-migrations` → drift_schema_v5.json + test helpers
- [x] T005 Migration test v4→v5 keeps activities (distance null) in test/drift/fitapp/migration_test.dart

## Phase 3: User Story 1 + 2 — repository and sheet (P1)

- [x] T006 [US2] Repository tests first: create/update with distance, rejection on snowboarding, update clearing distance — test/data/activity_repository_test.dart
- [x] T007 [US2] `distanceMeters` on `ActivityRepository.create/update`
- [x] T008 [US1/US2] Sheet: Pilates chip; Distance None/Set + km TextField (decimal keyboard, `km` suffix, error text, Save disabled when invalid) only when the selected type has distance; edit pre-fills; type switch to a non-distance type saves null — lib/features/activities/activity_sheet.dart; widget tests in test/features/activities_test.dart

## Phase 4: History (P1)

- [x] T009 [US2] History activity subtitle `distance · duration · pace|speed · note` in lib/features/history/history_rows.dart; widget test in test/features/history_screen_test.dart

## Phase 5: Polish

- [x] T010 Constitution 1.3.0 (VII: manual distance for running/cycling in scope; live tracking still out); PRD v2.5; README; docs/ARCHITECTURE.md; CLAUDE.md active feature
- [x] T011 Gates: format, analyze, `flutter test -j 1`
- [ ] T012 On-phone validation (owner)
