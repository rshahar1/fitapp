---
description: "Task list for earlier run confirmation off a lift"
---

# Tasks: Earlier Run Confirmation Off a Lift

**Input**: `/specs/021-snow-run-confirm-drop/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature

## Phase 2: Tests first

- [x] T002 Fixture test "a run off a lift on a flat traverse shows within 40 s (021)"; fails with 49 > 40 before the change — test/domain/tracking/val_thorens_fixture_test.dart
- [x] T003 Reducer test "a lift dipping 5 m between towers stays one lift (021)" — test/domain/tracking/snow_reducer_test.dart

## Phase 3: Change

- [x] T004 `SnowTuning.runConfirmDrop` default 10 → 6 — lib/domain/tracking/snow_reducer.dart
- [x] T005 Totals identical on Val Thorens, `plainDay`, `longDay`; 019 "known limit" test still passes

## Phase 4: Polish

- [x] T006 Update 017 plan confirmation table and 019 Findings item 1
- [x] T007 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (906 green)
- [ ] T008 (owner) check on a real ski day: no false run splits a lift, runs show sooner
