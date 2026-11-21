# Feature Specification: History Opens on Calendar, No "template plan" Label

**Feature Branch**: `038-history-calendar-default`

**Created**: 2026-11-21

**Status**: Implemented

**Input**: Owner (2026-11-21, after 0.0.32): (1) History shows the Calendar view by default, and the
switch puts Calendar on the left and List on the right. (2) On a workout started from a template,
the exercise card subtitle (`3 × 10 @ 125 kg · overload +2.5 · per hand · template plan`) drops the
`· template plan` suffix.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Calendar first (Priority: P1)

1. **Given** the app starts, **When** History opens, **Then** the Calendar view shows and the
   switch reads Calendar (left) | List (right).
2. Switching to List still works; the Home steps card still opens the calendar.

### User Story 2 - No "template plan" label (Priority: P1)

1. **Given** a workout started from a template, **When** an exercise card shows, **Then** its
   subtitle is only the plan summary, with no `template plan` text.
2. The ⋮ menu's Edit plan still edits the template plan (sheet title unchanged).

## Requirements

- **FR-001** `historyViewProvider` defaults to `HistoryView.calendar`; segment order Calendar, List.
- **FR-002** The exercise card subtitle is `planSummary(...)` only.
