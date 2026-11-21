# Tasks: Iron Plate Visual Identity

**Input**: [spec.md](./spec.md), [plan.md](./plan.md), [research.md](./research.md),
[contracts/theme-contract.md](./contracts/theme-contract.md), [quickstart.md](./quickstart.md)

Rules for every sweep task: read tokens only from `lib/app/theme/` (`AppColors`, `Radii`, `Strokes`,
`AppFonts`, `context.plate`, `context.metrics`, `AppIcons`); never edit `lib/app/theme/*`; no
`Icons.`, `BoxShape.circle`, `CircleBorder`, `StadiumBorder`, `CircleAvatar`, `Radii.pill`, or
hex colors; keep behaviour, keys, semantics strings, tap targets (≥ 48 dp, steppers 56×60) and
layout structure; update the tests that cover the touched files.

## Phase 1: Setup

- [x] T001 Download Barlow, Barlow Condensed and Big Shoulders Display (OFL) into `assets/fonts/`
- [x] T002 Build capitals-only `PlateDisplay` 800/900 with `tool/build_display_font.py`
- [x] T003 Add `material_symbols_icons` to `pubspec.yaml`
- [x] T004 Register font families in `pubspec.yaml` and OFL licences via `LicenseRegistry` in `lib/main.dart`

## Phase 2: Foundational (blocks all stories)

- [x] T005 New palette, `Radii`, `Strokes`, `AppFonts` in `lib/app/theme/tokens.dart` per the contract
- [x] T006 [P] `AppIcons` (all 52 current `Icons.*` names → `Symbols.*_sharp`) in `lib/app/theme/app_icons.dart`
- [x] T007 [P] `PlateTextStyles` extension (`display`, `number`, `tag`) in `lib/app/theme/text_styles.dart`
- [x] T008 Full component theming (Barlow default, PlateDisplay titles, square shapes for every Material control, icon weight 600, plate `MetricColors`) in `lib/app/theme/app_theme.dart`
- [x] T009 Guard test (old hex values, `Icons.`, circles, stadiums, `Radii.pill`) in `test/app/theme_guard_test.dart`

## Phase 3: User Story 1 — core gym flow (P1)

**Independent test**: full workout on the emulator matches the direction table.

- [x] T010 [P] [US1] Shared kit: `lib/widgets/*.dart` (app_button rectangular, app_card square + 4 dp yellow top rule option, group 1 dp rules, section_header PlateDisplay, chip_selector tape labels, app_stepper square, delta_badge plate tag, stat/metric tiles BarlowCondensed numbers, empty_state, duration_picker, glow_line_chart and weekly_bar_chart plate colors and square bar ends); tests in `test/widgets/`
- [x] T011 [P] [US1] Shell and Go: rectangular yellow Go block, nav bar in `lib/features/shell/shell_scaffold.dart`, `lib/features/start/*.dart`; tests `test/features/start_hub_test.dart`
- [x] T012 [P] [US1] Workout: `lib/features/workout/**` (square green done checks, yellow current-set rail, yellow overload tag, rest block, finish summary, set sheet, plan form, reward burst / figure / target pill colors); tests `test/features/workout_screen_test.dart`

## Phase 4: User Story 2 — every other screen (P1)

**Independent test**: every route, sheet, dialog and menu shows the new look.

- [x] T013 [P] [US2] Templates and exercises: `lib/features/templates/*.dart`, `lib/features/exercises/*.dart`
- [x] T014 [P] [US2] History and progress: `lib/features/history/*.dart`, `lib/features/progress/*.dart`; tests `test/features/history_calendar_test.dart`
- [x] T015 [P] [US2] Tracking and activities: `lib/features/tracking/**`, `lib/features/activities/**` (square map markers, plate heatmap, safety-orange live, activity icons via AppIcons); tests `test/features/gps_activity_test.dart`, `test/features/activities_test.dart`, `test/features/tracking/snow_widgets_test.dart`, `test/e2e/gps_flow.dart`
- [x] T016 [P] [US2] Train, You, Settings, Account, Privacy: `lib/features/train/*.dart`, `lib/features/you/*.dart`, `lib/features/settings/*.dart`; tests `test/features/train_screen_test.dart`
- [x] T017 [US2] Backdrop scrims from soot in `lib/app/backdrop.dart`; test `test/app/backdrop_test.dart`

## Phase 5: User Story 3 — share picture, launcher, splash (P2)

**Independent test**: exported PNGs, launcher and splash show the new identity.

- [x] T018 [P] [US3] Share card and preview: `lib/features/share/*.dart` (PlateDisplay headings, BarlowCondensed stats, plate metric colors, square shapes); tests `test/features/share_test.dart`
- [x] T019 [P] [US3] Draw the mark with `tool/draw_launcher_icon.swift` → `assets/icon/icon.png`, `assets/icon/icon_foreground.png`; set `#15120F` in `flutter_launcher_icons.yaml`, `flutter_native_splash.yaml`; regenerate Android/iOS resources

## Phase 6: User Story 4 — owner review (P1)

- [x] T020 [US4] Launch the branch build on `fitapp_sim` for the owner (quickstart walk-through)
- [x] T021 [US4] Apply the owner's rejects on this branch; re-run checks (live state → plate red on Home and the Go sheet; blue `info` role for read-only data; training icons stay yellow)

## Phase 7: Polish

- [x] T022 [P] PRD v2.20 §2.2 rewrite + changelog in `docs/PRD-fitapp-flutter.md`; `CLAUDE.md` active feature → 034
- [x] T023 Repo-wide sweep for leftovers (guard test green, manual grep of `lib/`), `dart format`, `flutter analyze`, `flutter test`; commit on the branch
- [x] T024 After explicit owner approval only: merge to main, push, bump version, build and send APK

## Dependencies

Setup → Foundational (T005–T009) → US1, US2 and US3 sweeps in parallel (disjoint files) →
T023 checks → US4 review → T024.

## Parallel execution

After T008: T010, T011, T012, T013, T014, T015, T016, T018 and T019 each own disjoint files and
can run at once. T017 and T022 are small and run alongside.

## Implementation strategy

Foundation first (owned by the orchestrator), then the sweeps by delegated agents, then one
verification pass and the emulator review. MVP is US1 (core gym flow), but the owner asked for
the whole app before review, so all stories ship together.
