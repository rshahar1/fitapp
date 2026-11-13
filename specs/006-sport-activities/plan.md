# Implementation Plan: Log Other Sport Activities

**Branch**: `006-sport-activities` | **Date**: 2026-11-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-sport-activities/spec.md`

## Summary

A pure-Dart activity type registry (`lib/domain/activity_types.dart`: stable id + label) with a UI
icon map (`lib/features/activities/activity_icons.dart`), a generic `activities` table (schema v4)
behind an `ActivityRepository` (create/update/delete with the delete queue), a Log activity sheet
opened from the Train tab and from History rows (edit/delete), a merged History list (workouts +
activities, icon per type, gym icon for workouts), and week stats (This week, streak, Progress
weekly bars) that include activity dates.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50

**Primary Dependencies**: existing (drift, Riverpod 3, go_router, material_ui); no new packages

**Storage**: drift schema v4 (+1 table) — [data-model.md](./data-model.md)

**Testing**: domain registry tests; repository tests (CRUD, validation, delete queue, stats);
migration test v3→v4; widget tests (log sheet from Train, History merged list + icons, edit/delete)

**Target Platform**: Android (iOS later) | **Project Type**: mobile-app

**Performance Goals**: sheet opens instantly; History renders < 300 ms with 500 entries

**Constraints**: offline; one transaction per multi-row write; migration never drops data

**Scale/Scope**: a few activities per week

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline-first, UUID, `updated_at`/`dirty`, delete queue, versioned migration | ✅ |
| II. Pure domain: registry + validation in `lib/domain/` with tests; stats helpers reused | ✅ |
| III. Tests first | ✅ |
| IV. Layering: widgets → providers → `ActivityRepository`; icons/colors from theme | ✅ (amend IV list of repositories) |
| V. UX: ≤ 3 taps, bottom sheet, delete confirmed, 48 dp, semantics | ✅ |
| VI. No secrets | ✅ |
| VII. Scope: owner request 2026-11-13; no sport-specific metrics | ✅ |

## Project Structure

```text
specs/006-sport-activities/          spec, plan, research, data-model, contracts/activities.md, quickstart, tasks
lib/domain/activity_types.dart       # ActivityType registry (id, label), lookup, validation limits
lib/data/db/tables.dart              # + Activities
lib/data/db/app_database.dart        # schemaVersion 4 (stepByStep from3To4)
drift_schemas/fitapp/drift_schema_v4.json
lib/data/models.dart                 # HistoryEntry (workout | activity)
lib/data/repositories/activity_repository.dart
lib/data/repositories/workout_repository.dart   # week stats include activity dates
lib/data/providers.dart              # activityRepositoryProvider, historyEntriesProvider
lib/features/activities/activity_icons.dart
lib/features/activities/activity_sheet.dart     # log / edit / delete sheet
lib/features/train/train_screen.dart            # Log activity action
lib/features/history/history_screen.dart        # merged list with icons
```
