---
description: "Task list for the Start/Log hub (Option C, slice 1)"
---

# Tasks: Start/Log Hub (center "+" action)

**Input**: `/specs/011-start-hub/` (spec, plan, research, contracts/start-hub.md, quickstart)

**Tests**: REQUIRED (constitution II, III). `[P]` = parallel (different files).

## Phase 1: Setup

- [x] T001 Commit `docs/ux/unified-start-proposal.md` and the 011 spec-kit documents on branch `011-start-hub`; `CLAUDE.md` active feature → 011

## Phase 2: Foundational — domain and data (tests first)

- [ ] T002 Tests: `sessionInProgress` (none, gym, tracking, both → tracking), labels (`Workout`, sport label, unknown → `Activity`), `continueLabel`, `blockedMessage`, equality — test/domain/start_guard_test.dart
- [ ] T003 Implement lib/domain/start_guard.dart (pure Dart) until T002 passes
- [ ] T004 Test: `TemplateRepository.startWorkout` throws while a tracking session exists — test/data/template_repository_test.dart
- [ ] T005 Add the tracking check to lib/data/repositories/template_repository.dart until T004 passes
- [ ] T006 Start service: `startActionsProvider`, `sessionInProgressProvider`, `current()`, `startGym({templateId})`, `startTracking(typeId)`, `open(session)`, blocked snackbar with Open — lib/features/start/start_actions.dart
- [ ] T007 Milestone gate: format, analyze, test; commit

## Phase 3: User Stories 1, 3, 4, 5 — hub (P1/P2)

- [ ] T008 Hub sheet: `showStartHub`, `HubChoice`, sections START NOW / EARLIER, Continue row, Gym, live sports, More sports (expand), templates, Log a past session — lib/features/start/start_hub_sheet.dart
- [ ] T009 [P] You screen (Exercise library, Settings rows) — lib/features/you/you_screen.dart
- [ ] T010 Router: `/you` branch (4th) — lib/app/router.dart
- [ ] T011 Shell: custom 5-slot bar with `[+]` action ("Start or log a session", 56 dp) — lib/features/shell/shell_scaffold.dart
- [ ] T012 [P] Activity sheet: remove Start live and "or log it manually below"; new-entry title "Log a past session" — lib/features/activities/activity_sheet.dart

## Phase 4: User Stories 2, 3, 6 — Train (P1/P3)

- [ ] T013 Train: header icons and Log activity removed; hero "Start gym workout" via start service; GPS state merged into hero (ticking time · km, Continue <sport>); template START via start service (dialog removed); `_TrackingBanner` removed — lib/features/train/train_screen.dart

## Phase 5: Tests

- [ ] T014 Widget tests with the real router — test/features/start_hub_test.dart: hub opens from every tab and keeps the tab selected; gym 1 tap from Train; template 1 tap from Train; + → Running routes to `/track/new?type=running`; + → Gym blocked while tracking (no workout created, message + Open); + → Running blocked while a gym workout is active; template START blocked while tracking; Continue row for gym and tracking; More sports → Pilates opens the form with Pilates; Log a past session form has no Start live; You → Settings / Exercise library
- [ ] T015 Update existing tests for removed UI: train_screen_test, activities_test, templates_test, workout_flow_ui_test, tracking/tracking_ui_test (Start live tests → hub; banner → hero), e2e/gps_flow.dart, e2e/workout_flow.dart
- [ ] T016 Milestone gate: format, analyze, test; commit

## Phase 6: Polish and docs

- [ ] T017 [P] PRD: §6 navigation (5-slot bar, hub, You, `/you`), version 2.7 + changelog — docs/PRD-fitapp-flutter.md
- [ ] T018 [P] Route contract: bottom bar, `/you`, hub, Train tab — specs/001-fitapp-v1/contracts/ui-routes.md
- [ ] T019 Mark tasks done; final gate; commit

## Dependencies

T002→T003; T004→T005; T003,T005→T006→T008→T011; T010 needs T009; T013 needs T006;
T014 needs T008–T013; T015 needs T012–T013. T009, T012, T017, T018 can run in parallel.
