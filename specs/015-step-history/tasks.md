---
description: "Task list for step totals in History"
---

# Tasks: Step totals in History, steps card below Templates

**Input**: `/specs/015-step-history/` (spec, plan). **Tests**: REQUIRED. `[P]` = parallel.

## Phase 1: Setup

- [x] T001 Constitution 1.7.0; spec, plan, tasks on branch `015-step-history`; `CLAUDE.md` active feature → 015

## Phase 2: Core (tests first)

- [x] T002 Tests: `stepWindow` (today → midnight..now; past day → full day; future → null; 31 days ago → null; 30 days ago → window; DST day), `formatSteps` (0, 1, 8432), `daySteps` (disabled/not granted/out of window → null without source call; granted → count) — test/core/step_source_test.dart, test/core/format_test.dart, test/data/step_providers_test.dart
- [x] T003 Implement `stepWindow`, `formatSteps`, `daySteps` until T002 passes
- [x] T004 Gate: format, analyze, test; commit

## Phase 3: UI

- [x] T005 [US1] Move `StepsCard` below Templates — lib/features/train/train_screen.dart; widget test asserts order (Templates header before "Steps today")
- [x] T006 [US2] Selected-day step total in calendar header, resume refresh — lib/features/history/history_calendar.dart; widget tests: shown with workouts, shown on a no-training day, "0 steps", hidden when off/not granted/future/out of window, no Icon in header, switches with selection
- [x] T007 Gate: format, analyze, test, `flutter build apk --debug`; commit; mark spec Implemented, README note
