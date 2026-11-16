# Implementation Plan: History calendar shows the month view only

**Branch**: `016-history-month-only` | **Spec**: [spec.md](spec.md)

## Technical Context

UI-only change in `lib/features/history/history_calendar.dart`. No schema, provider, domain or
package change. Constitution unchanged (scope shrinks).

## Constitution Check

- III: widget tests updated with the change. ✅ IV: no data-layer change. ✅

## Design

- Delete `_CalendarMode`, `_mode`, `_isMonth`, the `SegmentedButton<_CalendarMode>` and
  `_weekTitle`. Every former `_isMonth ? month : week` branch keeps the month branch only
  (`_canGoNext`, `_step` via `addMonths`, grid via `monthGrid`, title `MMMM y`, tooltips, day cell
  `inMonth: day.month == anchor.month`).
- Keep the `SizedBox(height: Space.s)` gap above the navigation row.
- Tests (`test/features/history_calendar_test.dart`): drop `toMonth` and the week tests; add
  "defaults to the month view, no Week selector".
