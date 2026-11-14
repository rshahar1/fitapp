---
description: "Task list for live GPS tracking (running, cycling)"
---

# Tasks: Live GPS Tracking for Running and Cycling

**Input**: `/specs/010-live-gps-tracking/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [ ] T001 (owner) Create a free MapTiler account and API key; put it in git-ignored `env/dev.json` as `MAP_TILES_KEY`
- [x] T002 Add `"MAP_TILES_KEY": ""` to env/example.json; README run instructions
- [x] T003 Add `geolocator`, `flutter_map`, `latlong2` (latest stable); Android manifest permissions + foreground service type `location`; iOS Info.plist keys and background mode
- [x] T004 Collect 3 GPX fixtures (5 km run, 30 km ride, run with a stop and a GPS spike) under test/fixtures/tracks/

## Phase 2: Foundational — domain (tests first)

- [x] T005 Tests: haversine, polyline encode/decode round trip, Douglas-Peucker — test/domain/tracking/geo_test.dart
- [x] T006 Implement lib/domain/tracking/geo.dart
- [x] T007 Tests: reducer accuracy filter, speed-spike rejection, manual pause/resume, auto-pause per profile, distance within 1% on fixtures, per-km splits, 30 s current pace, elevation gain with 3 m hysteresis, replay equals incremental — test/domain/tracking/track_reducer_test.dart
- [x] T008 Implement track_sample, track_profile, track_state, track_reducer, track_summary in lib/domain/tracking/
- [x] T009 `ActivityType.hasLiveTracking` (running, cycling) + tests in lib/domain/activity_types.dart

## Phase 3: Foundational — data

- [x] T010 Schema v6: `tracking_sessions`, `track_points`, activity columns (source, moving_seconds, elevation_gain_m, route, splits); `from5To6`; regenerate; make-migrations → drift_schema_v6.json; migration test v5→v6 (existing activities become `manual`)
- [x] T011 Repository tests: start (one session max, refuses while a gym workout is active), appendPoints batch, pause/resume, finish (activity row + points/session deleted in one transaction), discard, recover — test/data/tracking_repository_test.dart
- [x] T012 Implement lib/data/repositories/tracking_repository.dart + providers
- [x] T013 `LocationSource` interface, `FakeLocationSource` (test helper replaying fixtures), `GeolocatorLocationSource` with foreground notification config

## Phase 4: User Story 1 + 2 — record and recover (P1)

- [x] T014 Controller tests with FakeLocationSource: Acquiring → Live, batching flush every 5 s / 20 points, pause/resume, finish summary, discard, recovery after recreating the container — test/features/tracking/tracking_controller_test.dart
- [x] T015 Implement lib/features/tracking/tracking_controller.dart
- [x] T016 Activity sheet: Start live for live-tracking types; one-live-session message — lib/features/activities/activity_sheet.dart
- [x] T017 Setup screen (permission rationale, accuracy chip, Start / Start anyway, denied → settings or manual) — lib/features/tracking/track_setup_screen.dart
- [x] T018 `RouteMap` widget (flutter_map + MapTiler dark when key present; CustomPainter fallback) — lib/features/tracking/widgets/route_map.dart
- [x] T019 Live screen (hero + tiles per type, live route, fixed footer Pause/Resume · Lock · hold-to-Finish) — lib/features/tracking/live_track_screen.dart
- [x] T020 Finish sheet (fitted map, metrics, note, Save / Discard with confirm; short-session confirm)
- [x] T021 Routes `/track/new`, `/track/live`; launch-time recovery redirect; Train "in progress" banner
- [x] T022 Widget tests for T016–T021 (map tiles disabled) — test/features/tracking/

## Phase 5: User Story 3 + 4 — review (P2)

- [x] T023 `RouteThumbnail` + History row for GPS activities — lib/features/history/history_rows.dart
- [x] T024 Activity detail screen `/activity/:id` (interactive map, start/finish + km markers, metrics, splits; Edit type/date/note; Delete confirm)
- [x] T025 Widget tests for T023–T024
- [x] T026 Integration test: replay the 5 km fixture end-to-end to History — integration_test/

## Phase 6: Polish

- [x] T027 Constitution 1.4.0 (VII amendment), PRD v2.6, README, docs/ARCHITECTURE.md, CLAUDE.md active feature; mark proposal phase A as approved/implemented
- [x] T028 Gates: format, analyze, `flutter test -j 1`, `flutter build apk --debug`
- [ ] T029 (owner) On-phone validation: 30-minute run with screen locked, a forced kill mid-run, a ride, airplane-mode run

## Phase 7: Owner validation fixes (2026-11-14)

Owner report: (a) no map visible when starting without GPS; (b) after enabling GPS the setup screen stays on "Wait for a good GPS signal…".

- [x] T030 `LocationSource.serviceStatus()` stream + `lastKnownPosition()`; controller re-listens when location is switched on (quick settings, no app resume) and marks the service off when switched off
- [x] T031 Controller retries the position stream after an error (2 s backoff) while acquiring or live, instead of going silent
- [x] T032 Setup screen shows the map centred on the latest fix or the last known position (world view + "Finding your location" only when neither exists); after 20 s without a good fix the hint explains indoor GPS and promotes "Start anyway"
- [x] T033 `RouteMap` moves the camera to the first known point when it started without one (setup and live screens); live screen passes the current position
- [x] T034 Tests for T030–T033; gates (release APK rebuild with `env/dev.json` left to the owner)
