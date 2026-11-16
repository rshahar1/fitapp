# Feature Specification: History calendar shows the month view only

**Feature Branch**: `016-history-month-only`
**Created**: 2026-11-16
**Status**: Implemented

**Input**: Remove the History calendar's week view entirely and keep the month view only. This
also removes the Month/Week selector under the List/Calendar toggle, which looked too much like it.

## User Scenarios & Testing

### User Story 1 — One calendar view (P1)

**Acceptance Scenarios**

1. **Given** the History tab, **When** the user picks Calendar, **Then** the current month's grid
   is shown right under the List/Calendar toggle, with no second (Month/Week) selector.
2. Previous/next arrows move by one month (tooltips "Previous month" / "Next month"); next is
   disabled at the current month. The title "MMMM y" opens the month/year picker. "Today" returns
   to the current month and selects today.
3. Day selection, day cells, the selected-day session list and the step total are unchanged.

## Requirements

- **FR-001**: The History calendar has no week mode and no Month/Week selector.
- **FR-002**: Month navigation, the picker and "Today" behave as they did in month mode.

## Success Criteria

- **SC-001**: No "Week" control, week title or "Previous/Next week" tooltip appears anywhere in
  History.
- **SC-002**: No layout overflow at 360x690.

## Out of Scope

- Domain calendar helpers (`startOfWeek`, `weekDays`, `monthGrid`) stay; the weekday header row
  still uses `weekDays`.
