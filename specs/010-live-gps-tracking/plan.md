# Implementation Plan: Live GPS Tracking for Running and Cycling

**Branch**: `010-live-gps-tracking` | **Date**: 2026-11-14 | **Spec**: [spec.md](./spec.md)

## Summary

A pure-Dart **track reducer** (`lib/domain/tracking/`) folds GPS samples into metrics and is
replayable from stored points. A `TrackingController` (Riverpod `Notifier`) subscribes to a
`LocationSource` interface (`geolocator` implementation as an Android foreground service; a fake
for tests), feeds the reducer, and batches points to a `TrackingRepository` (drift schema v6).
Finishing writes one `activities` row with a simplified route and splits and deletes raw points.
UI: Start live in the Log activity sheet → setup screen → full-screen live screen with an in-app
`flutter_map` (MapTiler dark tiles, key from `env/dev.json`) → finish summary → History thumbnail
and Activity detail screen.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50

**New dependencies** (latest stable at implementation time, verified maintained/null-safe):
`geolocator` (location stream, foreground service), `flutter_map` + `latlong2` (in-app map).
No paid SDKs. The map key is read with `String.fromEnvironment('MAP_TILES_KEY')`.

**Storage**: drift schema v6 — [data-model below](#data-model)

**Testing**: domain reducer with GPX/CSV fixtures (100% line coverage for `lib/domain/tracking/`);
repository (batching, finish/discard transactions, recovery); migration v5→v6; controller with
`FakeLocationSource`; widget tests (sheet Start live, setup states, live screen, finish sheet,
History row thumbnail, detail screen with tiles disabled); integration test replaying a fixture.

**Target Platform**: Android first (foreground service type `location`); iOS config included.

**Constraints**: offline-first; ≤ 5 s data loss on kill; no background-location permission;
location data never leaves the device; no key in git.

## Data model

```text
tracking_sessions (new)  id, type_id, state (active|paused), started_at, paused_ms,
                         paused_at?, updated_at, dirty          -- at most one row
track_points (new)       session_id FK, seq, t, lat, lon, alt?, accuracy_m, speed_mps?,
                         paused (bool); PK (session_id, seq)
activities (+ columns)   source TEXT NOT NULL DEFAULT 'manual'  -- 'manual' | 'gps'
                         moving_seconds INT?, elevation_gain_m INT?,
                         route TEXT?   -- encoded polyline (precision 5), Douglas-Peucker ~5 m
                         splits TEXT?  -- JSON list of seconds per full km
```

Migration `from5To6`: create both tables, add the activity columns (existing rows → `manual`).

## Domain (`lib/domain/tracking/`, pure)

| File | Content |
|---|---|
| `track_sample.dart` | `TrackSample(t, lat, lon, alt?, accuracy, speed?)` |
| `geo.dart` | haversine, encoded polyline encode/decode, Douglas-Peucker |
| `track_profile.dart` | per-type limits: max speed, auto-pause speed and delay |
| `track_state.dart` | immutable metrics: distance, elapsed, moving, splits, elevation gain, current pace/speed (30 s window), last accepted sample |
| `track_reducer.dart` | `accumulate(state, sample, profile)`, `pause/resume(state, t)`, `replay(samples)` |
| `track_summary.dart` | `summarize(state, samples)` → distance, duration minutes, moving s, gain, route, splits |

Activity registry: `ActivityType.hasLiveTracking` (running, cycling).

## Data / platform

```text
lib/data/tracking/location_source.dart       interface + LocationFix, PermissionState
lib/data/tracking/geolocator_source.dart     geolocator impl (foreground notification config)
lib/data/repositories/tracking_repository.dart  start, appendPoints (batch), pause/resume,
                                              finish (→ activities row, delete points, delete
                                              session — one transaction), discard, recover
lib/features/tracking/tracking_controller.dart  Notifier<TrackingUiState> sealed:
                                              Idle | Acquiring(accuracy) | Live(metrics, paused)
                                              | Finishing(summary); batch flush every 5 s / 20 pts
```

Providers: `locationSourceProvider` (overridden in tests), `trackingRepositoryProvider`,
`trackingControllerProvider`, `activeTrackingProvider` (stream of the session row, for the Train
banner and the one-live-session rule).

Platform config: Android `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`,
`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`; iOS `NSLocationWhenInUseUsageDescription`,
`UIBackgroundModes: location`. `env/example.json` gains `"MAP_TILES_KEY": ""`.

## UI (`lib/features/tracking/`)

| Screen | Route | Notes |
|---|---|---|
| Activity sheet | — | Running/Cycling: **Start live** button above the manual form |
| Setup | `/track/new?type=` | permission rationale, GPS accuracy chip, Start / Start anyway |
| Live | `/track/live` | hero metric + 2×2 tiles, map with live route, fixed footer Pause/Resume · Lock · Finish (hold 1 s) |
| Finish sheet | — | map fitted to route, metrics, note, Save / Discard (confirm) |
| Activity detail | `/activity/:id` | interactive map, start/finish + km markers, metrics, splits list; Edit / Delete |
| History row | — | `RouteThumbnail` (`CustomPainter`, no tiles) for GPS entries |
| Train | — | "Run in progress" banner when a session exists; app launch reopens `/track/live` |

`RouteMap` widget wraps `flutter_map`: dark MapTiler style when a key exists; otherwise a
`CustomPainter` route on the theme background. Colors from theme tokens; 56 dp footer controls;
Semantics on every control; Lock disables all controls except a hold-to-unlock.

## Constitution Check

| Principle | Status |
|---|---|
| I. Offline-first: tracking works offline, points persisted, versioned migration v6, one transaction on finish/discard | ✅ |
| II. Pure domain reducer with fixture tests | ✅ |
| III. Tests first | ✅ |
| IV. Layering; two new packages (maintained, null-safe) justified below | ✅ |
| V. Fixed footer, 56 dp, hold-to-finish, discard confirm, semantics, dark | ✅ |
| VI. Map key via `--dart-define-from-file`, `env/example.json` empty; location stays on device | ✅ |
| VII. Owner approval 2026-11-14 → amend VII (1.4.0): live GPS tracking for running/cycling in scope; snowboarding tracking, imports, GPX export still out | ✅ (amendment) |

## Complexity Tracking

| Addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| `geolocator` | Background-safe location stream with Android foreground service | Writing platform channels by hand duplicates a maintained package |
| `flutter_map` | Owner wants a real map inside the app | External maps apps can't show a recorded route; Google Maps SDK needs a billing account |
