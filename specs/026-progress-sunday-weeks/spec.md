# Feature Specification: Progress Chart on Sunday Weeks

**Feature Branch**: `026-progress-sunday-weeks`

**Created**: 2026-11-20

**Status**: Implemented

**Input**: Owner request "Yes, align it": the Progress tab's *Workouts per week* bar chart must use the
same Sunday to Saturday weeks as the Train screen (feature 025).

## Findings before the change

- The chart bucketed sessions into ISO weeks (Monday to Sunday) via `isoWeekKey` and labelled bars
  with ISO week numbers such as `W46`, so one session could fall in different weeks on Train and
  on Progress.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Same weeks as Train (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a session on Saturday and another on the next Sunday, **When** Progress is shown,
   **Then** they fall in two different bars (Saturday belongs to the previous week).
2. **Given** sessions on Sunday and Saturday of the same week, **Then** they count in one bar.
3. The last bar is the current week and stays highlighted; it matches Train's *This week*.

### User Story 2 - Readable bar labels (Priority: P2)

**Acceptance Scenarios**:

1. Bars are labelled with the week's Sunday: day of month, plus the short month on the first bar
   and whenever the month changes, e.g. `18 Oct`, `25`, `1 Nov`, `8`.
2. The accessibility label reads "Workouts per week, by week starting: 18 Oct: 2, 25: 0, ...".

### Edge Cases

- Weeks with no sessions show a zero bar (always 8 bars, oldest first).
- Gym workouts and activities both count (unchanged).
- Weeks use local calendar days (DST safe).

## Requirements

- **FR-001**: `workoutsPerWeek` returns the last 8 Sunday-to-Saturday weeks keyed by each week's
  Sunday (date only), oldest first, zero-filled.
- **FR-002**: Bar labels follow the day-of-month / month-change format above.
- **FR-003**: The ISO week helpers (`isoWeekKey`, `isoWeekMonday`) are removed; nothing uses them.
