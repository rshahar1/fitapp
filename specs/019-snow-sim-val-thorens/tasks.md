---
description: "Task list for the simulated Val Thorens snowboarding session"
---

# Tasks: Simulated Snowboarding Session on Val Thorens

**Input**: `/specs/019-snow-sim-val-thorens/` (spec, plan)

**Tests**: REQUIRED (constitution II, III).

## Phase 1: Setup

- [x] T001 Spec, plan, tasks; CLAUDE.md active feature
- [x] T002 Move the CSV parser to lib/data/tracking/track_csv.dart; test/domain/tracking/track_fixtures.dart delegates to it; test — test/data/tracking/track_csv_test.dart

## Phase 2: Dataset

- [x] T003 tool/val_thorens/fetch_geometry.dart (Overpass lifts and pistes, IGN RGE ALTI every 12 m, generic User-Agent); run once; commit tool/val_thorens/geometry.json
- [x] T004 tool/val_thorens/README.md: sources, licences, attribution
- [x] T005 tool/gen_val_thorens_session.dart: offline, seeded, 1 Hz session per plan "Dataset", reference totals in the metadata, `--gpx <path>`; writes lib/data/tracking/sim/val_thorens_session.dart
- [x] T006 Check generation is deterministic (two runs, identical bytes) and needs no network

## Phase 3: User Story 1 — regression on real terrain (P1)

- [x] T007 Tests then fix-ups: fixture through `track_reducer` + `snow_reducer`: runs == 2, ride / lift / rest, distance, drop, max speed within 5%; replay equals incremental; lift spans cover the three lifts — test/domain/tracking/val_thorens_fixture_test.dart
- [x] T008 Record any detection weakness in plan.md "Findings" with evidence and a proposed `SnowTuning` change; do not bend the fixture

## Phase 4: User Story 2 — simulation mode (P2)

- [x] T009 Tests: virtual clock (monotonic, speed changes without a jump), parked fixes, ordering, end-of-session hold — test/data/tracking/sim/track_simulation_test.dart
- [x] T010 Implement lib/data/tracking/sim/track_simulation.dart and simulated_location_source.dart
- [x] T011 Tests then implementation: compile-time switch (`SIMULATE_GPS && !kReleaseMode`) and `simulationEnabled` helper — lib/data/tracking/sim/simulation_switch.dart, test/data/tracking/sim/simulation_switch_test.dart
- [x] T012 Providers and wiring: `simulationProvider`, listener on `trackingControllerProvider` (start on a new live session id, park on finish / discard), overrides of `locationSourceProvider` and `clockProvider` in main() only under the switch — lib/data/providers.dart, lib/main.dart; the listener lives in lib/features/tracking/simulation_driver.dart (data must not import features) and the database takes the simulation clock too (`AppDatabase.open(clock:)`, see Findings 4)
- [x] T013 Controller test: `SimulatedLocationSource` through the real `TrackingController` at high speed, in-memory database; live state shows lifts / runs; final summary matches the reference — test/features/tracking/simulated_tracking_test.dart
- [x] T014 `SimulationBar` (speed chips 1× 5× 10× 30×, progress) on the setup and live screens, shown only when enabled; widget test — lib/features/tracking/widgets/simulation_bar.dart, test/features/tracking/simulation_bar_test.dart
- [x] T015 e2e: Val Thorens variant of `runSnowFlow` ("2 runs" in History) — test/e2e/gps_flow.dart

## Phase 5: User Story 3 — GPX for the emulator (P3)

- [x] T016 Document the emulator steps in tool/val_thorens/README.md; GPX export checked by hand (2,525 track points, one per CSV row, 1 s apart), no automated test since the generator is a dev tool outside `flutter test`

## Phase 6: Polish

- [x] T017 `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` all green
- [x] T018 Check the release build contains neither the session data nor the bar (build with `--dart-define=SIMULATE_GPS=true` and look for the CSV text) — see plan.md Findings 5
- [x] T019 Run the simulation in an emulator and record what was seen (status changes, runs, map, speeds 1×–30×) in plan.md "Findings" — Pixel 7 AVD, API 35; see Findings "On screen"

## Dependencies

- T002 before T007 and T013; T003 before T005; T005 before T007.
- T009–T011 before T012; T012 before T013 and T014; T014 before T015.
- T017–T019 last.
