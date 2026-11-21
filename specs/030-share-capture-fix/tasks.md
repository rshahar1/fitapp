# Tasks: Share Capture Fix

- [x] T001 Tests for `isBlankImage` in `test/domain/share/image_check_test.dart`
- [x] T002 Tests for `shareCaptionFor` (gym → null, activity → caption) in `test/domain/share/share_card_test.dart`
- [x] T003 Implement `lib/domain/share/image_check.dart` and `shareCaptionFor` in `lib/domain/share/share_card.dart`
- [x] T004 [US1] Freeze card data, end-of-frame wait, blank check with 3 retries in `lib/features/share/share_preview_screen.dart`
- [x] T005 [US2] Pass `shareCaptionFor(data)` as the share text in `lib/features/share/share_preview_screen.dart`
- [x] T006 Widget tests (gym share has no text, DB write during preview, blank never shared) in `test/features/share_test.dart`
- [x] T007 [P] PRD v2.16 §5.11 + changelog in `docs/PRD-fitapp-flutter.md`; CLAUDE.md active feature
- [x] T008 Format, analyze, test; commit; merge; push
