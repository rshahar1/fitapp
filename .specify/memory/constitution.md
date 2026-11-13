<!--
Sync Impact Report
- Version change: 1.1.0 → 1.2.0 (feature 006, sport activities)
- Modified principles: IV (`ActivityRepository` added to the repositories that own business writes);
  VII (lightweight sport activity logging is in scope, owner request; sport-specific metrics and
  tracking modules remain out of scope until requested)
- Added sections: none | Removed sections: none
- Deferred TODOs: none

Previous report (1.1.0)
- Version change: 1.0.0 → 1.1.0 (feature 005, template progression)
- Modified principles: II (history safety is per plan; flag name `canRewriteBase`);
  IV (business writes also go through `TemplateRepository`); VII (routines/templates removed from
  the LATER list, they exist since feature 003)
- Added sections: none | Removed sections: none
- Deferred TODOs: none

Previous report (1.0.0)
- Version change: template → 1.0.0 (initial ratification)
- Principles defined: I. Offline-First, Local Source of Truth; II. Pure, Fully Tested Domain;
  III. Test-First Quality Gates; IV. Layered Feature-First Architecture; V. One-Tap Gym UX;
  VI. Safety, Privacy and Secrets Hygiene; VII. Scope Discipline (YAGNI)
- Added sections: Technology & Platform Constraints; Development Workflow & Quality Gates
- Removed sections: none
- Templates: plan/spec/tasks templates read the constitution at runtime; no edits required
- Deferred TODOs: none
-->

# FitApp Constitution

## Core Principles

### I. Offline-First, Local Source of Truth

- The on-device SQLite database (drift) is the single source of truth. 100% of v1 features
  MUST work with no network connection.
- Every logged set MUST be persisted immediately; killing the app mid-workout MUST NOT lose data.
- All ids MUST be client-generated UUID v4; timestamps MUST be ISO-8601 UTC; every syncable
  table carries `updated_at` and `dirty` so Phase 2 sync can be added without schema rewrites.
- Schema changes MUST ship as versioned migrations that never drop user data. Foreign keys are ON.
- Writes that touch several rows (finish, resume, recalculate, delete) MUST run in one transaction.

Rationale: gyms often have no signal, and a lost workout destroys trust in the progression engine.

### II. Pure, Fully Tested Domain (NON-NEGOTIABLE)

- Progression (`prescribe`, `evaluate`, `roundWeight`, `canRewriteBase`) and stats (volume,
  Epley 1RM, PRs, session summary/diff, ISO weeks, streak) MUST live in `lib/domain/` as pure Dart
  with no Flutter, DB or I/O imports.
- The progression engine MUST have 100% line coverage, and every worked scenario in PRD section 11
  MUST exist as an executable test.
- All weights MUST pass through `roundWeight` (nearest 0.25 kg); comparisons of weights happen
  after rounding.
- Editing, resuming or deleting history MUST respect `canRewriteBase`: the current base of a plan
  (the exercise's own plan or a template exercise's plan) is rewritten only when the workout is the
  latest session for that plan AND the current base equals the stored `resultBaseWeight`.

Rationale: automatic progressive overload is the product; a wrong base weight is the worst bug.

### III. Test-First Quality Gates

- Domain and data behavior MUST be specified by failing tests before implementation
  (red → green → refactor).
- Data-layer tests run against drift's in-memory database; widget tests cover set rows, the rest
  timer and settings; an integration test covers the end-to-end workout flow.
- Every milestone ends with `dart format --set-exit-if-changed`, `flutter analyze` (zero warnings,
  `very_good_analysis` or stricter) and `flutter test` all green, followed by a focused commit.
- CI (GitHub Actions) runs the same gates plus `flutter build apk --debug` on push and PR.

Rationale: correctness of history edits is subtle; only tests make refactoring safe.

### IV. Layered, Feature-First Architecture

- Layout: `app/` (router, theme, backdrop), `core/`, `domain/` (pure), `data/` (db, repositories,
  sync), `features/<feature>/`, `widgets/` (shared UI kit); `test/` mirrors `lib/`.
- Widgets MUST NOT touch the database; they reach repositories through Riverpod providers.
  No business logic in widgets.
- All business writes go through repositories (`WorkoutRepository`, `ExerciseRepository`, `TemplateRepository`, `ActivityRepository`).
- Colors, spacing, radii and type MUST come from the theme (tokens + `ThemeExtension`); no
  hard-coded colors or sizes in widgets.
- Prefer Flutter/Material 3 built-ins over third-party UI kits; every added package MUST be
  current, maintained and null-safe on pub.dev.

Rationale: a strict layering keeps the domain testable and the UI replaceable.

### V. One-Tap, Glanceable Gym UX

- Logging a set exactly as prescribed MUST take one tap; editing uses a bottom sheet with large
  steppers. Set logging MUST update the UI in < 100 ms.
- Nothing may shift layout right after a tap (the rest timer lives in a fixed footer).
- Always-dark theme, one accent color for actions, a fixed color per metric, tabular figures.
- Minimum tap target 48×48 dp (steppers 56×60); portrait only; one-handed use.
- All interactive controls carry `Semantics` labels; decorative layers (backdrop) are excluded.
- Destructive actions (remove exercise, delete workout, discard workout) always ask to confirm.
- Hevy is the structural reference only: no copying of its name, branding, icons, copy or exact
  layouts.

Rationale: the user is sweaty, distracted and between sets; mis-taps corrupt data.

### VI. Safety, Privacy and Secrets Hygiene

- No secrets in the repo, ever: config via `--dart-define-from-file=env/dev.json`; only
  `env/example.json` (empty values) is committed. Keystores and `android/key.properties` are never
  committed.
- `.gitignore` MUST cover every path listed in PRD section 9.3; no IDE folders or build output in git.
- No analytics or trackers in v1; data stays on device until the user opts into Phase 2 sync.
- The app MUST never crash on bad data: DB errors are caught, logged, and shown as a short message;
  sync errors are silent and retried.

Rationale: a personal health log is private data; leaked keys are irreversible.

### VII. Scope Discipline (YAGNI)

- Build only what the PRD marks MUST/SHOULD for v1. LATER items (Supabase sync, kg/lb,
  drop/failure sets, plate calculator, deload) MUST NOT be implemented early.
- Explicit non-goals MUST NOT appear in code or schema: no social/friends/feed/leaderboards, no
  `visibility` or friendship columns, no warm-up sets, no set-type column or W/D/F badges, no light
  theme, no videos, no AI workouts, no ads or paid features.
- Lightweight logging of sport activities besides gym workouts (feature 006, owner request) is in
  scope. Sport-specific metrics and tracking modules (distance, pace, routes, ...) remain out of
  scope until the owner requests them.
- Phase 2 is designed for (UUIDs, `dirty`, `pending_deletes`) but not built.

Rationale: the owner explicitly dropped these; speculative code is maintenance debt.

## Technology & Platform Constraints

- Flutter stable (latest) + Dart with sound null safety; Android first (APK), iOS later.
- Packages: `flutter_riverpod`, `go_router`, `drift` (+ SQLite libs), `fl_chart` or `CustomPainter`,
  `uuid`, `intl`; tests with `flutter_test`, `mocktail` if needed. `supabase_flutter` only in Phase 2.
- Android application id `com.fitapp.app`; app name **FitApp**; kg only internally and in the UI.
- Builds are local (`flutter build apk`); no third-party build cloud.
- Generated code (`*.g.dart`) policy is chosen once (commit or generate in CI) and documented in
  the README.

## Development Workflow & Quality Gates

- Work proceeds milestone by milestone (M0 → M6) as defined in the PRD; M7 (sync) is LATER.
- Each milestone: tests first, implementation, then format + analyze + test green, show results,
  and commit with a small, clear message using the owner's GitHub no-reply email.
- The repository is a private GitHub repo named `fitapp`; no LICENSE file.
- Required docs: README (purpose, progression rule, setup, run, test, build APK, layout, roadmap),
  `docs/ARCHITECTURE.md`, `.editorconfig`, `analysis_options.yaml`.

## Governance

- This constitution supersedes other practices; the PRD (`docs/PRD-fitapp-flutter.md`) is the
  authoritative source of product requirements, and the constitution governs how they are built.
- Every plan MUST pass the Constitution Check gate; any violation is recorded in the plan's
  Complexity Tracking table with a justification, or the plan is changed.
- Amendments: edit this file via `/speckit-constitution`, include a Sync Impact Report, and bump the
  version (MAJOR: principle removed/redefined; MINOR: principle/section added; PATCH: wording).
- Reviews verify compliance with principles II, III and VI on every milestone.

**Version**: 1.2.0 | **Ratified**: 2026-11-12 | **Last Amended**: 2026-11-13
