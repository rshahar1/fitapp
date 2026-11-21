# Feature Specification: History Gym Rows Like Recent, Edit / Share / Delete Only

**Feature Branch**: `037-history-gym-row-menu`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21, after 0.0.31): (1) on History, gym workouts should not list their
exercises; they should look like the other activities and like Home's Recent rows. (2) On a gym
workout opened from History, the ⋮ menu keeps only Delete, Share and Edit, like other workout types.

## Findings before the change

- History (list and calendar day) uses `HistoryWorkoutRow`: date, exercise names, volume, sets and
  duration. Home's Recent uses `HistoryWorkoutCompactRow` (`GroupRow`: badge, date, template name,
  chevron), the same shape as `HistoryActivityRow`.
- The finished workout's "Workout options" menu holds Edit workout, Share, Resume workout (when
  allowed), Save as template and Delete workout. The activity menu holds Edit activity, Share and
  Delete activity.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Gym rows like Recent (Priority: P1)

1. **Given** finished gym workouts, **When** History opens (list or calendar day), **Then** each
   workout row shows the dumbbell badge, the date, the template name ("Workout" when ad hoc) and a
   chevron, exactly like Home's Recent; no exercise names, volume or set count. Tapping opens it.

### User Story 2 - Edit / Share / Delete only (Priority: P1)

1. **Given** a finished gym workout, **When** its ⋮ menu ("Workout options") opens, **Then** it
   holds only Edit workout, Share and Delete workout (Delete last, danger colour), all as
   icon + label items.
2. **Given** edit mode, **Then** the menu holds only Delete workout ("Done editing" stays).
3. A live workout's menu is unchanged (Save as template, Discard workout); the finish summary's
   Resume is unchanged.

## Requirements

- **FR-001** History and Recent share one gym row widget; the detailed workout row is removed.
- **FR-002** The finished workout menu has no Resume workout or Save as template item.
- **FR-003** Repository functions (`resumeWorkout`, `saveFromWorkout`) and the live / finish
  summary paths are unchanged.

## Notes

- Owner's decision: Resume of an already-finished workout and Save as template from a finished
  workout are no longer reachable from History (recorded in PRD §15). Resume stays on the finish
  summary; templates can still be built in the template editor or saved from a live workout.
