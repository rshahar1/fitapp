---
description: "Task list for Progress chart on Sunday weeks"
---

# Tasks: Progress Chart on Sunday Weeks

**Input**: `/specs/026-progress-sunday-weeks/` (spec, plan)

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature — specs/026-progress-sunday-weeks/, CLAUDE.md

## Phase 2: Domain (US1, US2) — tests first

- [x] T002 [US1] Sunday-week tests, then `workoutsPerWeek` keyed by Sunday; remove ISO helpers and
  their tests — test/domain/stats_test.dart, lib/domain/stats.dart
- [x] T003 [US2] Label tests, then `weekBarLabels` — test/domain/stats_test.dart, lib/domain/stats.dart

## Phase 3: Data and UI

- [x] T004 [US1] Provider and repository types; repository tests — lib/data/providers.dart,
  lib/data/repositories/workout_repository.dart, test/data/
- [x] T005 [US2] Chart takes `Map<DateTime, int>`, new labels and semantics; widget test —
  lib/widgets/weekly_bar_chart.dart

## Phase 4: Docs

- [x] T006 PRD §5.5, §5.6, test list, decision log, changelog 2.12 — docs/PRD-fitapp-flutter.md
