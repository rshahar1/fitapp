# Implementation Plan: Train Stats — Sunday Weeks and Per-Type Breakdown

**Branch**: `025-train-stats-breakdown` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Move the Train screen's week maths from ISO weeks to the Sunday-based weeks already used by the
History calendar (`calendar.startOfWeek`), add a pure per-type breakdown, and show it on Train.
No schema, dependency or sync change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged) · **New dependencies**: none ·
**Storage**: unchanged · **Testing**: domain unit tests first, repository and widget tests.

## Constitution Check

New logic lives in `lib/domain/` as pure Dart with tests written first (principle II/III). UI reuses
`MetricTile`, `SectionHeader`, `Group`/`GroupRow` and `ActivityIcon` (principle V). PRD §5.5 and the
feature 006 decision row are updated to match (docs follow what was built).

## Design

1. `lib/domain/stats.dart`: `weeklyStreak` walks Sunday-based weeks (`startOfWeek` from
   `calendar.dart`). ISO helpers stay for the Progress bars.
2. New `lib/domain/training_breakdown.dart`: `gymTypeId = 'gym'`, `TrainingSession(typeId, date)`,
   `TypeCount(typeId, thisWeek, allTime)`, `isSameWeek(a, b)` and
   `trainingBreakdown(sessions, now:)` (unknown activity ids → `'activity'`; ordering per spec).
3. `HomeStats`: `thisWeek`, `streak`, `allTime` (replaces `total`), `byType`, `recent`.
   `WorkoutRepository.homeStats` builds sessions from finished workouts (`gym`) and activities.
4. `lib/features/train/train_screen.dart`: third tile **All time**; a **By type** section (Group of
   rows: type icon, label, "N all time" subtitle, "N this week" trailing) hidden when empty.
5. Tests: `test/domain/training_breakdown_test.dart`, `stats_test.dart` streak cases, repository
   tests in `test/data/`, Train widget test.
