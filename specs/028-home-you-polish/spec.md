# Feature Specification: Home, Progress and You Polish

**Feature Branch**: `028-home-you-polish`

**Created**: 2026-11-20

**Status**: Implemented

**Input**: Owner request: (1) Progress shows a weight for only some exercises; show it for all.
(2) Home *By type* shows types with 0 this week; show only types active this week. (3) Home
*Recent* shows only gym workouts; show all types, newest first. (4) Replace *Week streak* with
*This month*. (5) Move template creation from Home to You → **Gym Templates**, between *Exercise
library* and *Settings*.

## Findings before the change

- Progress rows showed the exercise's own plan (`exercise_state`). Exercises trained from a
  template keep their plan on the template exercise (feature 005), so most rows showed `—`. The
  exercise detail *Current base* tile had the same gap.
- *Recent* came from the gym-only workout history; activities were left out.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A weight for every trained exercise (Priority: P1)

1. **Given** an exercise trained only from a template, **When** Progress is shown, **Then** its
   row shows the template plan's current base weight.
2. **Given** an exercise trained ad hoc with its own plan, **Then** the row shows that plan's base.
3. **Given** an exercise whose latest session has no plan at all, **Then** the row shows that
   session's working weight (heaviest non-overload set; heaviest set if none).
4. The plan used is the one of the exercise's latest finished session with sets. The detail
   screen's first tile ("Current weight") shows the same value.

### User Story 2 - Home stats (Priority: P1)

1. *By type* lists only types with at least one session in the current Sunday-to-Saturday week
   and is hidden when there is none.
2. The tiles are *This week*, *This month* (sessions in the current local calendar month, gym
   workouts and activities) and *All time*.
3. *Recent* shows the 3 newest sessions of any type (gym workouts and activities), using the
   History rows, and opens the workout or activity on tap.

### User Story 3 - Gym Templates under You (Priority: P2)

1. Home has no *New* template button; its templates list with **START** stays. With no templates
   it says "Create one in You → Gym Templates."
2. You lists *Gym Exercise Library*, **Gym Templates**, *Settings*, in that order.
3. Gym Templates (`/templates`) lists templates (tap to edit) and has a *New template* action;
   empty state explains templates.

### Edge Cases

- An exercise with sessions but no sets in any of them shows `—`.
- Month boundaries use local calendar days.
- The backup nudge still counts finished gym workouts only.

## Requirements

- **FR-001**: Trained exercises carry a current weight resolved as in User Story 1.
- **FR-002**: `trainingBreakdown` output is filtered to `thisWeek > 0` for display.
- **FR-003**: `HomeStats` replaces `streak` with `thisMonth`; `recent` is `List<HistoryEntry>`.
- **FR-004**: New route `/templates` (Gym Templates screen); Home no longer links to
  `/template/new`.
