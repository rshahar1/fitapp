---
description: "Task list for home and history polish"
---

# Tasks: Home and History Polish

**Input**: `/specs/022-home-history-polish/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature

## Phase 2: Sunday weeks (US3, tests first)

- [x] T002 Calendar tests expect Sunday-first weeks — test/domain/calendar_test.dart
- [x] T003 `startOfWeek` Sunday; doc comments — lib/domain/calendar.dart
- [x] T004 Calendar widget test: header starts with Sun — test/features/history_calendar_test.dart

## Phase 3: Live style (US1)

- [x] T005 [P] `AppColors.live`, `liveSoft`; `AppButtonVariant.live` — tokens.dart, app_button.dart
- [x] T006 `_HeroCard` live border, LIVE pill, live Continue button with play icon — train_screen.dart
- [x] T007 Widget test: Start is primary, Continue is live with LIVE pill — test/features/train_screen_test.dart

## Phase 4: Functional emoji (US2)

- [x] T008 [P] `ActivityIcon` widget; use in start hub, activity sheet, history rows, calendar — lib/features/…
- [x] T009 Widget test: functional shows 🏋️ — test/features/start_hub_test.dart

## Phase 5: Steps → calendar (US4)

- [x] T010 [P] `historyViewProvider`; History reads it — history_screen.dart
- [x] T011 Steps card tappable, opens History calendar — steps_card.dart
- [x] T012 Widget test — test/features/train/steps_card_test.dart, test/features/history_screen_test.dart

## Phase 6: Polish

- [x] T013 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` (914 green)
- [x] T015 Functional emoji painted as a silhouette in the icon colour (owner feedback) — activity_icons.dart, start_hub_test.dart
- [ ] T014 (owner) check on a device
