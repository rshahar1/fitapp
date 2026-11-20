# Implementation Plan: Home, Progress and You Polish

**Branch**: `028-home-you-polish` | **Date**: 2026-11-20 | **Spec**: [spec.md](./spec.md)

## Summary

Resolve a current weight for every trained exercise, rework Home stats (active types only,
*This month*, mixed *Recent*), and move template management to a new You → Gym Templates screen.
No schema, dependency or sync change.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged) · **New dependencies**: none ·
**Storage**: unchanged · **Testing**: domain unit tests first, repository and widget tests.

## Constitution Check

Pure rules (`isSameMonth`, `activeTypes`, `currentWeightOf`) live in `lib/domain/` with tests
written first (principle II/III). Screens only render. PRD §5.5, §5.6, §5.9 and changelog updated.

## Design

1. `lib/domain/training_breakdown.dart`: `isSameMonth(a, b)`, `activeTypes(List<TypeCount>)`.
2. `lib/domain/stats.dart`: `displayWeight({planBase, workingWeight, topWeight})` — plan base,
   else working weight, else top weight, else null.
3. `ExerciseRepository.currentWeight(exerciseId)`: latest finished session with sets; plan =
   its template exercise plan (template session) or the exercise plan (ad hoc); then
   `displayWeight`. `TrainedExercise.currentWeight`; `currentWeightProvider` family for detail.
4. `WorkoutRepository.homeStats`: `thisMonth`, `recent = historyEntries().take(3)`; remove
   `streak` from `HomeStats` (`weeklyStreak` stays in the domain, unused by UI).
5. UI: `train_screen.dart` (tiles, active By type, `HistoryEntryRow` for Recent, no *New*),
   `progress_screen.dart`, `exercise_detail_screen.dart`, new
   `lib/features/templates/templates_screen.dart`, `Routes.templates`, `you_screen.dart`.
