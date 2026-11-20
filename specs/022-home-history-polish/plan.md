# Implementation Plan: Home and History Polish

**Branch**: `022-home-history-polish` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Four small UI changes: a "live" style for a session in progress on Train, the 🏋️ emoji for
functional training, Sunday-first History calendar weeks, and a tappable steps card that opens the
History calendar. No schema, dependency or data change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)

**New dependencies**: none

**Testing**: domain test for Sunday weeks first; widget tests for the other three.

## Changes

1. **Live style** — `lib/app/theme/tokens.dart`: `AppColors.live = 0xFFFF9F0A`,
   `liveSoft = 0x26FF9F0A`. `lib/widgets/app_button.dart`: `AppButtonVariant.live`
   (live fill, `onAccent` text). `lib/features/train/train_screen.dart` `_HeroCard`: when a session
   is in progress, live border, a "● LIVE" pill next to the title, `variant: live`,
   `icon: Icons.play_arrow`. Start stays `primary`.
2. **Functional icon** — `lib/features/activities/activity_icons.dart`: `ActivityIcon` renders
   `FunctionalIcon` for `functional` (a `CustomPaint` weightlifter on the 24-unit grid, limbs
   about 1.9 units like the Material sport icons, painted in the icon colour), otherwise
   `Icon(activityIcon(id))`. Used by the start hub, the activity sheet chips, History rows
   (`HistoryIconBadge`) and the calendar day marker. Replaced the first 🏋️ emoji after owner
   feedback (colour, then weight).
3. **Sunday weeks** — `lib/domain/calendar.dart`: `startOfWeek` returns the Sunday on or before the
   day (`d.day - d.weekday % 7`). `weekDays` and `monthGrid` follow; the calendar header follows
   `weekDays`. `lib/domain/stats.dart` (ISO weeks) not touched.
4. **Steps → calendar** — `historyViewProvider` (Riverpod, `list` / `calendar`) replaces the local
   `_view` state in `lib/features/history/history_screen.dart`. `StepsCard` (steps shown) passes
   `onTap` to `AppCard`: set calendar, then `StatefulNavigationShell.of(context).goBranch(1)`;
   wrapped with button semantics.

## Constitution Check

Domain stays pure Dart with tests first (II). No data or privacy change. Pass.
