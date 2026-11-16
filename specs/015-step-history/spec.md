# Feature Specification: Step totals in History, steps card below Templates

**Feature Branch**: `015-step-history`
**Created**: 2026-11-16
**Status**: Implemented

**Input**: (1) Main screen shows today's step count only, placed below the "Templates" section
(not above it). (2) History: selecting a date shows that day's total step count alongside the
exercises performed that day. (3) Keep History clean: no emojis on the date or the step count.

## User Scenarios & Testing

### User Story 1 — Today's steps below Templates (P1)

**Acceptance Scenarios**

1. **Given** step access is granted, **When** the Train tab opens, **Then** the "Steps today" card
   appears after the Templates section (after its last template card or its empty message) and
   before the weekly metrics row. Nothing step-related appears above Templates.
2. The card shows today's count only (no history, no chart). All other card states from feature
   014 (Connect, Get Health Connect, hidden) are unchanged, just in the new position.

### User Story 2 — A day's steps in the History calendar (P1)

**Acceptance Scenarios**

1. **Given** access is granted, **When** the user selects a day in the History calendar (week or
   month view), **Then** the day header shows the date on the left and that day's total on the
   right as plain text, e.g. "8,432 steps", above the day's workouts and activities.
2. **Given** the selected day has no workouts, **Then** the step total still shows and the list
   says "No training" as today.
3. **Given** the selected day is today, **Then** the total runs from midnight to now and
   refreshes on app resume, matching the Train card.
4. **Given** a future day, a day more than 30 days ago, steps turned off, access not granted, or
   a read failure, **Then** no step text is shown (no placeholder, no prompt).
5. **Given** zero steps were recorded that day (within 30 days, access granted), **Then** it
   shows "0 steps".
6. Text only: no emoji, icon or badge next to the date or the step count; theme secondary text
   style, tabular figures; one step reads "1 step".

### Edge Cases

- Switching days quickly shows only the selected day's count (no stale value from another day).
- Day boundaries are local midnight to the next local midnight (DST-safe).

## Requirements

- **FR-001**: The Train "Steps today" card sits below the Templates section.
- **FR-002**: The History calendar's selected-day header shows that day's step total as plain text.
- **FR-003**: Day totals are read live from Health Connect's aggregate for that local day; nothing
  is stored, synced or sent.
- **FR-004**: Only days from today back 30 days are read; other days show no step text.
- **FR-005**: No reads when the feature is off or access is not granted.

## Success Criteria

- **SC-001**: A selected day's total appears within 2 seconds of tapping the day.
- **SC-002**: No emoji or icon appears in the History date or step display.
- **SC-003**: The Train tab shows Templates before any step content.

## Assumptions

- 30 days is Health Connect's default readable window without the extra history permission; the
  owner only needs data recorded since connecting (feature 014 decision).
- No step totals on calendar day cells or in the flat History list (only the selected day).
