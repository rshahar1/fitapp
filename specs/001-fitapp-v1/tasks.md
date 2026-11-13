---
description: "Task list for FitApp v1 implementation"
---

# Tasks: FitApp v1 – Offline Workout Logger with Automatic Progressive Overload

**Status (2026-11-12)**: M0-M5 implemented; M6 partially done (icon/splash, docs, release build verified locally). Private repo created and CI green (T010). T056 and T057 (rest-end sound, background notification) done in feature 002-rest-alerts. Pending: T085-T086 (need the real phone). T083 is done except the keystore, which the owner creates.

**Input**: Design documents from `/specs/001-fitapp-v1/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: REQUIRED. The PRD (§12) and constitution (II, III) mandate test-first development: write
each test task first, see it fail, then implement.

**Organization**: Tasks are grouped by user story. PRD milestones are noted on each phase; every
milestone ends with `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test` green and
a commit.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- Paths follow plan.md (`lib/`, `test/`, `integration_test/` at repository root)

---

## Phase 1: Setup (M0)

**Purpose**: Flutter project, tooling, repo hygiene, CI

- [x] T001 Install Flutter stable 3.50+, JDK 17 and Android SDK; confirm `flutter doctor` is green for Android (see quickstart.md)
- [x] T002 Run `flutter create --org com.fitapp --project-name fitapp --platforms android,ios .` in the repo root without overwriting `docs/`, `specs/`, `.specify/`, `.claude/`
- [x] T003 Set Android `applicationId` to `com.fitapp.app`, app label **FitApp**, and portrait-only in android/app/build.gradle.kts and android/app/src/main/AndroidManifest.xml
- [x] T004 [P] Write .gitignore covering every path in PRD §9.3 (incl. `env/*.json` except `!env/example.json`, `*.jks`, `*.keystore`, `android/key.properties`, `coverage/`, `.DS_Store`, `supabase/.temp/`)
- [x] T005 [P] Add analysis_options.yaml using `very_good_analysis` (exclude `**/*.g.dart`; disable `public_member_api_docs`) and .editorconfig
- [x] T006 Add dependencies to pubspec.yaml per research.md: flutter_riverpod, go_router, drift, drift_flutter, fl_chart, uuid, intl; dev: drift_dev, build_runner, very_good_analysis, mocktail, integration_test (no `sqlite3_flutter_libs`)
- [x] T007 [P] Create env/example.json with empty values and wire `--dart-define-from-file` usage in README
- [x] T008 [P] Write README.md skeleton (what it is, progression rule, setup, run, test, build APK, layout, roadmap, generated-code policy: committed) and docs/ARCHITECTURE.md skeleton
- [x] T009 [P] Create .github/workflows/ci.yml: pub get → build_runner + `git diff --exit-code` → format check → analyze → `flutter test --coverage` → `flutter build apk --debug`
- [x] T010 Configure git user.email to the owner's GitHub no-reply address, create private GitHub repo `fitapp` with `gh repo create` (owner approval), push, and confirm CI is green; verify no secrets/IDE files are tracked

**Checkpoint**: M0 done – `flutter analyze` clean, CI green.

---

## Phase 2: Foundational (M1 domain + M2 schema + M3 theme/shell)

**Purpose**: Pure domain, database, theme and navigation that every story depends on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Domain: progression (tests first, 100% coverage)

- [x] T011 [P] Write tests for `roundWeight` (0.1+0.2+22.2 → 22.5) and `Plan` validation (sets ≥ 2, reps ≥ 1, increment > 0, base ≥ 0 throw otherwise) in test/domain/progression_test.dart
- [x] T012 [P] Write tests for `prescribe` (3-set base/base/base+inc, 4-set, +5 variant) in test/domain/progression_test.dart
- [x] T013 [P] Write tests for `evaluate` (progressed; exceeding reps; missed reps on set 2; reps at lighter weight; heavier overload → next base = lifted; overload missing; overload not heavier; working set missing; order independence; extra sets ignored) in test/domain/progression_test.dart
- [x] T014 [P] Write tests for `canRewriteBase` (latest & matching → true; edited since / not latest / never applied → false) in test/domain/progression_test.dart
- [x] T015 Implement lib/domain/progression.dart per contracts/domain-api.md until T011–T014 pass; verify 100% line coverage

### Domain: stats (tests first)

- [x] T016 [P] Write tests for `volume` (per-hand ×2, §11 case = 1070 kg), `epley1RM` (100×10 → 133.3, ×1 → 100, ×0 → 0) in test/domain/stats_test.dart
- [x] T017 [P] Write tests for `personalRecords`, `newPRTypes` (strictly greater), `summarizeSession` (working weight excludes overload), `diffSummary` (▲/▼/–, %, first session → null) in test/domain/stats_test.dart
- [x] T018 [P] Write tests for `isoWeekKey` (2026-11-09 → 2026-W46; 2027-01-01 → 2026-W53), `workoutsPerWeek` (8 weeks, zero-filled), `weeklyStreak` (in-progress current week, gap, across year boundary) in test/domain/stats_test.dart
- [x] T019 Implement lib/domain/stats.dart and lib/core/iso_week.dart until T016–T018 pass

### Data: schema, migrations, seed

- [x] T020 Define drift tables in lib/data/db/tables.dart exactly per data-model.md: `exercises`, `exercise_state` (`rest_seconds` NULL = default), `workouts` (`ended_at` NULL = in progress), `workout_exercises` (cascade, snapshot columns), `sets` (`UNIQUE(workout_exercise_id, set_no)`, cascade, no `set_type`), `pending_deletes` (PK table_name,row_id), `settings` (key PK, value); `updated_at` + `dirty` on syncable tables; indexes listed in data-model.md
- [x] T021 Create lib/data/db/app_database.dart (`schemaVersion = 1`, `MigrationStrategy`, `PRAGMA foreign_keys = ON` in `beforeOpen`, UTC text timestamps) using `drift_flutter`; generate and commit app_database.g.dart; export schema to drift_schemas/
- [x] T022 [P] Write tests: seeding inserts 16 exercises with UUIDs `00000000-0000-4000-8000-000000000001`…`…000000000010`, re-seeding is idempotent and refreshes name/group/increment, FK ON, migration from v1 schema dump keeps data, in test/data/database_test.dart
- [x] T023 Implement lib/data/db/seed_library.dart with the 16-exercise table from PRD §5.1 until T022 passes
- [x] T024 [P] Implement `DataException` + logging wrapper in lib/core/result.dart and the injectable `Clock` in lib/core/clock.dart
- [x] T025 Create Riverpod providers for database and repositories (overridable with in-memory DB in tests) in lib/data/providers.dart

### App shell, theme and UI kit

- [x] T026 [P] Define design tokens (all colors from PRD §2.2, spacing 2/4/8/16/24/32/64, radius 14, 48 dp / 56×60 targets) in lib/app/theme/tokens.dart and `MetricColors` ThemeExtension in lib/app/theme/metric_colors.dart
- [x] T027 Build always-dark Material 3 ThemeData with tabular-figure number styles in lib/app/theme/app_theme.dart
- [x] T028 [P] Implement subtle backdrop CustomPainter (top-right accent glow, fading grid, faint rising curve, bottom-left blue glow) wrapped in `ExcludeSemantics` in lib/app/backdrop.dart
- [x] T029 [P] Implement haptics wrapper (tick / success / warning, injectable) in lib/core/haptics.dart and formatting helpers (`formatKg`, durations, `m:ss`, deltas) in lib/core/format.dart with tests in test/core/format_test.dart
- [x] T030 [P] Build shared UI kit in lib/widgets/: AppButton (pill, uppercase), AppCard, Group/GroupRow (hairline separators), SectionHeader, AppStepper (min 0, custom step, 56×60), ChipSelector, MetricTile, Delta, Stat — all with Semantics; golden-free widget tests in test/widgets/ui_kit_test.dart
- [x] T031 Configure go_router with `StatefulShellRoute` (Train / History / Progress) and full-screen routes from contracts/ui-routes.md (placeholders allowed) in lib/app/router.dart; bottom navigation in lib/features/shell/shell_scaffold.dart
- [x] T032 Wire lib/main.dart and lib/app/app.dart: ProviderScope, seed on startup, portrait lock, backdrop behind all screens

**Checkpoint**: M1 + schema done; app launches to three empty tabs on a phone; all domain/data tests green.

---

## Phase 3: User Story 1 – Log a workout and progress automatically (P1, M2 + M3) 🎯 MVP

**Goal**: Start a workout, add an exercise, set up a plan, one-tap log sets, finish with progression.

**Independent Test**: PRD §11 scenarios 1–3 pass in tests; on a phone, log `20×10, 20×10, 22.5×6`
on Incline DB Press and see `20 kg → 22.5 kg`, next prescription `22.5, 22.5, 25`.

### Tests for User Story 1 (write first)

- [x] T033 [P] [US1] Repository tests: full flow plan → session → progression → prescription → missed session; re-log overwrites; no-plan exercise never progresses; snapshot written on finish; base raised only if unchanged; discard empty workout; only one active workout; every `logSet` committed — in test/data/workout_repository_test.dart
- [x] T034 [P] [US1] Repository tests: `previousSession` lookup and `savePlan` validation (`target_sets ≥ 2`, `target_reps ≥ 1`, `increment > 0`, `base_weight ≥ 0`) in test/data/exercise_repository_test.dart
- [x] T035 [P] [US1] Widget tests: set row dimmed when unlogged, check box logs as prescribed, missed reps shown red `8 / 10`, overload row marked, semantics label text, in test/features/workout/set_row_test.dart

### Implementation for User Story 1

- [x] T036 [US1] Implement ExerciseRepository (watchExercises, watchPlan, savePlan) in lib/data/repositories/exercise_repository.dart
- [x] T037 [US1] Implement WorkoutRepository live-workout methods (startWorkout, addExercise, removeExercise, logSet upsert, clearSet + pending delete, finishWorkout [txn, PRD §4.3], discardWorkout, watchWorkout, previousSession) in lib/data/repositories/workout_repository.dart
- [x] T038 [US1] Workout controller (Riverpod notifier: prescriptions, header totals, finish result) in lib/features/workout/workout_controller.dart
- [x] T039 [P] [US1] Workout header (live Duration · Volume · Sets, Finish) in lib/features/workout/widgets/workout_header.dart
- [x] T040 [P] [US1] Plan setup card (base stepper by increment, reps default 10, sets default 3 min 2, increment chips +1/+2/+2.5/+5 defaulting to exercise increment, “Start with this plan”) in lib/features/workout/widgets/plan_setup_card.dart
- [x] T041 [US1] Set table + set row (SET/↑ · PREVIOUS · KG · REPS · ✓, + Add Set) in lib/features/workout/widgets/set_table.dart
- [x] T042 [US1] Set editor bottom sheet (weight ± increment, reps ± 1, Log/Update, Clear set with warning haptic; closes on back) in lib/features/workout/widgets/set_sheet.dart
- [x] T043 [US1] Exercise card (name, plan summary `3 × 10 @ 20 kg · overload +2.5 · per hand`, ⋮ Remove (confirm) / Edit plan, notes field) and “Compared to previous” card in lib/features/workout/widgets/exercise_card.dart
- [x] T044 [US1] Workout screen (live mode) with fixed footer reserving space for the rest pill, Add Exercise button, Finish → discard confirm or summary sheet in lib/features/workout/workout_screen.dart and lib/features/workout/widgets/finish_summary_sheet.dart
- [x] T045 [US1] Basic exercise picker grouped by muscle group (returns selection, appends to this workout) in lib/features/exercises/exercise_picker_screen.dart
- [x] T046 [US1] Train tab hero card with Start workout / Continue workout in lib/features/train/train_screen.dart
- [x] T047 [US1] Integration test: start → add exercise → plan → log 3 sets → finish → summary shows new base (exercise-detail assertion added in US4) in integration_test/workout_flow_test.dart

**Checkpoint**: MVP – a full workout can be logged on a real phone with automatic progression.

---

## Phase 4: User Story 2 – Rest timer and settings (P2, M3)

**Goal**: Countdown rest timer in the footer, configurable default and per-exercise override.

**Independent Test**: Log a set → footer counts down from 1:00 without shifting rows; at 0 pulse and
overtime; change default to 90 s, restart, log → 1:30.

### Tests for User Story 2 (write first)

- [x] T048 [P] [US2] SettingsRepository tests: default 60, clamp 10..600 and snap to 5 s, persists across DB reopen, alert prefs default true/true, active rest round-trip, in test/data/settings_repository_test.dart
- [x] T049 [P] [US2] Rest timer widget tests with fake Clock: appears in footer without shifting the list; counts down from default; per-exercise override; NULL falls back to default; one pulse at 0 then `+m:ss` overtime; correct after simulated 40 s background; tap dismisses; next log restarts — in test/features/workout/rest_timer_test.dart
- [x] T050 [P] [US2] Settings screen widget test: stepper 5 s steps, preset chips 30/60/90/120/180, toggles, value applied to next logged set, in test/features/settings/settings_screen_test.dart

### Implementation for User Story 2

- [x] T051 [US2] Implement SettingsRepository in lib/data/repositories/settings_repository.dart
- [x] T052 [US2] Rest timer controller (stored start timestamp + target, restore after process death, single alert flag, haptic/sound per prefs) in lib/features/workout/rest_timer_controller.dart
- [x] T053 [US2] Rest pill widget in the fixed footer (countdown / muted overtime, tap to dismiss, semantics) in lib/features/workout/widgets/rest_pill.dart; start/restart on every logSet in workout_controller.dart
- [x] T054 [US2] Settings screen (default rest stepper + chips, haptic and sound toggles) at `/settings` with gear icon on Train tab in lib/features/settings/settings_screen.dart
- [x] T055 [US2] Per-exercise *Rest time* row (Default (60 s) or custom stepper, stored in `exercise_state.rest_seconds`) in plan_setup_card.dart and the Edit plan sheet lib/features/workout/widgets/edit_plan_sheet.dart
- [x] T056 [US2] (SHOULD) Rest-end sound via `audioplayers` with bundled asset assets/sounds/rest_end.mp3 (done in feature 002-rest-alerts)
- [x] T057 [US2] (SHOULD) Background rest notification via `flutter_local_notifications` + `timezone` (schedule on log, cancel on dismiss/restart, POST_NOTIFICATIONS permission) in lib/core/rest_notifications.dart (done in feature 002-rest-alerts)

**Checkpoint**: Rest timer and settings work on a phone, including after backgrounding.

---

## Phase 5: User Story 3 – Correct history safely (P2, M4)

**Goal**: History by month, edit mode with auto-save, Resume, Delete, safe base rewriting.

**Independent Test**: PRD §11 scenarios 4–8 pass in repository tests and through the UI.

### Tests for User Story 3 (write first)

- [x] T058 [P] [US3] Repository tests for §11 scenarios 4–8: resume restores base; edit latest set 2 → 9 reps → 20, back to 10 → 22.5; edit older workout leaves current base 25; manual base 30 survives resume + re-finish; delete latest undoes, delete older doesn't; resume blocked when another is active or not most recent; recalculation after clearing a set; legacy workouts without snapshots; delete cascades and queues one pending delete — in test/data/workout_history_test.dart
- [x] T059 [P] [US3] Repository test: `watchHistory` returns finished workouts newest first with volume (per-hand ×2), exercise names, set count, duration, in test/data/workout_history_test.dart
- [x] T060 [P] [US3] Widget test: edit mode footer shows Resume only when allowed; Delete asks confirmation, in test/features/workout/edit_mode_test.dart

### Implementation for User Story 3

- [x] T061 [US3] Implement `recalculate`, `canResume`, `resumeWorkout`, `deleteWorkout` [txn] and recalc-on-edit in logSet/clearSet/addExercise/removeExercise for finished workouts in lib/data/repositories/workout_repository.dart
- [x] T062 [US3] Implement `watchHistory` query in lib/data/repositories/workout_repository.dart
- [x] T063 [US3] History tab grouped by month (date, exercise names, volume in metricVolume, sets, duration; empty state) in lib/features/history/history_screen.dart
- [x] T064 [US3] Edit mode for `/workout/:id` in workout_screen.dart: “Changes save automatically”, footer Done / Resume / Delete with confirmations, add exercise to a past workout

**Checkpoint**: M4 – scenarios 4–8 work in the UI.

---

## Phase 6: User Story 4 – Progress per exercise (P3, M5)

**Goal**: Weekly bars, trained exercise list, exercise detail with charts, PRs, history, plan edit.

**Independent Test**: Exercise detail renders with 1, 2 and 25 sessions; PR badge correct.

### Tests for User Story 4 (write first)

- [x] T065 [P] [US4] Repository tests: `watchTrainedExercises` (most recent first, current base), `history(exerciseId, limit: 20)`, `watchWorkoutsPerWeek` in test/data/progress_queries_test.dart
- [x] T066 [P] [US4] Widget tests: exercise detail with 1, 2 and 25 sessions (chart points ≤ 20, tiles, PR badge, compared-to-previous, History tab rows) in test/features/progress/exercise_detail_test.dart

### Implementation for User Story 4

- [x] T067 [US4] Implement progress queries in lib/data/repositories/exercise_repository.dart and workout_repository.dart
- [x] T068 [P] [US4] WeeklyBarChart (8 ISO weeks, current accent) in lib/widgets/weekly_bar_chart.dart
- [x] T069 [P] [US4] GlowLineChart (smooth curve, glow, gradient fill, highlighted last point) in lib/widgets/glow_line_chart.dart
- [x] T070 [US4] Progress tab (weekly bars + trained exercises with base in metricWeight) in lib/features/progress/progress_screen.dart
- [x] T071 [US4] Exercise detail screen: Summary (tiles Current base / Heaviest set / Est. 1RM / Sessions, chart chips Working weight · Volume · Est. 1RM, PR badge, compared to previous, plan card with Edit) and History tab (sessions newest first, tap → `/workout/:id`) in lib/features/progress/exercise_detail_screen.dart
- [x] T072 [US4] Extend integration_test/workout_flow_test.dart: after finish, exercise detail shows the new base and one chart point

**Checkpoint**: M5 – charts render with 1, 2 and 20+ sessions.

---

## Phase 7: User Story 5 – Home overview and exercise library (P3, M3/M5)

**Goal**: Train-tab stats and recent workouts; picker search and custom exercises.

**Independent Test**: Workouts in 2026-W52, 2026-W53, 2027-W01 → streak 3; search “row”; create
“Hack Squat” and add it.

### Tests for User Story 5 (write first)

- [x] T073 [P] [US5] Repository tests: `watchHomeStats` (this week, streak, total, 3 recent) and `createCustom` (trimmed non-empty name, unique case-insensitive, increment > 0) in test/data/home_and_library_test.dart
- [x] T074 [P] [US5] Widget test: picker search filters, “Create ‘<name>’” appears for unknown names, duplicate name shows error, in test/features/exercises/exercise_picker_test.dart

### Implementation for User Story 5

- [x] T075 [US5] Implement `watchHomeStats` and `createCustom` in the repositories
- [x] T076 [US5] Train tab: date kicker, title, tiles This week · Week streak · Total workouts, 3 recent workouts in lib/features/train/train_screen.dart
- [x] T077 [US5] Picker search + custom exercise form (name, per-hand, increment) in lib/features/exercises/exercise_picker_screen.dart and lib/features/exercises/custom_exercise_sheet.dart

**Checkpoint**: All user stories independently functional.

---

## Phase 8: Polish & Cross-Cutting (M6)

- [x] T078 [P] Haptics pass: tick on taps/steppers, success on log and base increase, warning on clear, across lib/features/
- [x] T079 [P] Accessibility pass: Semantics on every control, 48 dp targets, contrast check, backdrop excluded; TalkBack run (quickstart V11)
- [x] T080 [P] Empty states for Train, History, Progress, exercise detail
- [x] T081 [P] App icon and black splash (placeholder green mark) via flutter_launcher_icons / flutter_native_splash
- [x] T082 Error handling pass: DataException → short SnackBar message, no crash on bad data
- [x] T083 Release signing: android/key.properties + keystore loading in android/app/build.gradle.kts (debug fallback); document keytool steps in README (keystore not created; owner creates it)
- [x] T084 Complete README.md and docs/ARCHITECTURE.md (data flow, progression and edit rules, Phase 2 sync design from PRD §8)
- [ ] T085 Run quickstart.md validation V1–V11; `flutter build apk --release`; install on the phone and use for a real workout (SC-008)
- [ ] T086 Verify performance on device: set logging < 100 ms, cold start < 2 s (SC-001, SC-002)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** → **Foundational (Phase 2)** → user stories.
- **US1 (Phase 3)** is the MVP and must land first: US2–US5 build on the workout screen and
  repositories it creates.
- **US2** and **US3** both depend only on US1 and can proceed in parallel (different files, except
  shared edits to workout_screen.dart / workout_repository.dart — sequence those tasks).
- **US4** depends on US1 (data to chart); **US5** depends on US1 (picker, Train tab).
- **Polish (Phase 8)** after all desired stories.

### Within Each Story

Tests first (must fail) → repository → controller → widgets → screen → integration.

### Milestone mapping

M0 = Phase 1 · M1 = T011–T019 · M2 = T020–T025 + US1/US3 repository tasks · M3 = T026–T032 + US1 UI +
US2 + T076 · M4 = US3 UI · M5 = US4 + T077 · M6 = Phase 8.

## Parallel Example: Foundational

```text
T011, T012, T013, T014  (progression tests, same file but independent groups — write together)
T016, T017, T018        (stats tests)
T026, T028, T029, T030  (tokens, backdrop, haptics/format, UI kit)
```

## Parallel Example: User Story 1

```text
T033 repository tests  |  T034 exercise repo tests  |  T035 set row widget tests
T039 header            |  T040 plan setup card
```

## Implementation Strategy

### MVP First

1. Phases 1–2 (M0, M1, schema, theme).
2. Phase 3 (US1) → **stop and validate** on a real phone with §11 scenarios 1–3.

### Incremental Delivery

US1 → US2 (rest timer) → US3 (history safety) → US4 (progress) → US5 (home stats, library) →
Polish → release APK. Commit at every milestone after format/analyze/test are green.

## Notes

- [P] = different files, no dependency on incomplete tasks.
- Never add LATER/non-goal features (sync, routines, set types, kg/lb, social, light theme).
- 86 tasks total.
