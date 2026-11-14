# Feature Specification: Live GPS Tracking for Running and Cycling

**Feature Branch**: `010-live-gps-tracking`

**Created**: 2026-11-14

**Status**: Draft

**Input**: Owner approval (2026-11-14) of [docs/proposals/live-tracking.md](../../docs/proposals/live-tracking.md)
for running and cycling: "record runs and rides live with GPS and save distance, route, pace and
duration automatically instead of manual entry". Snowboarding is excluded (separate feature later).

## Clarifications

### Session 2026-11-14

- Q: Which activities? → A: **Running and Cycling** only. Snowboarding is a later feature.
- Q: Map or no map? → A: A **real map inside the app** (not an external maps app), OpenStreetMap
  based, dark style, via a tile provider (MapTiler) with an API key from the git-ignored
  `env/dev.json`. Without network or without a key the route is drawn on a plain dark background.
- Q: Keep raw GPS points after finishing? → A: **No.** Keep a simplified route only; raw points are
  deleted when the session is saved or discarded.
- Q: Import from watches (Health Connect)? → A: **Not now.**
- Q: Where does it start? → A: The existing **Log activity** sheet: picking Running or Cycling shows
  **Start live** (primary) and the existing manual form below it.
- Q: Units? → A: km and km/h, min/km (kg/km-only rule).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Record a run live (Priority: P1)

The user opens Log activity, picks Running, taps Start live, waits for "GPS ready", taps Start and
runs with the phone locked. The notification shows time and distance. After 28 minutes they open
the app, tap Finish (hold), see the summary with a map of the route and save. History shows
"Running · 5.2 km · 28 min · 5:23 /km" with a route thumbnail.

**Independent Test**: With a fake location source replaying a 5 km GPX fixture, start, finish and
save: an activity is stored with source `gps`, distance within 1% of the fixture's, duration,
moving time, a simplified route and per-km splits; the raw points are gone.

**Acceptance Scenarios**:

1. **Given** location permission is not granted, **When** Start live is tapped, **Then** a short
   rationale is shown before the OS prompt; if denied, the user is offered settings or the manual form.
2. **Given** the setup screen, **When** no accurate fix yet, **Then** it shows "Searching for GPS"
   with an accuracy indicator; Start is available once accuracy ≤ 20 m, plus a "Start anyway" option.
3. **Given** a live session, **When** the screen is locked or the app is in the background,
   **Then** tracking continues and a persistent notification shows elapsed time and distance.
4. **Given** a live session, **When** Pause is tapped, **Then** time and distance stop counting
   until Resume; auto-pause does the same when the user stands still (running ≥ 10 s, cycling ≥ 5 s).
5. **Given** Finish, **Then** it requires a 1-second hold; the summary sheet offers Save and Discard
   (Discard asks to confirm).

### User Story 2 - Crash-safe session (Priority: P1)

The phone kills the app mid-run. When the user opens FitApp again, it returns to the live screen
with time and distance intact (at most the last ~5 s lost) and tracking resumes.

**Independent Test**: Persist points, recreate the controller from the database, and get the same
distance and elapsed time as before the "kill".

### User Story 3 - Review a tracked activity (Priority: P2)

Tapping a GPS activity in History opens an Activity detail screen: an interactive map (pan/zoom)
with the route, start and finish markers and km markers, the summary metrics and a per-km splits
list. Edit allows type, date and note (not GPS metrics); Delete asks to confirm.

### User Story 4 - Live screen at a glance (Priority: P2)

Running shows elapsed time big, then distance, current pace, average pace and the last km split;
cycling shows current speed big, then distance, average speed, elapsed time and climb. The route
is drawn on the map live. A fixed footer holds Pause/Resume, Lock and Finish.

### Edge Cases

- Only one live session at a time: starting live tracking while a gym workout is in progress (or
  the reverse) shows a message with a button to open the one in progress.
- Fixes with accuracy > 20 m or implying impossible speed (running > 12 m/s, cycling > 30 m/s) are ignored.
- Very short sessions (< 1 min or < 50 m) can be saved only after a confirmation.
- No network: map tiles don't load; the route is drawn on a dark background; everything else works.
- No map key configured (e.g. CI, tests): same as no network.
- Location services switched off mid-session: the session pauses with a banner until they return.

## Requirements *(mandatory)*

- **FR-001**: Live tracking MUST be offered for activity types with `hasLiveTracking` (running, cycling).
- **FR-002**: Tracking MUST continue with the screen off via an Android foreground service
  (iOS: background location mode), using "while in use" permission only.
- **FR-003**: Every accepted GPS point MUST be persisted within ~5 s (batched) so a killed app
  loses at most a few seconds.
- **FR-004**: Metrics (distance, elapsed, moving time, current/average pace or speed, per-km
  splits, elevation gain) MUST be computed by pure, tested domain code that can be replayed from
  stored points.
- **FR-005**: Saving MUST create one `activities` row (source `gps`, distance, duration, moving time,
  elevation gain, simplified route, splits) and delete the raw points, in one transaction.
- **FR-006**: History MUST show GPS activities with a route thumbnail (drawn locally, no tiles) and
  open the Activity detail screen.
- **FR-007**: Maps MUST use the configured tile provider key from `--dart-define-from-file`; no key
  in the repo; with no key or no network the route is drawn on a plain background.
- **FR-008**: Only one live session (gym workout or tracked activity) may exist at a time.
- **FR-009**: Location data MUST stay on the device (only map tile requests go to the provider).

## Success Criteria *(mandatory)*

- **SC-001**: Distance from replaying reference GPX fixtures is within 1% of the reference.
- **SC-002**: From the Train tab to tracking: ≤ 4 taps once GPS is ready.
- **SC-003**: A forced app kill loses ≤ 5 s of track.
- **SC-004**: An hour of tracking stores a route of ≤ 50 KB after simplification.
- **SC-005**: Format, analyze and all tests green; on-phone 30-minute run validated by the owner.

## Out of scope

Snowboarding, Health Connect/HealthKit import, miles, GPX export, offline tile download, audio
cues, heart-rate sensors, segments/social.
