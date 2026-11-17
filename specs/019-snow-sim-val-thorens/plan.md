# Implementation Plan: Simulated Snowboarding Session on Val Thorens

**Branch**: `019-snow-sim-val-thorens` | **Date**: 2026-11-16 | **Spec**: [spec.md](./spec.md)

## Summary

A deterministic 1 Hz snowboarding session built from real Val Thorens lift lines, pistes and terrain
heights becomes (a) a test fixture for the feature 017 engine and (b) a dev-only simulated GPS source
for the running app. The simulation plugs in at the `LocationSource` seam and overrides `clockProvider`
with a virtual clock, so the app can replay the session at 1×–30× while elapsed time, the reducers
and the stored activity stay consistent. `TrackingController` and the detection code are not changed.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)

**New dependencies**: none (tools use `dart:io` and `dart:convert`).

**Storage**: none new. The session CSV is a generated Dart `const String`.

**Testing**: fixture through `track_reducer` + `snow_reducer`; CSV parser; `TrackSimulation`;
`SimulatedLocationSource` through the real `TrackingController` with an in-memory database; widget
test for the bar; e2e variant.

**Constraints**: offline generation; byte-identical output for the same seed; no data or code from
this feature reachable in a release build.

## Dataset

| Item | Content |
|---|---|
| `tool/val_thorens/fetch_geometry.dart` | Overpass API (OSM ways: lifts, pistes) and Géoplateforme altimetry (IGN RGE ALTI) every 12 m along them. Public coordinates only, generic User-Agent. Writes `geometry.json` |
| `tool/val_thorens/geometry.json` | Committed result; generation is offline and deterministic |
| `tool/val_thorens/README.md` | Sources, licences, attribution: © OpenStreetMap contributors (ODbL 1.0); IGN RGE ALTI (Licence Ouverte / Open Licence 2.0) |
| `tool/gen_val_thorens_session.dart` | Seeded generator: geometry → 1 Hz session CSV, reference totals, optional `--gpx <path>` |
| `lib/data/tracking/sim/val_thorens_session.dart` | Generated; one `const String` with the CSV text |

Legs (real OSM ways):

| Leg | From → to |
|---|---|
| Boismint chairlift | 2075 → 2664 m |
| Run 1: piste Boismint, Blanchot link, Boulevard Boismint | 2664 → 2103 m (Caron gondola base) |
| Caron gondola | 2103 → 2315 m |
| Cime Caron cable car | 2316 → 3178 m |
| Run 2: Col de l'Audzin, then Gentiane | 3178 → 2075 m (Boismint base) |

Script: rest at the base, chairlift, short stand at the top, run 1, break at the Caron base,
gondola, short walk between stations at the Caron mid station, cable car, run 2 with one stop
mid-run, final rest. Speed depends on slope, with carving turns; lifts move at steady line speed
with slow-downs at the stations; cable-car altitude follows the cable, not the terrain. Noise is
slowly drifting (correlated), not white. Output format: the existing fixture CSV
(`t_ms,lat,lon,alt,accuracy,speed`, `# key=value` metadata) plus reference totals (runs, ride / lift
/ rest seconds, vertical drop, ride distance, max speed) from the noise-free truth.

Why a Dart `const String` and not an asset: tests and app load exactly the same bytes; a release
build tree-shakes it away because the only reference is behind a compile-time-false guard, so no
ODbL-derived data and no extra weight ship to users; no asset plumbing. The parser moves to
`lib/data/tracking/track_csv.dart`; the test helper `track_fixtures.dart` delegates to it.

Altitude is terrain height above sea level; phones report ellipsoid height. Only differences are
used, so this does not matter.

## Simulation

### Wiring

```text
main(): simulation = kSimulateGps ? valThorensSimulation()..start() : null   // const: SIMULATE_GPS && !kReleaseMode
  AppDatabase.open(clock: simulation?.now)      // saving validates dates on the database clock
  overrides (simulationOverrides):
    simulationProvider     -> simulation        (null in a normal build)
    locationSourceProvider -> SimulatedLocationSource(simulation)
    clockProvider          -> simulation.now
  driveSimulation(container, simulation)        // lib/features/tracking/simulation_driver.dart
    TrackingLive with a new session id  -> simulation.startReplay(id)
    TrackingIdle / TrackingFinished     -> simulation.park()
```

The driver lives in `lib/features/tracking/` because it listens to `trackingControllerProvider`;
`lib/data/` must not import features (principle IV).

`TrackingController` reads the same providers as before and does not know about the simulation.

### Clock design

`TrackSimulation` owns a virtual clock and the playhead.

- Before a replay: virtual time = real time.
- `start()` records the anchor `(realAnchor, virtualAnchor, playheadAnchor)`. After that
  `virtualNow = virtualAnchor + (realNow − realAnchor) × speed`, and the playhead (fixture time) is
  `playheadAnchor + (realNow − realAnchor) × speed`.
- `setSpeed(s)` first re-anchors at the current instant, then changes `speed`; so the clock never
  jumps and never goes backwards.
- Fix timestamps are the virtual clock time at which the row's fixture time is reached, so fixes,
  `clockProvider`, elapsed time, pace and the stored activity share one timeline at any speed.
- The source emits each row when the playhead passes it (timer driven; at 30× several rows can be
  due in one tick, they are emitted in order).
- After the last row: last position again each second at 1× (watchdog quiet).
- Parked: first position once a second; `park()` re-anchors so the clock keeps going, speed back to
  the selected value, playhead to 0.

### Switch

`kSimulateGps = bool.fromEnvironment('SIMULATE_GPS') && !kReleaseMode`, one `const` in a small file
(read like `MAP_TILES_KEY`), with a helper `simulationEnabled(define, release)` for the test. Run:
`flutter run --dart-define-from-file=env/dev.json --dart-define=SIMULATE_GPS=true`.

### UI

`SimulationBar` ("SIMULATED GPS", speed chips 1× 5× 10× 30×, progress) on the setup screen and the
live screen, shown only when `kSimulateGps`. It reads and sets the speed through
`simulationProvider`. Colours and spacing from theme tokens; Semantics on the chips.

### Limitation

A simulated session is saved like any other activity (and synced if signed in). The developer
deletes it afterwards.

## Alternative considered: Android emulator GPX / KML route playback

| | Emulator route playback | In-app simulation (chosen) |
|---|---|---|
| Exercises geolocator plugin and foreground service | yes | no |
| Speed up | positions accelerate but time stays real: 5× looks like 5× speed, fixes above 45 m/s are rejected, segments misclassified | virtual clock: time and positions speed up together |
| Accuracy and Doppler speed | not controllable | from the fixture |
| Manual GUI steps | yes | none |
| CI | no | yes (tests) |
| Physical phone | no | yes (dev build) |

Chosen: in-app simulation as the main path; the GPX export is kept for 1× platform-level checks.

## Files

| File | Change |
|---|---|
| `tool/val_thorens/fetch_geometry.dart`, `geometry.json`, `README.md` | new |
| `tool/gen_val_thorens_session.dart` | new |
| `lib/data/tracking/track_csv.dart` | new: parser moved from the test helper |
| `lib/data/tracking/sim/val_thorens_session.dart` | new, generated |
| `lib/data/tracking/sim/track_simulation.dart` | new: virtual clock, playhead, parked / playing / ended |
| `lib/data/tracking/sim/simulated_location_source.dart` | new: `LocationSource` implementation |
| `lib/data/tracking/sim/simulation_switch.dart` | new: `kSimulateGps`, `simulationEnabled` |
| `lib/data/providers.dart` | `simulationProvider` (null by default) |
| `lib/data/db/app_database.dart` | `open({clock})`, so the database follows the simulation clock |
| `lib/features/tracking/simulation_driver.dart` | new: `valThorensSimulation`, `simulationOverrides`, `driveSimulation` |
| `lib/main.dart` | overrides under `kSimulateGps` only |
| `lib/features/tracking/widgets/simulation_bar.dart` | new |
| setup screen, live screen | show the bar when enabled |
| `test/domain/tracking/track_fixtures.dart` | delegates to `track_csv.dart` |

`TrackingController` and everything in `lib/domain/` stay unchanged.

## Tests

| Test | Covers |
|---|---|
| `test/domain/tracking/val_thorens_fixture_test.dart` | track + snow reducers: runs == 2, ride / lift / rest, distance, drop, max speed within 5%; replay equals incremental; lift spans cover the three lifts |
| `test/data/tracking/track_csv_test.dart` | parser, metadata, bad rows |
| `test/data/tracking/sim/track_simulation_test.dart` | clock monotonic, speed changes without a jump, parked fixes, ordering, end hold |
| `test/data/tracking/sim/simulation_switch_test.dart` | define and release combinations |
| `test/features/tracking/simulated_tracking_test.dart` | `SimulatedLocationSource` through the real `TrackingController`, in-memory database, high speed: live state shows lifts / runs, final summary matches the reference |
| `test/features/tracking/simulation_bar_test.dart` | bar only when enabled; speed chips change speed |
| `test/e2e/gps_flow.dart` | Val Thorens variant of `runSnowFlow` ("2 runs" in History) |

Gates: `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`.

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline-first: generator and app need no network; no schema change | ✅ |
| II. Pure domain: no domain change; the fixture exercises it | ✅ |
| III. Tests first for the parser, clock and source; gates listed above | ✅ |
| IV. Simulation lives in `data/`; widgets use providers; no package added; theme tokens for the bar | ✅ |
| V. Dev-only bar, not part of the user UI; controls 48 dp with Semantics | ✅ |
| VI. The bundled mock route is public open data with no user fixes; nothing leaves the device (the fetch tool is a dev script sending public coordinates only); no secrets; define passed like `MAP_TILES_KEY` | ✅ |
| VII. Owner request 2026-11-16; dev tooling for an in-scope feature; no new user-facing capability. The GPX export is a dev tool output, not an app feature | ✅ |

No constitution change needed.

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| Generated Dart file with the session CSV (ODbL-derived data in the repo) | One byte-identical source for tests and app, tree-shaken from release builds | A Flutter asset ships in every build and needs asset plumbing |
| Virtual clock overriding `clockProvider` | Faster replay without breaking elapsed time and the 45 m/s filter | Emulator playback speeds up positions only |

## Findings

Measured on the Val Thorens session (default `SnowTuning`), `test/domain/tracking/val_thorens_fixture_test.dart`
and `test/features/tracking/simulated_tracking_test.dart`.

**Totals: pass.** 2 runs (exact). Against the noise-free reference: ride 924 s / 956 s, lift
858 s / 854 s, rest 742 s / 714 s, ride distance 8,802 m / 8,851 m, vertical drop 1,658 m /
1,687 m, max speed 16.5 / 17.2 m/s; all within 5%. The three lifts measure 589 m, 208 m and
844 m of gain (real: 589, 213, 862). Without Doppler speed the totals stay within 5% as well.
Replay equals incremental, also when resumed half-way. 1×, 5×, 10× and 30× replays through the
real controller give identical days.

**1. A run that starts on a flat traverse is shown late on the live screen.** Both pistes start
with about 40 s of near-level riding at 2.5–6 m/s (the Blanchot link off the Boismint chair, the
Col de l'Audzin ridge below Cime Caron). Off a lift a run is confirmed only by
`runConfirmDrop` (10 m of net drop), so the chip says "On lift" for 49 s and 63 s after the
rider set off (017's SC-002 aims at 15 s). Totals are unaffected: the run is backdated.
Lowering `runConfirmDrop` to 6 m brings it to 36 s and 31 s with identical totals on this
session and on the synthetic `plainDay` and `longDay` scenarios. *Proposal (not applied):*
`runConfirmDrop: 6`, after checking a real chairlift ride for dips between towers, which this
threshold also guards against. The rest of the delay is inherent: nothing distinguishes a flat
traverse from a level stretch of cable until height is lost.

**2. A fast, level lift departure shows "Riding" for 7 s.** The Cime Caron cable car leaves the
mid station at up to 8 m/s while the 15 s altitude median and the 30 s climb rate lag behind
the climb. Coming from a rest, a run is confirmed after `runConfirm` (10 s) and
`runConfirmMeters` (60 m), so fixes 1470–1477 show a run before the lift is confirmed;
`falseRun` then folds it into the lift and the totals are right. *Proposal (not applied):*
`runConfirmMeters: 120` (or `runConfirm: 20 s`): removes the flicker with identical totals,
at the cost of showing a run again 6–10 s later after a stop on the slope. Pinned by the test
"known limit: the cable car start shows a run for under 10 s", which fails on purpose when the
tuning changes.

**3. Lift → mid-station walk shows "On lift" for 134 s**, by design (`liftRestConfirm` 120 s
keeps a stopped chairlift a lift). A 1.2 m/s walk is between `restMaxSpeed` and `runMinSpeed`
and gets no label. No change proposed.

**4. Simulation wiring issue found and fixed.** Saving a simulated session failed with "startedAt
is in the future": `TrackingRepository.finish` validates the date on the database clock, which
stayed the wall clock while the app clock ran ahead. The database now takes the simulation
clock too (`AppDatabase.open(clock:)`).

**5. Release builds cannot simulate.** Built with `--dart-define=SIMULATE_GPS=true` for
android-arm64: the release `libapp.so` (10.2 MB) contains none of `reference_runs`,
`Boismint_chairlift`, `SIMULATED GPS`, `waiting at Boismint`; the profile build of the same
source (control, not `kReleaseMode`) contains all four and is 3.6 MB larger.

**On screen (Android emulator, 2026-11-17).** Pixel 7 AVD, Android 15 (API 35, Google APIs,
arm64), debug APK built with `--dart-define-from-file=env/dev.json --dart-define=SIMULATE_GPS=true`,
driven with `adb`. Seen:

- Setup: the bar, "GPS ready (±6 m)", the dot parked at the Boismint base on MapTiler tiles of Val
  Thorens. No location permission prompt (the simulated source grants it).
- 1×: after 50 s the bar shows 0:50 / 42:04 and Elapsed 0:50; "Resting" at the base as scripted.
- 10×: 4:38 into the session, "On lift" at 17.9 km/h, grey lift line up the Boismint chair.
- 30×: run 1 "Riding" with the green route (1 run, 440 m); run 2 "Riding" (2 runs); at the end
  "session over", "Resting", 2 runs, 1,658 m, 8.80 km, max 59.5 km/h, the same numbers as the
  tests. Speed changes took effect at once with no jump in Elapsed.
- Finish: the summary sheet with the whole day on tiles, the ride / lift / rest bar; Save worked
  (the database clock follows the simulation clock) and History shows "Snowboarding · 2 runs ·
  1,658 m ↓ · 43 min" with the route thumbnail. No Flutter errors in logcat.
- Opening Snowboarding again: parked at the base, the chosen 30× kept.
- Fixed after this run: the bar's parked text was cut off at 1080 px ("waiting at Boi…"); it now
  reads "Val Thorens · at the base".

Not covered: the geolocator plugin and the foreground service (the simulation replaces them by
design; the GPX route playback in the README is the way to exercise them at 1×), and a physical
phone.

**Rendered in tests.** Before the emulator was installed, the real `FitApp` widget tree was rendered with the
simulation running at 30× (Roboto loaded, map tiles off so the route painter draws) at seven
points of the session: setup (parked, GPS ready ±6 m), Boismint chair ("On lift", grey lift
line), run 1 ("Riding", green route with turns), Caron break, cable car ("On lift" 29.8 km/h),
run 2, and the end (2 runs, 1,658 m, 8.80 km, max 59.5 km/h, "Resting", elapsed 42:06 for a
42:04 track). Tile rendering was then confirmed on the emulator (above).
