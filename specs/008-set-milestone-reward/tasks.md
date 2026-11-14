---
description: "Task list for the set milestone reward animation"
---

# Tasks: Set Milestone Reward Animation

**Input**: `/specs/008-set-milestone-reward/` (spec, plan; no data-model, no schema change)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Foundational (domain, tests first)

- [x] T001 Domain tests first: `firstTwoSetsHitTarget` true at/above target, false below, false when targetReps/set1/set2 is null, uses only sets 1-2 — test/domain/milestones_test.dart
- [x] T002 Implement `firstTwoSetsHitTarget` in lib/domain/milestones.dart (pure Dart)
- [x] T003 Add color tokens accentBright #2BE07F, mint #7CF5B0, gold #FFD60A, rewardIconFill #14261C, rewardScrim (65 % black) in lib/app/theme/tokens.dart

## Phase 2: US1 — burst and pill (P1)

- [x] T004 [US1] Widget tests first in test/features/set_milestone_reward_test.dart: burst on live false→true; no burst on open, in edit mode, or with reduced motion; pill whenever rule holds; pill hides and burst replays after clear and re-achieve; taps pass through the overlay; overlay removed on dispose; one burst at a time; Semantics live-region label
- [x] T005 [US1] Figure painter (double-biceps line art, glow, pumps, strain lines) in lib/features/workout/widgets/reward/muscle_figure.dart
- [x] T006 [US1] Burst overlay (OverlayEntry + IgnorePointer, scrim, 3 s timeline, fireworks with side bursts, haptic, single-instance guard) in lib/features/workout/widgets/reward/reward_burst.dart
- [x] T007 [US1] Target pill in lib/features/workout/widgets/reward/target_hit_pill.dart
- [x] T008 [US1] Wire transition detection, overlay and pill into lib/features/workout/widgets/exercise_card.dart (live only, no layout shift)

## Phase 3: Polish

- [x] T009 Docs: README / PRD / ARCHITECTURE notes if they list workout UI behavior; keep CLAUDE.md active feature current
- [x] T010 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` green; commit
