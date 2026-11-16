# Feature Specification: Live Snowboarding Tracking

**Feature Branch**: `017-snowboard-live-tracking`

**Created**: 2026-11-16

**Status**: Draft

**Input**: Owner request (2026-11-16): "add a live snowboarding tracking feature. Currently users
can only log historical snowboarding sessions, while live tracking is limited to running and
cycling. The live tracking and session summary should work like the app Slopes: live GPS route
with the runs on a map; automatic detection and breakdown of time riding down, resting and on
lifts; current, average and max speed; total daily distance, vertical drop and run count."

## Clarifications

### Session 2026-11-16

- Q: How are runs, lifts and rests told apart? → A: **Automatically** from GPS speed and altitude
  change. The user never tags anything. Thresholds are in [plan.md](./plan.md#detection).
- Q: Altitude source? → A: **GPS altitude only** in this version (smoothed). A barometer is a
  later improvement.
- Q: What is a "run"? → A: A descent between two lifts (or the session start / end) with at least
  30 m of vertical drop. Stopping on the way down does not start a new run; that time counts as
  rest.
- Q: Which distance is "the" distance? → A: **Ride distance** (distance covered in runs). Lift
  distance is kept per lift segment but not added to the day's distance.
- Q: Is there auto-pause? → A: **No.** Standing still is classified as rest. Manual Pause stays
  (lunch, car ride) and excludes that time from everything.
- Q: Does a manual snowboarding entry change? → A: It gains the optional **Distance** field
  (same as running and cycling). Nothing else changes; old entries stay as they are.
- Q: Units? → A: km, km/h and metres (kg/km-only rule).
- Q: Which Slopes Premium features
  ([list](https://blog.getslopes.com/discover-slopes-premium/))? → A: **In**: speed heatmap,
  Winter and Satellite map styles, 2D run-by-run replay, run-by-run comparison, detailed stats,
  best-run badges, live stats (already User Story 3). **Not now** (owner, 2026-11-16): 3D maps
  and replay (needs another map engine), lift names (needs a third-party lookup that receives
  locations), heart rate and fitness (needs a watch, a new health permission and a scope change).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record a day on the mountain (Priority: P1)

The user taps "+", picks Snowboarding, waits for "GPS ready", taps Start and puts the phone in a
pocket. They take a lift, ride down, queue, and repeat. At the end of the day they open the app,
hold Finish, see the summary and save. History shows "Snowboarding · 8 runs · 3,240 m ↓" with a
route thumbnail.

**Independent Test**: With a fake location source replaying a synthetic ski-day fixture (3 lifts,
3 runs, queues, one stop mid-run), start, finish and save: one activity is stored with source
`gps`, run count 3, vertical drop within 5% of the fixture's reference, ride / lift / rest
seconds within 5% of the reference, max speed within 5%, a route and a segment list; the raw
points are gone.

**Acceptance Scenarios**:

1. **Given** a live session, **When** the user rides a lift, **Then** within about a minute the
   status shows "On lift" and the whole ascent (from where it began) counts as lift time.
2. **Given** a live session, **When** the user rides down, **Then** the status shows "Riding",
   and runs, vertical drop, ride distance and max speed update.
3. **Given** a run, **When** the user stops for a while and continues down, **Then** the stop
   counts as rest time and the run count does not increase.
4. **Given** a chairlift that stops for under two minutes, **Then** the lift segment continues.
5. **Given** Pause is tapped, **Then** nothing is counted and nothing is classified until Resume.
6. **Given** Finish, **Then** the summary shows runs, vertical drop, ride distance, max and
   average speed, and the split of ride / lift / rest time.

### User Story 2 - Crash-safe day (Priority: P1)

The phone kills the app at midday. On reopening, the live screen returns with the same runs,
vertical drop, times and current state, and tracking resumes.

**Independent Test**: Replaying the stored points gives exactly the same snowboarding metrics and
segments as the incremental computation before the "kill".

### User Story 3 - Live screen at a glance (Priority: P2)

Current speed is the big number. A status chip shows Riding, On lift or Resting. Tiles show
runs, vertical drop, max speed, average speed, ride distance and elapsed time. The map shows the
route so far, runs in the accent colour and lifts muted. The footer (Pause/Resume, Lock, hold to
Finish) is unchanged.

### User Story 4 - Review the day (Priority: P2)

Tapping a tracked snowboarding day in History opens the Activity detail screen: the map with
runs and lifts coloured differently, the day totals, a bar showing the share of ride / lift /
rest time, and a timeline listing each run (number, start time, duration, vertical drop,
distance, max speed) and each lift (start time, duration, vertical gain).

### User Story 5 - Speed heatmap and map styles (Priority: P3)

On the detail screen the runs are coloured by speed, from slow to fast, with a small legend
showing the scale in km/h; lifts stay muted. A style button switches the map between Dark,
Winter and Satellite. The choice is remembered.

**Independent Test**: A stored day with known per-point speeds renders run sections whose colours
follow the speeds; switching style changes the tile source and persists across app restarts.

### User Story 6 - Compare runs and see the best ones (Priority: P3)

Below the timeline a "Compare runs" view lists every run with bars for one chosen metric (max
speed, average speed, vertical drop, distance or duration), sortable by that metric or by time.
The fastest run, the longest run and the run with the most vertical carry a badge in the
timeline and in the comparison. The totals also show the highest and lowest altitude of the day
and the longest run.

**Independent Test**: For a fixture day with three different runs, each badge lands on the
expected run and sorting by each metric gives the expected order.

### User Story 7 - Replay a run (Priority: P3)

Tapping a run in the timeline opens a replay: the map fits that run, a marker travels along it,
and a readout shows speed, altitude and time into the run. Controls: play / pause, a scrubber
and 1× / 4× / 16× speed. Runs with a badge are one tap away ("Replay fastest run").

**Independent Test**: For a stored run, the replay position at a given time equals the
interpolated point between the two stored route points around that time, and the readout shows
the interpolated speed.

### Edge Cases

- A descent of less than 30 m of drop (traversing to a lift, a short slide) counts as ride time
  and distance but is not a run.
- Fixes with accuracy worse than 20 m or implying more than 45 m/s are ignored.
- A gap without accepted fixes (tunnel, gondola cabin, lost signal) of more than 10 s counts as
  rest unless it lies inside a lift, where it stays lift.
- A fix without altitude does not change the state.
- Known limits, accepted for this version: riding a gondola down counts as a run; a slow uphill
  walk counts as rest; a very flat conveyor lift may count as rest.
- A whole day (8 h, ~29,000 fixes) must stay responsive: the live route is thinned before it is
  drawn.
- Manual snowboarding entries and entries synced from an older app version have no snowboarding
  metrics; every screen shows them as before.
- Editing a tracked snowboarding day allows date and note only; the type cannot change.
- Only one live session at a time (unchanged, FR-008 of feature 010).
- With no map key or no network every style falls back to the route drawn on a plain background;
  the heatmap and the replay still work.
- A day with a single run shows no "Compare runs" view; badges need at least two runs.
- Replay of a run shorter than two route points is not offered.

## Requirements *(mandatory)*

- **FR-001**: Snowboarding MUST be offered for live tracking wherever running and cycling are
  (start hub, Log activity sheet, setup screen), and MUST accept an optional manual distance.
- **FR-002**: Each accepted fix MUST be classified as run, lift or rest by pure, tested domain
  code with no user input; the result MUST be identical when replayed from stored points.
- **FR-003**: The session MUST report: ride, lift and rest time; ride distance; vertical drop;
  run count; current speed (about 5 s window), average speed (ride distance ÷ ride time) and max
  speed (spike-filtered, runs only).
- **FR-004**: Auto-pause MUST be off for snowboarding; manual pause MUST exclude time and
  movement from all metrics and from classification.
- **FR-005**: Saving MUST create one `activities` row (source `gps`) with ride distance, duration,
  ride time, vertical drop, run count, max speed, lift time, rest time, the simplified route and
  the segment list, and delete the raw points, in one transaction.
- **FR-006**: The route MUST be simplified per segment so each segment maps to a contiguous slice
  of the stored route.
- **FR-007**: The new fields MUST sync like the other activity fields (owner-only, last write
  wins) and MUST be optional so older clients and manual entries keep working.
- **FR-008**: History rows, the finish sheet and the Activity detail screen MUST show the
  snowboarding metrics for tracked snowboarding days; the detail map MUST distinguish runs from
  lifts.
- **FR-010**: Each stored run MUST keep, for every route point, the speed there and the time
  since the run began, and every segment its start and end altitude, so the heatmap, the replay
  and the altitude stats work after the raw points are deleted.
- **FR-011**: The detail map MUST colour runs by speed with a legend, and MUST offer Dark,
  Winter and Satellite styles from the configured tile provider, remembering the last choice on
  the device.
- **FR-012**: The detail screen MUST offer a run comparison (five metrics, sortable), badges for
  the fastest, longest and most-vertical run, and the day's highest and lowest altitude and
  longest run.
- **FR-013**: Each run MUST be replayable in 2D with play / pause, scrubbing and three speeds,
  showing speed, altitude and time.
- **FR-009**: Everything in feature 010 that is not sport-specific (permission flow, foreground
  service, 5 s persistence, provider fallback, recovery, one live session, location privacy)
  MUST apply unchanged.

## Success Criteria *(mandatory)*

- **SC-001**: On the synthetic ski-day fixtures: run count exact; vertical drop, ride / lift /
  rest seconds and max speed within 5% of the reference.
- **SC-002**: A lift is shown as "On lift" within 60 s of leaving the bottom station; a run is
  shown as "Riding" within 15 s of setting off.
- **SC-003**: Replay equals incremental for every fixture (same metrics, same segments).
- **SC-004**: An 8-hour day stores a route of ≤ 400 KB and a segment list of ≤ 100 KB; the live
  screen never draws more than 2,000 route points.
- **SC-006**: The replay plays at 16× without dropped frames on the owner's phone; opening the
  detail screen of an 8-hour day takes under one second.
- **SC-005**: Format, analyze and all tests green; SQL tests green; one real day on the mountain
  validated by the owner (run count matches what they rode).

## Out of scope

Barometer altitude; resort, piste and lift names (lift identification); piste maps; 3D maps and
3D replay; heart rate overlay and fitness insights; friends and live location; skiing as a
separate type; GPX export or import; miles and feet; offline tile download; season or lifetime
statistics across days.
