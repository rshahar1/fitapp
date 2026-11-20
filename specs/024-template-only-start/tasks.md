---
description: "Task list for template-only gym start"
---

# Tasks: Template-Only Gym Start

**Input**: `/specs/024-template-only-start/` (spec, plan)

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature — specs/024-template-only-start/, CLAUDE.md

## Phase 2: Template-only start (US1, P1)

**Goal**: no empty gym start; hero only for Continue (FR-001..FR-003).
**Independent test**: idle Train shows no start button or "Ready to train?"; template START works.

- [x] T002 [US1] Update tests first: idle Train has no "Ready to train?" / "START GYM WORKOUT";
  remove the one-tap gym start test — test/features/train_screen_test.dart,
  test/features/start_hub_test.dart
- [x] T003 [US1] `startGym` → `startTemplate(context, templateId)` — lib/features/start/start_actions.dart
- [x] T004 [US1] Hero hidden when idle; Continue-only button; templates call `startTemplate` —
  lib/features/train/train_screen.dart
- [x] T005 [US1] E2E flow starts from a seeded template — test/e2e/workout_flow.dart
- [x] T006 PRD §5.5 hero text — docs/PRD-fitapp-flutter.md

## Phase 3: Polish

- [x] T007 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`; commit
