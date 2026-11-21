# Implementation Plan: History Gym Rows Like Recent, Edit / Share / Delete Only

**Branch**: `037-history-gym-row-menu` | **Date**: 2026-11-21 | **Spec**: [spec.md](./spec.md)

## Summary

UI-only change. No domain, schema, sync or dependency change.

## Design

1. `lib/features/history/history_rows.dart`: `HistoryEntryRow` always renders the gym workout as
   the compact row (rename `HistoryWorkoutCompactRow` → `HistoryWorkoutRow`); drop the `compact`
   flag and the old detailed row. `train_screen.dart` drops `compact: true`.
2. `lib/features/workout/workout_screen.dart`: remove the `resume` and `template` items from the
   finished menu; `template` stays for a live workout (`isLive && exercises.isNotEmpty`). Remove
   `_resume` / `canResumeProvider` only if nothing else uses them.
3. Tests: history list asserts template name, no exercise names / volume; edit_mode tests assert
   menu is Edit / Share / Delete only; Save-as-template test runs from a live workout.
4. PRD §5.4 / §15 / changelog v2.23; CLAUDE.md active feature.
