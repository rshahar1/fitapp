# Implementation Plan: Live Snowboarding Tracking

**Branch**: `017-snowboard-live-tracking` | **Date**: 2026-11-16 | **Spec**: [spec.md](./spec.md)

## Summary

Snowboarding joins running and cycling as a live-tracking type and reuses the whole feature 010
pipeline unchanged: `LocationSource` → `TrackingController` → base `track_reducer` (accuracy and
glitch filter, manual pause, elapsed time) → `TrackingRepository` (5 s persistence, recovery by
replay). A second pure reducer, the **snow reducer**, runs on the fixes the base reducer accepts
and classifies them into run / lift / rest segments, from which all snowboarding metrics are
derived. Saving writes the same single `activities` row with six new optional columns (drift
schema v9 + one Supabase migration). The live screen, finish sheet, detail screen and History row
get a snowboarding branch.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)

**New dependencies**: none.

**Storage**: drift schema v9 and Supabase migration — [data model](#data-model)

**Testing**: snow reducer with synthetic ski-day fixtures (100% line coverage for the new domain
files); replay-equals-incremental; repository finish for snowboarding; migration v8→v9; SQL tests
for the new columns; controller with `FakeLocationSource`; widget tests for the live tiles, finish
sheet, detail screen, History row and start hub.

**Constraints**: offline-first; no new permission; raw fixes never leave the device; an 8-hour
day (~29,000 fixes) stays responsive; no auto-pause for snowboarding.

## Detection

All of this lives in `lib/domain/tracking/snow_reducer.dart`. Input: each fix the base reducer
accepted while not manually paused, in order. Thresholds are constants in one `SnowTuning` class
so tests and later tuning touch one place. They are starting values, to be tuned on fixtures and
on the owner's first real day.

### 1. Signals per fix

| Signal | Definition |
|---|---|
| `hSpeed` | device (Doppler) speed when present, else path distance over the trailing 5 s |
| `altS` | median altitude of the trailing 15 s (fixes without altitude are skipped) |
| `vRate` | change of `altS` over the trailing 30 s, in m/s; undefined until the window spans 10 s |

### 2. Raw label per fix

| Label | Condition |
|---|---|
| lift | `vRate ≥ +0.25 m/s` and `hSpeed ≥ 0.8 m/s` |
| run | `hSpeed ≥ 2.0 m/s` and `vRate ≤ +0.10 m/s` |
| rest | `hSpeed < 1.0 m/s`, or the gap since the previous fix is over 10 s |
| (none) | anything else, or `vRate` undefined for lift: keeps the current segment's kind |

### 3. State machine with backdating

The session starts in **rest**. When the raw label differs from the current segment's kind, a
**candidate** of that kind opens at that fix and accumulates its own time, distance, altitude
change and max speed. It is dropped when the raw label goes back to the current kind or to the
third kind. When it meets its confirmation rule, the current segment is closed **at the
candidate's first fix** and the candidate becomes the current segment with everything it
accumulated. Totals are always sums over segments, so backdating never leaves them inconsistent.

| Candidate | Confirmed when |
|---|---|
| lift | net `altS` gain since it opened ≥ 15 m |
| run | open ≥ 10 s and (`altS` drop ≥ 10 m or distance ≥ 60 m) |
| rest (from run) | open ≥ 10 s |
| rest (from lift) | open ≥ 120 s (a stopped chairlift stays a lift) |

**A lift ends at its last climbing fix.** When a lift is left (to rest after 120 s, or to a
confirmed run), the lift segment is closed at the last fix whose raw label was lift; the time
between that fix and the next segment becomes a rest segment if it is 10 s or longer, otherwise
it joins the next segment. This keeps standing at the top station out of lift time.

A gap inside a lift (gondola cabin) shorter than 120 s stays lift. A longer gap stays lift only
if `altS` rose at least 15 m across it.

### 4. Metrics

| Metric | Definition |
|---|---|
| ride / lift / rest seconds | sum of segment durations per kind |
| ride distance | sum of run segment distances (haversine between accepted fixes) |
| vertical drop | per run segment, descent of `altS` with 5 m hysteresis; summed |
| lift gain | per lift segment, ascent of `altS` with 5 m hysteresis |
| current speed | `hSpeed` over 5 s; 0 while resting |
| max speed | highest median-of-3 `hSpeed` inside run segments |
| average speed | ride distance ÷ ride seconds |
| run count | number of **descents** with total drop ≥ 30 m, where a descent is the consecutive run and rest segments between two lifts (or the session start / end) |

`snowDescents(segments)` builds that grouping for the run count and for the detail timeline.

### 5. Manual pause

A fix flagged `paused` is not fed to the snow reducer. `pauseSnow` closes the current segment
and drops the candidate; `resumeSnow` clears the signal windows and starts a new rest segment, so
nothing is measured across the pause.

## Data model

```text
activities (+ columns, all nullable; set only for source 'gps' and type 'snowboarding')
  vertical_drop_meters INT      -- sum over runs
  run_count            INT
  max_speed_mps        REAL
  lift_seconds         INT
  rest_seconds         INT
  segments             TEXT     -- JSON list, see below

Reused columns for a tracked snowboarding day:
  distance_meters = ride distance      moving_seconds = ride seconds
  duration_minutes = elapsed minus manual pauses
  route = whole day, encoded polyline  elevation_gain_meters, splits = NULL
```

`segments` JSON, one object per segment in time order:

```json
{"k":"r","t":1260,"d":212,"m":1840,"v":412,"s":17.4,"n":96}
```

`k` kind (`r` run, `l` lift, `s` rest) · `t` start, seconds since the activity started · `d`
duration in seconds · `m` distance in metres · `v` vertical in metres (drop for a run, gain for
a lift, 0 for rest) · `s` max speed in m/s, one decimal (runs only) · `n` number of points of
`route` that belong to this segment. Each segment is simplified on its own (Douglas-Peucker,
5 m) and the results are concatenated, so slices of `route` by `n` give each segment's line.

**Local**: migration `from8To9` adds the six columns; `drift_schemas/drift_schema_v9.json`;
generated `schema_v9.dart`; migration test v8→v9 (existing rows keep nulls).

**Server**: `supabase/migrations/20261116000001_activities_snowboard.sql` adds the same columns
(`>= 0` checks, `length(segments) <= 100000`), and replaces `public.sync_columns` so the
`activities` whitelist includes them. `lib/data/sync/sync_table.dart` gains the six
`SyncColumn`s (`max_speed_mps` is `ColKind.real`). Older clients ignore the columns.

## Domain (`lib/domain/`, pure)

| File | Content |
|---|---|
| `activity_types.dart` | snowboarding: `hasDistance: true, hasLiveTracking: true`; `formatSpeedMps`, `formatMetersGrouped` ("3,240 m") |
| `tracking/track_profile.dart` | `TrackProfile.snowboarding` (max 45 m/s, auto-pause speed 0 so it never triggers); `forType` accepts it |
| `tracking/snow_state.dart` | `SnowKind`, `SnowSegment`, immutable `SnowState` (closed segments, current segment, candidate, signal windows) with getters for every metric in the table above |
| `tracking/snow_reducer.dart` | `SnowTuning`, `startSnow`, `accumulateSnow(state, fix)`, `pauseSnow`, `resumeSnow`, `replaySnow(accepted)`, `snowDescents(segments)` |
| `tracking/snow_summary.dart` | `SnowSummary` and `summarizeSnow(state, accepted, endedAt)`: closes the open segment, simplifies per segment, encodes the route, builds the segment list; `encodeSegments` / `decodeSegments` |

The base reducer is not changed. Per-fix cost stays constant: windows are bounded by time.

## Data / controller

| File | Change |
|---|---|
| `data/db/tables.dart`, `app_database.dart` | six columns, schema v9, `from8To9` |
| `data/sync/sync_table.dart` | six sync columns |
| `data/repositories/tracking_repository.dart` | `finish`: for snowboarding, replay the snow reducer over the accepted fixes and write the snowboarding columns; other types unchanged. `replaySnowState(row, points)` for recovery |
| `data/repositories/activity_repository.dart` | editing a `gps` snowboarding row keeps its type |
| `features/tracking/tracking_controller.dart` | holds a `SnowState?` next to the `TrackState` (fed in `_onFix` when the fix was accepted, rebuilt in `recover`, paused / resumed with the track); `TrackingLive.snow`; `previewSnowSummary()`; **route thinning**: the live route keeps a point only when it is ≥ 10 m from the last kept one and halves itself when it passes 2,000 points (applies to every type) |

## UI

| Place | Change |
|---|---|
| Start hub, Log activity sheet, setup screen | nothing to build: they follow `hasLiveTracking`. The sheet shows Distance for manual snowboarding and hides the type picker when editing a tracked snowboarding day |
| Live screen | `widgets/snow_live_panel.dart`: hero = current speed (km/h); status chip Riding / On lift / Resting; tiles Runs, Vertical, Max speed, Avg speed, Distance, Elapsed. Footer unchanged |
| `RouteMap` | optional `sections` (list of point ranges marked muted) so lifts draw muted and runs in the accent colour, in both the tile map and the painter fallback |
| Finish sheet | snowboarding branch: Runs, Vertical, Distance, Max speed, Avg speed, Time, and the time bar |
| `widgets/snow_time_bar.dart` | one horizontal bar split into ride / lift / rest with a legend ("Ride 1 h 12 min") |
| Activity detail | snowboarding branch: sectioned map, totals, time bar, `snow_timeline.dart` listing descents (run number, start time, duration, drop, distance, max speed) and lifts (start time, duration, gain). No km markers, no splits |
| History row | "8 runs · 3,240 m ↓" instead of pace or speed |

Colours from theme tokens; Semantics labels on the chip, the bar and each timeline row.

## Fixtures

`test/domain/tracking/snow_fixtures.dart` generates deterministic ski days (seeded noise: 3 m
horizontal, 4 m altitude) from a script of legs (lift, run, queue, stop) and returns the fixes
with reference totals. Scenarios: plain day (3 lifts, 3 runs); chairlift stopping 90 s;
stop mid-run; short traverse under 30 m; manual pause for lunch; gondola with a 3-minute GPS gap;
fixes without altitude; an 8-hour day for the size and performance criteria. A real GPX from the
owner, if they provide one, is added as an extra fixture.

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline-first: no network needed; versioned migration v9 adds nullable columns only; one transaction on finish | ✅ |
| II. Pure domain: snow reducer and summary in `lib/domain/tracking/`, fixture tests, replay = incremental | ✅ |
| III. Tests first for domain and data; SQL tests for the server migration | ✅ |
| IV. Layering unchanged; writes through `TrackingRepository`; no new package | ✅ |
| V. Same footer, hold-to-finish, 56 dp controls, semantics, dark theme | ✅ |
| VI. Raw fixes stay on device; route and segment list sync to the owner's account only; RLS already covers `activities` | ✅ (VI wording amended) |
| VII. Owner request 2026-11-16 → amended (1.8.0): snowboarding tracking in scope; barometer, piste names, 3D replay, sharing still out | ✅ (amendment) |

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| A second reducer beside `track_reducer` | Run / lift / rest classification with backdating is a different state machine from pace and auto-pause | Folding it into `TrackState` would put snowboarding fields and branches into every run and ride |
| `segments` JSON column | The detail timeline and the run / lift colouring need per-segment data | A child table needs its own sync table, triggers, RLS and tombstones for data that is never queried on its own |
| Five scalar columns besides the JSON | History rows and future stats read totals without parsing JSON | Deriving them from `segments` on every list row costs a parse per row |
