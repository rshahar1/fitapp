# Feature Specification: Daily distance (km) next to steps

**Feature Branch**: `018-daily-distance`
**Status**: Implemented

**Input**: Alongside the total steps per day, also show the total distance (km) per day, as in
Google Fit / Health Connect.

## User Scenarios & Testing

### User Story 1 — Today's km on the Train steps card (P1)
1. **Given** step and distance access are granted, **Then** the "Steps today" card shows the step
   count and, beside it, today's distance in km (e.g. "6.21 km"), from midnight to now.
2. **Given** steps are granted but distance is not (existing users), **Then** the step count is
   unchanged and a "Show km" button asks for the distance permission only.
3. **Given** the distance read fails or returns nothing, **Then** no km text is shown (steps unaffected).

### User Story 2 — A day's km in History (P1)
1. **Given** access is granted, **When** a day is selected, **Then** the day header shows
   "8,432 steps · 6.21 km" as plain text (no emoji/icon).
2. **Given** no distance permission or unreadable, **Then** only the steps text shows, as before.
3. Same 30-day window, day boundaries and "off / not granted" rules as feature 015.

## Requirements
- **FR-001**: Distance is read live from Health Connect's aggregated distance total (deduplicated
  across sources) for the same intervals as steps; nothing stored, synced or sent.
- **FR-002**: Needs `READ_DISTANCE`; the step feature must keep working without it.
- **FR-003**: Format: metres → km, 2 decimals, "0.00 km" for zero.
- **FR-004**: Connect flow requests steps and distance together; privacy text mentions distance.
- **FR-005**: No distance reads when steps are off, access is not granted, or distance is not granted.
