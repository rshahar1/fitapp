# Implementation Plan: FitApp v1 – Offline Workout Logger with Automatic Progressive Overload

**Branch**: `001-fitapp-v1` | **Date**: 2026-11-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-fitapp-v1/spec.md`; product source of truth
`docs/PRD-fitapp-flutter.md` (v2.1).

## Summary

Build an Android-first Flutter app that logs gym workouts offline and applies a deterministic
progressive-overload rule. The progression and stats logic is a pure Dart domain layer with 100%
test coverage; persistence is a drift (SQLite) database with versioned migrations and transactional
repositories implementing finish / resume / edit / delete with plan snapshots and the
`canRewriteBase` safety rule. The UI is a Material 3, always-dark, Hevy-structured app (Train,
History, Progress tabs) built with Riverpod and go_router, featuring one-tap set logging, a
timestamp-based rest timer in a fixed footer, and fl_chart progress charts. Work proceeds in PRD
milestones M0–M6; Phase 2 sync (M7) is designed for in the schema but not built.

## Technical Context

**Language/Version**: Dart 3.14 (sound null safety), Flutter 3.50 stable (latest on 2026-11-12)

**Primary Dependencies**: flutter_riverpod 3.x (no Riverpod codegen), go_router 18.x, drift 2.35 +
drift_flutter 0.3 (drift_dev + build_runner for codegen), fl_chart 1.3, uuid 4.x, intl 0.20;
SHOULD-level: flutter_local_notifications 23.x (+ timezone) for background rest alerts,
audioplayers 6.x for the rest-end sound. See [research.md](./research.md).

**Storage**: On-device SQLite via drift; schema version 1 with migration strategy; foreign keys ON;
local `settings` key/value table. Details in [data-model.md](./data-model.md).

**Testing**: flutter_test (unit + widget), drift `NativeDatabase.memory()` for data tests,
integration_test for the end-to-end flow, mocktail only if needed; coverage via
`flutter test --coverage` (domain progression = 100%).

**Target Platform**: Android (Flutter default minSdk), portrait only; iOS scaffolded but not
released in v1.

**Project Type**: mobile-app (single Flutter project, no backend in v1)

**Performance Goals**: set logging reflected in UI < 100 ms; cold start < 2 s on a mid-range phone;
60 fps scrolling of the set table and charts.

**Constraints**: 100% offline; no data loss on process kill (every set written immediately);
multi-row writes in one transaction; no secrets in git; no analytics; kg only.

**Scale/Scope**: single user per device; ~5 primary screens + settings + picker + sheets; history
of hundreds of workouts / thousands of sets; 16 seeded exercises plus custom ones.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Pre-design | Post-design |
|---|---|---|---|
| I. Offline-first | Local drift DB is source of truth; UUID v4 ids; `updated_at`/`dirty`; migrations; transactions for multi-row writes | ✅ | ✅ data-model.md defines all tables, txn boundaries in contracts/repositories.md |
| II. Pure, tested domain | `lib/domain/` has no Flutter/DB imports; 100% coverage on progression; §11 scenarios as tests | ✅ | ✅ contracts/domain-api.md is pure Dart signatures |
| III. Test-first gates | Tests precede implementation per task; format/analyze/test + CI per milestone | ✅ | ✅ tasks will order tests before code |
| IV. Layered architecture | Widgets → providers → repositories → drift; theme tokens only | ✅ | ✅ project structure below |
| V. One-tap UX | One-tap check box; fixed footer timer; 48 dp; semantics; confirmations | ✅ | ✅ contracts/ui-routes.md |
| VI. Safety & secrets | env via dart-define-from-file; keystore ignored; full .gitignore; no trackers | ✅ | ✅ quickstart.md |
| VII. Scope discipline | No social, set types, light theme, sync code, kg/lb | ✅ | ✅ schema has no set_type/visibility columns |

No violations. Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-fitapp-v1/
├── spec.md              # Feature spec (/speckit-specify)
├── plan.md              # This file
├── research.md          # Phase 0: technology decisions
├── data-model.md        # Phase 1: tables, fields, rules, state transitions
├── quickstart.md        # Phase 1: setup and validation guide
├── contracts/
│   ├── domain-api.md    # Pure Dart domain signatures and semantics
│   ├── repositories.md  # Repository interfaces and transaction contracts
│   └── ui-routes.md     # Routes, screens, and UI behavior contract
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── main.dart
├── app/
│   ├── app.dart                 # MaterialApp.router, portrait lock
│   ├── router.dart              # go_router: shell (3 tabs) + full-screen routes
│   ├── theme/
│   │   ├── tokens.dart          # colors, spacing, radii, tap sizes (PRD §2.2)
│   │   ├── app_theme.dart       # dark ThemeData (Material 3)
│   │   └── metric_colors.dart   # ThemeExtension for metric colors
│   └── backdrop.dart            # CustomPainter backdrop, ExcludeSemantics
├── core/
│   ├── format.dart              # formatKg, durations, deltas
│   ├── iso_week.dart            # ISO week keys (Monday start, W53)
│   ├── haptics.dart             # tick / success / warning wrapper
│   ├── clock.dart               # injectable clock for timers and tests
│   └── result.dart              # error/result helpers
├── domain/                      # PURE Dart
│   ├── progression.dart         # Plan, PrescribedSet, LoggedSet, prescribe, evaluate, roundWeight, canRewriteBase
│   └── stats.dart               # volume, epley1RM, PRs, newPRTypes, summarizeSession, diffSummary, weekly counts, streak
├── data/
│   ├── db/
│   │   ├── tables.dart          # drift tables
│   │   ├── app_database.dart    # @DriftDatabase, migrations, FK pragma
│   │   ├── app_database.g.dart  # generated (committed; see research R4)
│   │   └── seed_library.dart    # 16 exercises, fixed UUIDs, idempotent upsert
│   ├── repositories/
│   │   ├── exercise_repository.dart
│   │   ├── workout_repository.dart
│   │   └── settings_repository.dart
│   └── providers.dart           # Riverpod providers for db + repositories
├── features/
│   ├── shell/                   # bottom navigation scaffold
│   ├── train/                   # home tab
│   ├── workout/                 # live + edit screen, set table, set sheet, plan setup, rest timer, finish summary
│   ├── history/
│   ├── progress/                # weekly chart, exercise list, exercise detail
│   ├── exercises/               # picker, custom exercise
│   └── settings/
└── widgets/                     # AppButton, AppCard, Group/GroupRow, SectionHeader, AppStepper,
                                 # ChipSelector, MetricTile, Delta, Stat, GlowLineChart, WeeklyBarChart

test/                            # mirrors lib/
├── domain/  data/  core/  widgets/  features/
integration_test/
└── workout_flow_test.dart
android/  ios/                   # flutter create output; applicationId com.fitapp.app
env/example.json                 # empty config values (committed)
docs/PRD-fitapp-flutter.md  docs/ARCHITECTURE.md
.github/workflows/ci.yml
```

**Structure Decision**: Single Flutter project with the feature-first, layered layout from PRD §9.2.
`domain/` is pure Dart; `data/` owns all persistence and transactions; `features/` hold screens and
their controllers (Riverpod notifiers) and never touch drift directly. Supabase `data/sync/` is not
created in v1 (constitution VII).

## Milestone mapping

| Milestone | Spec stories | Plan artifacts |
|---|---|---|
| M0 Setup | foundation | quickstart.md, research R1–R4, R10 |
| M1 Domain | US1, US3, US4, US5 logic | contracts/domain-api.md |
| M2 Data | US1, US3 persistence | data-model.md, contracts/repositories.md |
| M3 UI kit + live workout + settings | US1, US2, US5 (Train) | contracts/ui-routes.md, research R5–R8 |
| M4 History & edit mode | US3 | contracts/ui-routes.md |
| M5 Progress & exercise detail | US4 | research R6 |
| M6 Polish & release APK | all | quickstart.md, research R9 |

## Complexity Tracking

No constitution violations; nothing to justify.
