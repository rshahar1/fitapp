---
description: "Task list for templates that carry their own progression"
---

# Tasks: Templates That Carry Their Own Progression

**Input**: `/specs/005-template-progression/` (plan, spec, research, data-model, contracts/plan-source.md, quickstart)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [x] T001 Confirm the v2 schema dump exists in drift_schemas/fitapp/drift_schema_v2.json (no table change yet)

## Phase 2: Foundational — rule change (US1, P1)

- [x] T002 [US1] Rewrite evaluate tests first for the new rule (overload set ignored, missing set 3 progresses, heavier overload → base + inc, 2-set plan, incomplete before missed reps, `isLatestSessionForPlan`) in test/domain/progression_test.dart
- [x] T003 [US1] Implement the rule, trim `EvalReason`, rename the `canRewriteBase` flag in lib/domain/progression.dart; 100% line coverage
- [x] T004 [US1] Update repository/feature tests whose expectations relied on the overload weight (test/data/workout_repository_test.dart, test/data/workout_history_test.dart, test/features/*) and PRD §11 scenarios

## Phase 3: Foundational — schema v3

- [x] T005 Add plan columns to `TemplateExercises` and `templateExerciseId` to `WorkoutExercises` in lib/data/db/tables.dart; schemaVersion 3 with onUpgrade (add columns, seed from exercise_state, index) in lib/data/db/app_database.dart; regenerate code; `dart run drift_dev make-migrations` → drift_schemas/fitapp/drift_schema_v3.json + test/drift/fitapp/generated/schema_v3.dart
- [x] T006 Migration test v2→v3 keeps workouts/sets/templates and seeds template plans from exercise plans (exercise without plan → NULL) in test/drift/fitapp/migration_test.dart

## Phase 4: User Story 2 + 4 — per-template plans in data (P1)

- [x] T007 [US2] Models `StoredPlan`, `PlanSourceKind`, `WorkoutExerciseDetail.planSource`, `TemplateSummary.plans` in lib/data/models.dart
- [x] T008 [US2] Tests first in test/data/template_progression_test.dart: seeding on create/update/saveFromWorkout, startWorkout links, finish progresses only the template plan (exercise plan and other template unchanged), ad-hoc exercise in a template workout uses the exercise plan, savePlan by source, plan setup for a template exercise without plan, orphan after template delete never rewrites, live workout unlinked on delete
- [x] T009 [US4] Tests first in test/data/template_progression_test.dart: PRD §11 scenarios 4–8 on a template plan, with no cross-effect on the exercise plan
- [x] T010 [US2] Implement plan sources in lib/data/repositories/workout_repository.dart (finish, recalc, undo, latest-session per source, savePlan, workoutDetail)
- [x] T011 [US2] Implement template plan seeding/editing/linking/unlinking in lib/data/repositories/template_repository.dart

## Phase 5: User Story 2 — live workout UI (P1)

- [x] T012 [US2] `PlanForm` takes `StoredPlan? initial` + `onSubmit`; `PlanSetupCard`/`showEditPlanSheet` callers save through `WorkoutRepository.savePlan` (live card) or `ExerciseRepository.savePlan` (exercise detail) in lib/features/workout/widgets/plan_form.dart, exercise_card.dart, lib/features/progress/exercise_detail_screen.dart; widget test that Edit plan on a template workout edits the template plan in test/features/template_progression_ui_test.dart

## Phase 6: User Story 3 — template editor plans (P2)

- [x] T013 [US3] Template editor rows show the plan summary or "No plan yet" and open a plan sheet editing the draft; new rows pre-fill from the exercise plan; Save passes `plans`; discard drops plan edits (dirty tracking includes plans) in lib/features/templates/template_editor_screen.dart; widget tests in test/features/template_editor_test.dart

## Phase 7: Polish

- [x] T014 Amend constitution (1.1.0, Sync Impact Report): II history safety per plan; IV TemplateRepository; VII routines no longer LATER in .specify/memory/constitution.md
- [x] T015 PRD §3, §4.2–4.4, §11, §15 decisions log, §17 changelog (v2.2) in docs/PRD-fitapp-flutter.md; README progression rule; docs/ARCHITECTURE.md plan sources
- [x] T016 Gates: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test -j 1`, coverage of lib/domain/progression.dart = 100%
- [ ] T017 On-phone validation per quickstart.md (owner)
