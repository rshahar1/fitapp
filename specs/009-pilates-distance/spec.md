# Feature Specification: Pilates and Manual Distance

**Feature Branch**: `009-pilates-distance`

**Created**: 2026-11-14

**Status**: Draft

**Input**: User description: "Add a Pilates workout type with a duration input like the existing
time-based activities. For Running and Cycling, add an option to manually input distance, operating
similarly to the existing manual time input." (Live GPS / sensor tracking was asked as a feasibility
question only; see [docs/proposals/live-tracking.md](../../docs/proposals/live-tracking.md). It is
NOT part of this feature.)

## Clarifications

### Session 2026-11-14

- Q: How does Pilates log time? → A: Exactly like the other activity types: the shared optional
  **Duration** (None / Set, stepper in 5-minute steps). No Pilates-specific fields.
- Q: Units for distance? → A: **Kilometres only** in the UI, stored internally as whole **metres**,
  matching the kg-only rule (miles, like kg/lb, is a LATER display setting; storing metres keeps it
  a pure display change).
- Q: How is distance entered? → A: Same pattern as Duration: a **Distance** None / Set selector;
  Set shows a decimal number field in km (e.g. `10.37`). A stepper is not used because real
  distances (5–150 km, copied from a watch to 0.01 km) would need dozens of taps.
- Q: Which types offer distance? → A: **Running and Cycling** only. Switching an entry to another
  type hides the field and the saved entry has no distance.
- Q: Is anything derived? → A: When both distance and duration are set, History shows **pace**
  for running (`5:23 /km`) and **average speed** for cycling (`24.5 km/h`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log Pilates (Priority: P1)

The user opens Log activity, picks Pilates, sets 50 minutes and saves. History shows it with a
Pilates icon, "Pilates" and "50 min".

**Independent Test**: Log "Pilates, today, 50 min": History shows the entry at the top with the
Pilates icon and "50 min".

**Acceptance Scenarios**:

1. **Given** the Log activity sheet, **When** it opens, **Then** Pilates is offered with the other
   five types.
2. **Given** Pilates is picked, **When** the user looks for Distance, **Then** there is none.

### User Story 2 - Distance for Running and Cycling (Priority: P1)

After a run the user logs Running, 28 min, distance Set → `5.2` km. History shows
"5.2 km · 28 min · 5:23 /km".

**Independent Test**: Log "Cycling, 1 h 30 min, 36.75 km": History shows
"36.75 km · 1 h 30 min · 24.5 km/h".

**Acceptance Scenarios**:

1. **Given** Running or Cycling is picked, **When** the sheet shows, **Then** a Distance None / Set
   selector appears below Duration (None by default for new entries).
2. **Given** Distance is Set, **When** the field is empty, zero, non-numeric or above 1000 km,
   **Then** Save is disabled and the field shows a short error.
3. **Given** a Running entry with distance, **When** it is edited, **Then** the distance is
   pre-filled; switching it to Snowboarding hides Distance and saving clears it.
4. **Given** distance without duration, **Then** History shows only "5.2 km" (no pace).

### Edge Cases

- Comma decimal separator (`5,2`) is accepted as `5.2`.
- More than two decimals are rounded to the nearest 10 m.
- Entries logged before this feature have no distance and display unchanged.
- Unknown (retired) type ids keep working; their distance (if any) is kept on edit.

## Requirements *(mandatory)*

- **FR-001**: The activity registry MUST include `pilates` ("Pilates"), with its own icon.
- **FR-002**: Pilates MUST use the shared optional Duration field.
- **FR-003**: Activities MUST store an optional distance in whole metres (1 .. 1,000,000).
- **FR-004**: Only distance-capable types (Running, Cycling) MAY carry a distance; validation MUST
  reject a distance on other known types.
- **FR-005**: The sheet MUST offer Distance (None / Set + km field) only for distance-capable types.
- **FR-006**: History MUST show distance, and pace (running) or speed (cycling) when duration is
  also set.
- **FR-007**: The schema change MUST be a versioned migration (v4 → v5) that keeps all data.

## Success Criteria *(mandatory)*

- **SC-001**: Logging a run with distance takes ≤ 5 taps plus typing the number.
- **SC-002**: Upgrading from v4 keeps every workout, template and activity.
- **SC-003**: Format, analyze and all tests green.

## Out of scope

Live GPS tracking, routes, maps, sensors, miles, elevation, snowboarding metrics (see the proposal).
