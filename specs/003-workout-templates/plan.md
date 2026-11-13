# Implementation Plan: Workout Templates

**Branch**: `003-workout-templates` | **Date**: 2026-11-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-workout-templates/spec.md`

## Summary

User-created templates (name + ordered exercises) stored in two new local tables (schema v2), a
`TemplateRepository` with transactional create/update/delete/save-from-workout/start-workout, a
Templates section on the Train tab with one-tap START, a template editor with drag-to-reorder, and
"Save as template" on the workout screen. Plans and progression are untouched: a template-started
workout is built from the same rows as a manual one.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50

**Primary Dependencies**: existing (drift, Riverpod 3, go_router); no new packages

**Storage**: drift schema v2 (+2 tables) — [data-model.md](./data-model.md)

**Testing**: repository tests on in-memory DB; drift schema migration test v1→v2; widget tests for
Train templates section, editor and save-as-template

**Target Platform**: Android (iOS later) | **Project Type**: mobile-app

**Performance Goals**: START → live workout visible < 300 ms with 10 exercises

**Constraints**: offline; one transaction per write; migration never drops data

**Scale/Scope**: tens of templates, ≤ 20 exercises each

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline-first, UUIDs, `updated_at`/`dirty`, versioned migration, transactions | ✅ |
| II. Pure domain untouched (no new progression logic) | ✅ |
| III. Tests first (repository + migration tests before UI) | ✅ |
| IV. Layering (widgets → providers → TemplateRepository) | ✅ |
| V. UX: one-tap start, 48 dp, confirmations for delete, semantics | ✅ |
| VI. No secrets/trackers | ✅ |
| VII. Scope: PRD §14 listed routines as LATER — now explicitly requested by the owner (2026-11-13); built-in routines and folders stay out | ✅ (owner decision recorded) |

## Project Structure

```text
specs/003-workout-templates/  spec, plan, research, data-model, contracts/templates.md, quickstart, tasks
lib/data/db/tables.dart                      # + Templates, TemplateExercises
lib/data/db/app_database.dart                # schemaVersion 2, onUpgrade, name index
drift_schemas/fitapp/drift_schema_v{1,2}.json
lib/data/models.dart                         # + TemplateSummary
lib/data/repositories/template_repository.dart
lib/data/providers.dart                      # + templateRepositoryProvider, templatesProvider
lib/features/templates/template_editor_screen.dart
lib/features/train/train_screen.dart         # + Templates section
lib/features/exercises/exercise_picker_screen.dart   # + selection mode
lib/features/workout/workout_screen.dart     # + ⋮ Save as template
lib/app/router.dart                          # + /template/new, /template/:id, /pick-exercise
test/data/template_repository_test.dart  test/data/migration_test.dart  test/features/templates_test.dart
```

## Complexity Tracking

None.
