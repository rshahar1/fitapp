---
description: "Task list for the month-only History calendar"
---

# Tasks: History calendar shows the month view only

**Input**: `/specs/016-history-month-only/` (spec, plan). **Tests**: REQUIRED.

## Phase 1: Setup

- [x] T001 Spec, plan, tasks on branch `016-history-month-only`; `CLAUDE.md` active feature → 016

## Phase 2: UI

- [x] T002 [US1] Tests: month view by default, no "Week"/"Month" selector, no week tooltips; remove week-mode tests and `toMonth` — test/features/history_calendar_test.dart
- [x] T003 [US1] Remove week mode and the selector until T002 passes — lib/features/history/history_calendar.dart
- [x] T004 Gate: format, analyze, test; commit
