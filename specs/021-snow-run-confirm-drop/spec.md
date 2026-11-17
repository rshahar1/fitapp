# Feature Specification: Earlier Run Confirmation Off a Lift

**Feature Branch**: `021-snow-run-confirm-drop`

**Created**: 2026-11-17

**Status**: Implemented (real-day check open)

**Input**: Finding 1 of feature 019: on the Val Thorens simulation the live chip keeps saying "On lift"
for 49 s and 63 s after the rider set off on a flat traverse. Proposal: `runConfirmDrop: 6`.

## Clarifications

### Session 2026-11-17

- Q: What changes? → A: Only the default of `SnowTuning.runConfirmDrop`, 10 m → 6 m
  (`lib/domain/tracking/snow_reducer.dart`). No new rule, no new field.
- Q: Rule after the change? → A: Off a lift, a run candidate is confirmed after `runConfirm` (10 s)
  and a net smoothed-altitude drop ≥ `runConfirmDrop`. Distance alone does not count off a lift
  (cabins cross flat ground). From a rest, 10 s and 60 m distance also confirms (unchanged).
- Q: `runConfirmMeters` (60 m)? → A: Not changed. The 7 s "Riding" flicker at the cable-car start
  stays a known limit (019 test "known limit: the cable car start shows a run for under 10 s").

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run shown sooner on a flat start (Priority: P1)

A snowboarder leaves a lift and starts on a near-level traverse. The live chip switches from
"On lift" to "Riding" sooner, after 6 m of net drop instead of 10 m.

**Independent Test**: Val Thorens fixture: both runs show within 40 s of the rider setting off
(was 49 s and 63 s; now 36 s and 31 s).

**Acceptance Scenarios**:

1. **Given** the Val Thorens session, **When** reduced fix by fix, **Then** a run off a lift on a
   flat traverse shows within 40 s.
2. **Given** the Val Thorens session and the synthetic `plainDay` and `longDay`, **Then** run
   count, ride / lift / rest time, drop, distance and max speed are identical to before (runs are
   backdated, only live timing changes).

### User Story 2 - A dipping lift stays one lift (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a lift that dips 5 m over 25 s between towers, **Then** it stays one lift, no run.

## Requirements

- **FR-001**: `SnowTuning.runConfirmDrop` defaults to 6 m. Other thresholds are unchanged.
- **FR-002**: Domain stays pure Dart; tests are written first.

## Edge Cases

- A lift that loses ≥ 6 m net over ≥ 10 s while moving ≥ 2 m/s with climb rate ≤ 0.10 m/s could be
  split by a false run (a gondola dipping across a valley). Guarded by the 5 m dip test; a real ski
  day should confirm.
- The remaining delay is inherent: nothing tells a flat traverse from a level stretch of cable
  until height is lost.

## Success Criteria

- **SC-001**: Run shown within 40 s on both Val Thorens pistes (017 SC-002 aims at 15 s; not
  reachable on flat starts).
- **SC-002**: All totals identical before and after on the three scenarios above.
- **SC-003**: 906 tests green, format and analyze clean.
- **SC-004**: (owner) no false run splits a lift on a real ski day.
