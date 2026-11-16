---
description: "Task list for live snowboarding tracking"
---

# Tasks: Live Snowboarding Tracking

**Input**: `/specs/017-snowboard-live-tracking/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [x] T001 Constitution 1.8.0 (VI wording, VII scope), spec, plan, tasks; CLAUDE.md active feature
- [ ] T002 (owner, optional) Export a real ski day as GPX (Slopes can export one) into test/fixtures/tracks/ for threshold tuning

## Phase 2: Foundational — domain (tests first)

- [x] T003 Tests: snowboarding has distance and live tracking; `validateActivity` accepts a snowboarding distance; `TrackProfile.forType('snowboarding')` (45 m/s limit, never auto-pauses); `formatSpeedKmh`, `formatMetersGrouped` — test/domain/activity_types_test.dart, test/domain/tracking/track_reducer_test.dart
- [x] T004 Implement T003 in lib/domain/activity_types.dart and lib/domain/tracking/track_profile.dart; fix the tests that assumed snowboarding has no distance (activity_types_test, activity_repository_test, activities_test, start_hub_test)
- [x] T005 Fixture generator: scripted legs (lift, run, queue, stop) with seeded noise and reference totals; scenarios from plan "Fixtures" — test/domain/tracking/snow_fixtures.dart
- [x] T006 Tests: signals (speed fallback, altitude median, vertical rate), raw labels, candidate confirmation and backdating, lift ends at last climbing fix, chairlift stop under 120 s, gondola gap, stop mid-run, traverse under 30 m not a run, no altitude, pause / resume, `snowDescents`, metrics within 5% and exact run count on every scenario, replay equals incremental — test/domain/tracking/snow_reducer_test.dart
- [x] T007 Implement lib/domain/tracking/snow_state.dart and snow_reducer.dart (`SnowTuning`, `startSnow`, `accumulateSnow`, `pauseSnow`, `resumeSnow`, `replaySnow`, `snowDescents`)
- [x] T008 Tests: summary totals, open segment closed at `endedAt`, per-segment simplification (sum of `n` equals route length, slices start and end on segment boundaries), start / end altitudes, per-point `p` and `q` arrays (length `n`, `q` non-decreasing, last `q` ≤ duration), segments JSON round trip, 8-hour day within SC-004 sizes — test/domain/tracking/snow_summary_test.dart
- [x] T009 Implement lib/domain/tracking/snow_summary.dart (`SnowSummary`, `summarizeSnow`, `encodeSegments`, `decodeSegments`)

## Phase 3: Foundational — data

- [x] T010 Schema v9: six `activities` columns; `from8To9`; regenerate; make-migrations → drift_schemas/drift_schema_v9.json and test/drift/fitapp/generated/schema_v9.dart; migration test v8→v9 (existing rows keep nulls)
- [x] T011 [P] Server: supabase/migrations/20261116000001_activities_snowboard.sql (columns, checks, length limit, `sync_columns` whitelist); extend supabase/tests/sync_push_test.sql and limits_test.sql; `node tool/db_test.mjs` green
- [x] T012 Sync columns in lib/data/sync/sync_table.dart; push / pull round-trip test with the new fields — test/data/sync/
- [x] T013 Repository tests: start accepts snowboarding; finish for snowboarding writes ride distance, ride seconds, vertical drop, run count, max speed, lift and rest seconds, route and segments, with null splits and climb, and deletes points in one transaction; running and cycling unchanged; editing a tracked snowboarding day keeps its type — test/data/tracking_repository_test.dart, test/data/activity_repository_test.dart
- [x] T014 Implement T013 in lib/data/repositories/tracking_repository.dart (`finish` branch, `replaySnowState`) and activity_repository.dart

## Phase 4: User Story 1 + 2 — record and recover (P1)

- [ ] T015 Controller tests with FakeLocationSource replaying a ski-day fixture: `TrackingLive.snow` updates, pause / resume, `previewSnowSummary`, finish stores the same numbers as the preview, recovery after recreating the container gives the same snow state, live route never exceeds 2,000 points and running / cycling routes still draw — test/features/tracking/tracking_controller_test.dart
- [ ] T016 Implement T015 in lib/features/tracking/tracking_controller.dart (snow state, preview, route thinning)
- [ ] T017 `RouteMap` sections (muted ranges) in the tile map and the painter fallback; test — lib/features/tracking/widgets/route_map.dart, test/features/tracking/route_map_test.dart
- [ ] T018 Live screen snowboarding panel: speed hero, status chip, six tiles, sectioned live route — lib/features/tracking/widgets/snow_live_panel.dart, live_track_screen.dart; widget test
- [ ] T019 [P] `SnowTimeBar` (ride / lift / rest with legend and semantics) — lib/features/tracking/widgets/snow_time_bar.dart; widget test
- [ ] T020 Finish sheet snowboarding branch (metrics, time bar, sectioned map) — lib/features/tracking/finish_sheet.dart; widget test
- [ ] T021 Start hub and Log activity sheet: Snowboarding listed with the live types, manual form shows Distance, type picker hidden when editing a tracked snowboarding day — tests in test/features/start_hub_test.dart, activities_test.dart
- [ ] T022 e2e: fixture ski day from start hub to saved activity — test/e2e/gps_flow.dart

## Phase 5: User Story 3 + 4 — review (P2)

- [ ] T023 History row "N runs · X m ↓" for tracked snowboarding days; manual entries unchanged — lib/features/history/history_rows.dart; test
- [ ] T024 `SnowTimeline` (descents and lifts) — lib/features/activities/widgets/snow_timeline.dart; widget test
- [ ] T025 Activity detail snowboarding branch: sectioned map, totals, time bar, timeline; no km markers or splits — lib/features/activities/activity_detail_screen.dart; test in test/features/gps_activity_test.dart

## Phase 6: User Story 5 + 6 + 7 — Slopes Premium review tools (P3)

- [x] T030 Tests then implementation: `snowDayStats`, `snowBadges`, `compareRuns`, `replayAt`, `speedColorStops` — lib/domain/tracking/snow_review.dart, test/domain/tracking/snow_review_test.dart
- [ ] T031 `RouteMap`: per-point coloured sections and `style` (Dark, Winter, Satellite; confirm the MapTiler style ids and attribution in their docs first); plain-background fallback keeps the colours — route_map.dart; tests
- [ ] T032 [P] `mapStyleProvider` persisted in local settings (not synced) and the style button — lib/features/settings/, detail screen; test
- [ ] T033 Heatmap on the detail map with legend; highest / lowest altitude and longest run in the totals — activity_detail_screen.dart; widget test
- [ ] T034 [P] `SnowCompare` view with metric chips, sort and badges; badges in `SnowTimeline` — lib/features/activities/widgets/snow_compare.dart; widget test
- [ ] T035 Replay screen and route `/activity/:id/replay/:run`; entry from a timeline row and from the badges — lib/features/activities/snow_replay_screen.dart, lib/app/router.dart; widget test with a fake ticker

## Phase 7: Polish

- [ ] T026 Docs: PRD (v2.9: snowboarding tracking moves from LATER to done, glossary, changelog), README roadmap, docs/ARCHITECTURE.md (snow reducer, schema v9)
- [ ] T027 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, `node tool/db_test.mjs` all green; domain coverage 100% for the new files
- [ ] T028 Apply the Supabase migration to the project; build the phone-test APK (release build, debug signing, next `app-release-0.0.N`)
- [ ] T029 (owner) One real day on the mountain; report run count and anything misclassified; tune `SnowTuning` if needed

## Dependencies

- T003–T009 before everything else; T010 before T012–T014; T011 is independent of the app code.
- T016 needs T007, T009, T014. T018 and T020 need T016 and T017. T025 needs T017, T019, T024.
- Phase 6 needs T009 (stored arrays) and T025; T031 before T033 and T035; T030 before T033–T035.
- [P] tasks touch files nobody else touches and can run in parallel.
