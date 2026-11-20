---
description: "Task list for Train stats Sunday weeks and per-type breakdown"
---

# Tasks: Train Stats — Sunday Weeks and Per-Type Breakdown

**Input**: `/specs/025-train-stats-breakdown/` (spec, plan)

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature — specs/025-train-stats-breakdown/, CLAUDE.md

## Phase 2: Domain (US1, US2) — tests first

- [x] T002 [US1] Sunday-week streak tests, then `weeklyStreak` on `startOfWeek` —
  test/domain/stats_test.dart, lib/domain/stats.dart
- [x] T003 [US2] Breakdown tests, then `trainingBreakdown` — test/domain/training_breakdown_test.dart,
  lib/domain/training_breakdown.dart

## Phase 3: Data

- [x] T004 [US1][US2] `HomeStats` (`allTime`, `byType`), `homeStats` on Sunday weeks; repository
  tests — lib/data/models.dart, lib/data/repositories/workout_repository.dart, test/data/

## Phase 4: UI

- [x] T005 [US2] All time tile and By type section; widget test — lib/features/train/train_screen.dart,
  test/features/train_screen_test.dart

## Phase 5: Docs

- [x] T006 PRD §5.5 stats text and decision log — docs/PRD-fitapp-flutter.md
