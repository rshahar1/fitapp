# Implementation Plan: Templates That Carry Their Own Progression

**Branch**: `005-template-progression` | **Date**: 2026-11-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-template-progression/spec.md`

## Summary

1. **Rule change (domain)**: `evaluate` progresses iff every working set 1..N−1 is logged at
   ≥ base with ≥ target reps; next base = `roundWeight(base + increment)`. `EvalReason` loses
   `noOverloadSet` / `overloadNotHeavier`. `canRewriteBase` is unchanged in logic; its flag is
   renamed `isLatestSessionForPlan`.
2. **Per-template plans (data)**: schema v3 adds nullable plan columns to `template_exercises`
   (seeded from `exercise_state` in the migration) and a nullable `template_exercise_id` on
   `workout_exercises` (no FK, so a deleted template leaves an "orphan" link that never rewrites any
   plan). `WorkoutRepository` resolves a **plan source** per workout exercise (exercise plan /
   template plan / orphan) and applies finish, edit, resume, delete and history-safety to that
   source. `TemplateRepository` seeds, stores and edits template plans.
3. **UI**: `PlanForm` becomes storage-agnostic (`onSubmit(StoredPlan)`); the live workout card
   edits/sets up the plan of its source; the template editor shows each exercise's plan and edits it
   in a bottom sheet as part of the draft.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50

**Primary Dependencies**: existing (drift, Riverpod 3, go_router); no new packages

**Storage**: drift schema v3 — [data-model.md](./data-model.md)

**Testing**: domain unit tests (100% coverage of `progression.dart`), repository scenario tests on
in-memory DB (PRD §11 for template and exercise plans, cross-isolation), drift migration test
v2→v3 with data, widget tests for the template editor plan rows and live card

**Target Platform**: Android (iOS later) | **Project Type**: mobile-app

**Performance Goals**: unchanged (set log < 100 ms; finish < 300 ms for 10 exercises)

**Constraints**: offline; one transaction per multi-row write; migration never drops data

**Scale/Scope**: tens of templates, ≤ 20 exercises each

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline-first, versioned data-preserving migration, transactions | ✅ v3 adds columns only; seeding in the same migration |
| II. Pure domain, 100% coverage, `canRewriteBase` for history | ✅ rule change lives in `lib/domain/progression.dart`, tests first; history safety now "per plan" → **amend II wording** (constitution 1.1.0) |
| III. Tests first | ✅ domain + repository + migration tests precede UI |
| IV. Layering; writes via repositories | ✅ (`TemplateRepository` added to the list in the amendment) |
| V. UX: one tap, sheets with steppers, confirmations | ✅ plan edit sheet reused |
| VI. No secrets | ✅ |
| VII. Scope | ✅ owner decision 2026-11-13; "routines" removed from the LATER list (they exist since 003) |

Post-design re-check: ✅ no violations; no Complexity Tracking entries.

## Project Structure

```text
specs/005-template-progression/   spec, plan, research, data-model, contracts/plan-source.md, quickstart, tasks
lib/domain/progression.dart                    # new evaluate rule, EvalReason trimmed
lib/data/db/tables.dart                        # template_exercises plan cols; workout_exercises.template_exercise_id
lib/data/db/app_database.dart                  # schemaVersion 3 + onUpgrade (add cols, seed, index)
drift_schemas/fitapp/drift_schema_v3.json      # make-migrations dump
lib/data/models.dart                           # StoredPlan, PlanSource, detail/summary fields
lib/data/repositories/workout_repository.dart  # plan-source aware finish/edit/resume/delete/savePlan
lib/data/repositories/template_repository.dart # seed/edit template plans; link on start; unlink on delete
lib/features/workout/widgets/plan_form.dart    # onSubmit(StoredPlan); setup card/edit sheet by source
lib/features/workout/widgets/exercise_card.dart
lib/features/templates/template_editor_screen.dart  # plan summary per row + edit sheet
lib/features/progress/exercise_detail_screen.dart   # PlanForm callback adapter
test/domain/progression_test.dart
test/data/template_progression_test.dart       # new: §11 per template, isolation, orphan
test/data/*.dart, test/features/*.dart         # updated for the rule
test/drift/fitapp/migration_test.dart          # v2→v3 data test
docs/PRD-fitapp-flutter.md, README.md, docs/ARCHITECTURE.md, .specify/memory/constitution.md
```

**Structure Decision**: existing feature-first layout; no new feature folder.
