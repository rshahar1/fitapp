---
description: "Task list for live GPS tracking (running, cycling)"
---

# Tasks: Live GPS Tracking for Running and Cycling

**Input**: `/specs/010-live-gps-tracking/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [ ] T001 (owner) Create a free MapTiler account and API key; put it in git-ignored `env/dev.json` as `MAP_TILES_KEY`
- [ ] T002 Add `"MAP_TILES_KEY": ""` to env/example.json; README run instructions
- [ ] T003 Add `geolocator`, `flutter_map`, `latlong2` (latest stable); Android manifest permissions + foreground service type `location`; iOS Info.plist keys and background mode
- [ ] T004 Collect 3 GPX fixtures (5 km run, 30 km ride, run with a stop and a GPS spike) under test/fixtures/tracks/

## Phase 2: Foundational — domain (tests first)

- [ ] T005 Tests: haversine, polyline encode/decode round trip, Douglas-Peucker — test/domain/tracking/geo_test.dart
- [ ] T006 Implement lib/domain/tracking/geo.dart
- [ ] T007 Tests: reducer accuracy filter, speed-spike rejection, manual pause/resume, auto-pause per profile, distance within 1% on fixtures, per-km splits, 30 s current pace, elevation gain with 3 m hysteresis, replay equals incremental — test/domain/tracking/track_reducer_test.dart
- [ ] T008 Implement track_sample, track_profile, track_state, track_reducer, track_summary in lib/domain/tracking/
- [ ] T009 `ActivityType.hasLiveTracking` (running, cycling) + tests in lib/domain/activity_types.dart

## Phase 3: Foundational — data

- [ ] T010 Schema v6: `tracking_sessions`, `track_points`, activity columns (source, moving_seconds, elevation_gain_m, route, splits); `from5To6`; regenerate; make-migrations → drift_schema_v6.json; migration test v5→v6 (existing activities become `manual`)
- [ ] T011 Repository tests: start (one session max, refuses while a gym workout is active), appendPoints batch, pause/resume, finish (activity row + points/session deleted in one transaction), discard, recover — test/data/tracking_repository_test.dart
- [ ] T012 Implement lib/data/repositories/tracking_repository.dart + providers
- [ ] T013 `LocationSource` interface, `FakeLocationSource` (test helper replaying fixtures), `GeolocatorLocationSource` with foreground notification config

## Phase 4: User Story 1 + 2 — record and recover (P1)

- [ ] T014 Controller tests with FakeLocationSource: Acquiring → Live, batching flush every 5 s / 20 points, pause/resume, finish summary, discard, recovery after recreating the container — test/features/tracking/tracking_controller_test.dart
- [ ] T015 Implement lib/features/tracking/tracking_controller.dart
- [ ] T016 Activity sheet: Start live for live-tracking types; one-live-session message — lib/features/activities/activity_sheet.dart
- [ ] T017 Setup screen (permission rationale, accuracy chip, Start / Start anyway, denied → settings or manual) — lib/features/tracking/track_setup_screen.dart
- [ ] T018 `RouteMap` widget (flutter_map + MapTiler dark when key present; CustomPainter fallback) — lib/features/tracking/widgets/route_map.dart
- [ ] T019 Live screen (hero + tiles per type, live route, fixed footer Pause/Resume · Lock · hold-to-Finish) — lib/features/tracking/live_track_screen.dart
- [ ] T020 Finish sheet (fitted map, metrics, note, Save / Discard with confirm; short-session confirm)
- [ ] T021 Routes `/track/new`, `/track/live`; launch-time recovery redirect; Train "in progress" banner
- [ ] T022 Widget tests for T016–T021 (map tiles disabled) — test/features/tracking/

## Phase 5: User Story 3 + 4 — review (P2)

- [ ] T023 `RouteThumbnail` + History row for GPS activities — lib/features/history/history_rows.dart
- [ ] T024 Activity detail screen `/activity/:id` (interactive map, start/finish + km markers, metrics, splits; Edit type/date/note; Delete confirm)
- [ ] T025 Widget tests for T023–T024
- [ ] T026 Integration test: replay the 5 km fixture end-to-end to History — integration_test/

## Phase 6: Polish

- [ ] T027 Constitution 1.4.0 (VII amendment), PRD v2.6, README, docs/ARCHITECTURE.md, CLAUDE.md active feature; mark proposal phase A as approved/implemented
- [ ] T028 Gates: format, analyze, `flutter test -j 1`, `flutter build apk --debug`
- [ ] T029 (owner) On-phone validation: 30-minute run with screen locked, a forced kill mid-run, a ride, airplane-mode run
