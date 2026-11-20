# Feature Specification: Train Stats — Sunday Weeks and Per-Type Breakdown

**Feature Branch**: `025-train-stats-breakdown`

**Created**: 2026-11-20

**Status**: Implemented

**Input**: Owner request: "This Week" must use Sunday to Saturday (local device time); break the
Train statistics down by training type (e.g. `1 Cycling`, `2 Gym`, `3 Pilates`), clean and
consistent with the Train screen design.

## Findings before the change

- *This week* counted ISO weeks (Monday to Sunday) via `isoWeekKey`; *Week streak* likewise.
- *Total workouts* counted finished gym workouts only (owner decision of feature 006); activities
  counted toward *This week* and *Week streak* but not toward the total.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Sunday to Saturday week (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a session on Saturday and another on the next Sunday, **When** Train is shown on that
   Sunday, **Then** *This week* is 1 (Saturday belongs to the previous week).
2. **Given** sessions on Sunday and Saturday of the same week, **Then** *This week* counts both.
3. *Week streak* uses the same Sunday-based weeks, so a session counted in *This week* always
   counts toward the current streak week.

### User Story 2 - Breakdown by training type (Priority: P1)

**Acceptance Scenarios**:

1. **Given** 2 gym workouts and 1 cycling ride this week and a Pilates class last week, **When**
   Train is shown, **Then** a **By type** list shows Gym (2 this week, 2 all time), Cycling (1 this
   week, 1 all time) and Pilates (0 this week, 1 all time), each with its type icon.
2. Rows are ordered by this-week count, then all-time count, then Gym first and registry order.
3. Types never logged are not listed; with nothing logged the list is hidden.
4. The third tile becomes **All time**: every finished gym workout plus every activity (the sum of
   the breakdown). It replaces the gym-only *Total workouts*.

### Edge Cases

- Unknown activity type ids (newer app version) group into one "Activity" row.
- Unfinished (in-progress) gym workouts never count.
- Weeks are computed on local calendar days (DST safe, `DateTime(y, m, d)` arithmetic).

## Requirements

- **FR-001**: *This week* counts gym workouts and activities started Sunday 00:00 to Saturday
  23:59 local time of the current week.
- **FR-002**: *Week streak* counts consecutive Sunday-based weeks with at least one session, ending
  this week or last week.
- **FR-003**: Train shows a per-type breakdown (this week and all time) under the stat tiles.
- **FR-004**: The third tile shows *All time* = all finished gym workouts + all activities.
- **FR-005**: The Progress tab's ISO-week bar chart is out of scope (unchanged).
