# Tasks: Share Polish

## Phase 1: Foundational (domain, tests first)

- [x] T001 Tests for duration parts (`27 min`, `1h 3m`, `4h`) and `ShareStat` parts in `test/domain/share/share_card_test.dart`
- [x] T002 Tests for `shareListLayout` (fits base; grows; two columns; shrinks at max) and the uncapped exercise list in `test/domain/share/share_card_test.dart`
- [x] T003 Implement parts, `durationShareStat`, `shareListLayout`, remove the cap in `lib/domain/share/share_card.dart`

## Phase 2: US1 + US2 – icon and overflow menu

- [x] T004 [US1] `Icons.adaptive.share` in `lib/features/share/share_preview_screen.dart` and `lib/features/workout/widgets/finish_summary_sheet.dart`
- [x] T005 [US2] `⋮` menu with Share in `lib/features/activities/activity_detail_screen.dart`
- [x] T006 [US2] Share item in the workout `⋮` menu, app-bar icon removed, in `lib/features/workout/workout_screen.dart`

## Phase 3: US3 + US4 – card layout

- [x] T007 [US3] Tokens in `lib/app/theme/tokens.dart`
- [x] T008 [US3] Variable-height strength card, one/two-column list in `lib/features/share/share_card_view.dart`
- [x] T009 [US4] Uniform stat scaling and number/unit parts in `lib/features/share/share_card_view.dart`
- [x] T010 [US2/US3] Update `test/features/share_test.dart` (menus, 11/40 exercises, no "+N more")

## Phase 4: Polish

- [x] T011 [P] PRD v2.15 §5.11, changelog; CLAUDE.md active feature
- [x] T012 Render check of all card types; format, analyze, test; commit; merge
