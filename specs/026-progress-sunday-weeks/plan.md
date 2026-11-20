# Implementation Plan: Progress Chart on Sunday Weeks

**Branch**: `026-progress-sunday-weeks` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Move the Progress bar chart from ISO weeks to the Sunday-based weeks used by Train and History
(`calendar.startOfWeek`) and label bars by date. No schema, dependency or sync change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged) · **New dependencies**: none ·
**Storage**: unchanged · **Testing**: domain unit tests first, repository and widget tests.

## Constitution Check

Logic stays in `lib/domain/` as pure Dart with tests written first (principle II/III). The chart
widget only renders. PRD §5.5, §5.6, the test list and the decision log are updated to match.

## Design

1. `lib/domain/stats.dart`: `workoutsPerWeek` returns `Map<DateTime, int>` keyed by week Sunday
   (via `startOfWeek`), last 8 weeks, oldest first, zero-filled. Remove `isoWeekKey` and
   `isoWeekMonday`. New pure `weekBarLabels(List<DateTime> sundays)`.
2. `lib/data/providers.dart`, `lib/data/repositories/workout_repository.dart`: types updated to
   `Map<DateTime, int>`.
3. `lib/widgets/weekly_bar_chart.dart`: takes `Map<DateTime, int>`, uses `weekBarLabels`, semantics
   "Workouts per week, by week starting: 18 Oct: 2, 25: 0, ...", current week still highlighted.
4. Tests: `test/domain/stats_test.dart` (ISO tests removed, Sunday and label cases),
   `test/data/activity_stats_test.dart`, `test/data/home_stats_test.dart`, chart widget test.
