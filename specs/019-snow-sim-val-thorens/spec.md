# Feature Specification: Simulated Snowboarding Session on Val Thorens

**Feature Branch**: `019-snow-sim-val-thorens`

**Created**: 2026-11-16

**Status**: Draft

**Input**: Owner request (2026-11-16): "test the live snowboarding tracking (feature 017) away from a
ski resort: simulate a session on real Val Thorens geography, so run / lift / rest detection,
vertical drop and the map can be checked without being on the mountain."

## Clarifications

### Session 2026-11-16

- Q: Which geography? → A: **Real Val Thorens (France)**: real OpenStreetMap lift and piste lines,
  real IGN terrain heights. No invented terrain.
- Q: How does the session reach the app? → A: Through the existing `LocationSource` seam, in a
  **dev-only simulation mode**. `TrackingController` is not changed.
- Q: Can the session run faster than real time? → A: Yes, 1×, 5×, 10× and 30×, switchable while it
  plays. A virtual clock keeps elapsed time, pace and stored activities consistent at any speed.
- Q: Where is the session data kept? → A: As a generated Dart file with one `const String` (the CSV
  text), not as a Flutter asset. A release build tree-shakes it away.
- Q: Does a simulated session count as a real activity? → A: It is saved like any other activity
  (known limitation, see Edge Cases); the developer deletes it afterwards.
- Q: Do detection thresholds change? → A: **No**, unless the tests show a weakness on the real
  geometry; then it is reported with evidence and a `SnowTuning` change is proposed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Automated regression on real terrain (Priority: P1)

A developer runs `flutter test`. The Val Thorens fixture goes through the same reducers as a real
day (`track_reducer`, `snow_reducer`) and through the real `TrackingController`, and the results
are compared with reference totals computed from the noise-free route.

**Independent Test**: The fixture gives exactly 2 runs; ride, lift and rest seconds, ride distance,
vertical drop and max speed are within 5% of the reference totals; replay equals incremental; the
lift spans cover the three lifts (Boismint, Caron gondola, Cime Caron cable car).

**Acceptance Scenarios**:

1. **Given** the fixture, **When** it is reduced fix by fix, **Then** run count is 2 and each total
   is within 5% of the reference in the CSV metadata.
2. **Given** the fixture, **When** it is replayed from the accepted fixes, **Then** the metrics and
   segments equal the incremental result.
3. **Given** a `SimulatedLocationSource` driven at high speed through a `TrackingController` with an
   in-memory database, **When** the session is finished, **Then** the snow summary matches the
   reference and the live state showed lifts and runs on the way.

### User Story 2 - Watch the live screen replay the session (Priority: P2)

The developer starts the app with `flutter run --dart-define-from-file=env/dev.json
--dart-define=SIMULATE_GPS=true`, picks Snowboarding and sees a "SIMULATED GPS" bar. On the setup
screen the GPS is "ready" at the Boismint base. Tapping Start begins the replay: the status goes
On lift, Riding, Resting, and the map draws the route. The bar switches speed between 1×, 5×, 10×
and 30× and shows progress. Finishing or discarding returns the source to the parked position.

**Independent Test**: Widget test: the bar is absent when the mode is off, present when on, and
tapping a speed changes the speed of the simulation.

**Acceptance Scenarios**:

1. **Given** the mode is on and no session is recording, **Then** the source emits the first
   position once a second and the bar shows 1× and 0% progress.
2. **Given** a recording starts, **Then** the replay starts from the first row and the bar shows
   progress.
3. **Given** the speed is changed while playing, **Then** the virtual clock and the fixes speed up
   without a jump and never go backwards.
4. **Given** the last row has been played, **Then** the last position keeps coming at 1× and the
   no-fix watchdog stays quiet.
5. **Given** the mode is off (default) or the build is a release build, **Then** no bar, no
   simulated source and no override exist.

### User Story 3 - Platform check with GPX on the emulator (Priority: P3)

The generator can write the same route as a GPX file. The developer loads it in the Android
emulator's route playback at 1× to check the real geolocator plugin and foreground service.

**Independent Test**: The GPX has the same number of points as the CSV, with times, and loads in the
emulator; the app shows the same lifts and runs as the in-app simulation at 1×.

### Edge Cases

- Altitude in the fixture is terrain height above sea level (IGN); phones report ellipsoid height.
  This does not matter because the snow reducer only uses differences.
- The cable car altitude follows the cable, not the terrain, so it differs from the terrain
  elevation along that line.
- The replay (and the fixture) contains a stop mid-run: it counts as rest, run count stays 2.
- A short walk between stations at the Caron mid station must not start a run.
- Fixes with the real accuracy filter (20 m) and 45 m/s limit still apply; the simulation does not
  bypass `track_reducer`.
- At 30× the virtual clock runs 30× faster, so no fix implies more than 45 m/s.
- If a release build is made with `--dart-define=SIMULATE_GPS=true`, the mode stays off
  (`!kReleaseMode` is part of the compile-time constant).
- A simulated session is saved like any other activity and synced if cloud backup is signed in.
  Known limitation: the developer deletes it afterwards.
- Changing the speed, finishing or discarding while the app is in the background is not specified
  beyond "the clock never goes backwards".
- After an accelerated replay the app clock stays ahead of the wall clock by the time saved (about
  40 min for a whole session at 30×) until the app restarts; it never goes backwards.
- If the app is killed mid-replay, recovery resumes the stored session but the replay restarts from
  the first fix, so the recovered route jumps back to the base. Dev-only; not handled.

## Requirements *(mandatory)*

- **FR-001**: `tool/val_thorens/fetch_geometry.dart` MUST download the lift lines and pistes from
  OpenStreetMap (Overpass API) and terrain elevations every 12 m along them from IGN RGE ALTI
  (Géoplateforme altimetry service), sending only public coordinates and a generic User-Agent, and
  write `tool/val_thorens/geometry.json`, which is committed.
- **FR-002**: The legs MUST be real OSM ways: Boismint chairlift (2075 → 2664 m); run 1 down piste
  Boismint via the Blanchot link and Boulevard Boismint to the Caron gondola base (2664 → 2103 m);
  Caron gondola (2103 → 2315 m); Cime Caron cable car (2316 → 3178 m); run 2 down Col de l'Audzin
  then Gentiane back to the Boismint base (3178 → 2075 m).
- **FR-003**: `tool/gen_val_thorens_session.dart` MUST work offline, be seeded and deterministic,
  and produce a 1 Hz session: rest at the Boismint base, chairlift, short stand at the top, run 1, a
  break at the Caron base, gondola, a short walk at the Caron mid station, cable car, run 2 with one
  stop mid-run, final rest at the base. Speed follows slope with carving turns; lifts move at
  steady line speed with station slow-downs; cable car altitude follows the cable; noise is slowly
  drifting, not white.
- **FR-004**: The output MUST keep the existing fixture CSV format (`t_ms,lat,lon,alt,accuracy,speed`
  and `# key=value` metadata) with reference totals in the metadata (runs, ride / lift / rest
  seconds, vertical drop, ride distance, max speed) computed from the noise-free truth.
- **FR-005**: The generator MUST export a GPX with `--gpx <path>`.
- **FR-006**: The CSV MUST be committed embedded in the generated
  `lib/data/tracking/sim/val_thorens_session.dart` (one `const String`), not as an asset. The parser
  MUST live in `lib/data/tracking/track_csv.dart`; `test/domain/tracking/track_fixtures.dart`
  delegates to it.
- **FR-007**: `SimulatedLocationSource` (implements `LocationSource`) and `TrackSimulation` (virtual
  clock and playhead) MUST provide the fixes; `TrackingController` MUST NOT change.
- **FR-008**: `clockProvider` MUST be overridden with the simulation's virtual clock. The clock
  equals the real clock until a replay starts, then advances `speed` times faster; it never jumps
  and never goes backwards. Fix timestamps are fixture time on that clock. The database clock
  (used to validate saved dates) MUST follow the same clock.
- **FR-009**: Before recording starts the source MUST emit the first position once a second
  ("parked"). The replay MUST start when the tracking controller goes live with a new session id and
  return to parked when the session is finished or discarded. After the last row the source MUST
  keep emitting the last position at 1×.
- **FR-010**: The speeds MUST be 1×, 5×, 10× and 30×, switchable while playing from a "SIMULATED
  GPS" bar on the setup and live screens, only when the mode is on. The bar MUST show progress.
- **FR-011**: The mode MUST be enabled by `--dart-define=SIMULATE_GPS=true` combined with
  `!kReleaseMode` in one compile-time constant; the two provider overrides in `main()` MUST be
  added only under that constant, so a release build tree-shakes the session data.
- **FR-012**: Tests MUST cover the fixture through the reducers, the parser, `TrackSimulation`, the
  compile-time switch helper, the controller with `SimulatedLocationSource`, the bar, and an e2e
  Val Thorens variant of `runSnowFlow` ("2 runs" in History).
- **FR-013**: `tool/val_thorens/README.md` MUST record the sources, licences and attribution:
  "© OpenStreetMap contributors" (ODbL 1.0) and IGN RGE ALTI (Licence Ouverte / Open Licence 2.0).
- **FR-014**: No new package dependency.
- **FR-015**: Any detection weakness found on the real geometry MUST be reported with evidence and
  a proposed `SnowTuning` change; the fixture MUST NOT be adjusted to fit.

## Success Criteria *(mandatory)*

- **SC-001**: On the Val Thorens fixture: run count exactly 2; ride, lift and rest seconds, ride
  distance, vertical drop and max speed within 5% of the reference.
- **SC-002**: Replay equals incremental; the lift spans cover the three lifts.
- **SC-003**: The controller test at high speed ends with a snow summary matching the reference.
- **SC-004**: Generating twice gives byte-identical output; generation needs no network.
- **SC-005**: A release build contains neither the session data nor the simulation bar
  (compile-time switch test).
- **SC-006**: Format, analyze and all tests green; the session was run once in an emulator and what
  was seen is recorded.

## Out of scope

A real ski-day recording; iOS simulator specifics; changing detection thresholds unless evidence
demands it; simulating other activity types; other resorts; a user-facing simulation mode; any
change to `TrackingController`; GPX import or export in the app itself.

## Assumptions

- The route is public open data (OSM and IGN) and contains no user fixes; the generator is offline;
  the fetch tool sends only public coordinates (constitution VI).
- Overpass and Géoplateforme stay available long enough to run the fetch tool once; after that
  `geometry.json` is the source.
- The existing fixture CSV format is enough for the new session.
- Terrain height (IGN) and phone ellipsoid height differ by a constant offset per place, which the
  reducer ignores.
