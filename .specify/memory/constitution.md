<!--
Sync Impact Report
- Version change: 1.7.0 → 1.8.0 (feature 017, live snowboarding tracking, owner request
  2026-11-16)
- Modified principles: VI (a saved snowboarding day's per-segment breakdown is backed up with its
  route to the user's own account, like splits); VII (live GPS tracking for snowboarding with
  automatic run / lift / rest detection, speed, vertical drop and run count is in scope;
  barometer-based altitude, resort or piste names, 3D replay, friends and live location sharing
  remain out of scope)
- Added sections: none | Removed sections: none
- Deferred TODOs: none

Previous report (1.7.0)
- Version change: 1.6.0 → 1.7.0 (feature 015, step totals per day in History, owner request
  2026-11-16)
- Modified principles: VII (a selected day's step total in the History calendar is in scope, read
  live from Health Connect for the last 30 days; step goals, charts and data older than 30 days
  remain out of scope)
- Added sections: none | Removed sections: none
- Deferred TODOs: none

Previous report (1.6.0)
- Version change: 1.5.0 → 1.6.0 (feature 014, daily step count, owner approval 2026-11-15)
- Modified principles: VI (step counts are read on device from Health Connect, read-only and
  steps only; they are not stored in the app database and never leave the device); VII (reading
  today's step total from Android Health Connect is in scope, on by default with a Settings switch;
  only data written from the moment access is granted, no historical import. The Google Fit APIs
  are end-of-life at the end of 2026, so Google Fit data is read through Health Connect.
  HealthKit, writing to Health Connect, other health data types, step goals and step history
  remain out of scope)
- Added sections: none (Technology & Platform Constraints adds `health`)
- Removed sections: none
- Deferred TODOs: none

Previous report (1.5.0)
- Version change: 1.4.0 → 1.5.0 (feature 013, cloud backup and sync, owner approval 2026-11-14)
- Modified principles: I (local DB stays the source of truth; sync is a background copy, never
  required for any feature); IV (sync code lives in `data/sync/`, auth in `AuthRepository`; widgets
  never call the backend); VI (opt-in by Google sign-in; owner-only access enforced by the backend;
  saved activity routes may be backed up to the user's own account, raw GPS fixes never leave the
  device; backend URL/anon key via `--dart-define-from-file`, service-role key never in the app);
  VII (Phase 2 sync is in scope; Apple Sign-In, email magic link, live multi-device push and sharing
  remain out of scope)
- Added sections: none (Technology & Platform Constraints adds `supabase_flutter`, `google_sign_in`,
  Supabase CLI migrations with SQL tests on PGlite; Workflow moves M7 into scope)
- Removed sections: none
- Deferred TODOs: none

Previous report (1.4.0)
- Version change: 1.3.0 → 1.4.0 (feature 010, live GPS tracking for running and cycling)
- Modified principles: IV (`TrackingRepository` added to the repositories that own business writes);
  VI (location data stays on device; only map tile requests leave it; the map key comes from
  `--dart-define-from-file` as `MAP_TILES_KEY`); VII (live GPS tracking for running and cycling,
  with an in-app map via a tile provider, is in scope, owner approval 2026-11-14; snowboarding
  tracking, Health Connect/HealthKit import, GPX export, miles and offline tile download remain out
  of scope until requested)
- Added sections: none (Technology & Platform Constraints lists geolocator, flutter_map, latlong2)
- Removed sections: none
- Deferred TODOs: none

Previous report (1.3.0)
- Version change: 1.2.1 → 1.3.0 (feature 009, Pilates and manual distance)
- Modified principles: VII (manual distance entry for running and cycling is now in scope, owner
  request 2026-11-14; live GPS tracking, routes, maps and sensors remain out of scope until the
  owner requests them)
- Added sections: none | Removed sections: none
- Deferred TODOs: none

Previous report (1.2.1)
- Version change: 1.2.0 → 1.2.1 (feature 007, workout flow and exercise library)
- Modified principles: II (finishing a workout rewrites a plan's base only when it is the newest
  session for that plan; backdated or resumed older sessions never do) — PATCH clarification
- Added sections: none | Removed sections: none
- Deferred TODOs: none

Previous report (1.2.0)
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

- The on-device SQLite database (drift) is the single source of truth. 100% of features MUST
  work with no network connection, signed in or not. Cloud sync (feature 013) is a background copy
  of the local data; no screen may read from or wait on the backend.
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
  Finishing a workout likewise rewrites a plan's base only when it is the newest session for that
  plan; backdated or resumed older sessions never do.

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
- Widgets MUST NOT touch the database or the backend; they reach repositories (including
  `AuthRepository`) and the sync service through Riverpod providers. Sync code lives in
  `lib/data/sync/` behind an interface with an in-memory fake for tests.
  No business logic in widgets.
- All business writes go through repositories (`WorkoutRepository`, `ExerciseRepository`, `TemplateRepository`, `ActivityRepository`, `TrackingRepository`).
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
- No analytics or trackers. Data stays on device until the user opts into sync by signing in with
  Google; there are no anonymous cloud accounts.
- Synced data MUST be readable and writable only by its owner, enforced by backend row-level
  security on every table (not only by the app) and covered by automated tests.
- Backend URL and anon key come from `--dart-define-from-file` (`env/dev.json`, git-ignored); the
  service-role key MUST never ship in the app or the repo.
- Raw GPS fixes and in-progress tracking sessions never leave the device. A saved activity's
  simplified route, splits and snowboarding segment breakdown are backed up only to the signed-in user's own account. Apart from
  sync, the only network traffic live tracking adds is map tile requests to the tile provider. The map key is read from `--dart-define-from-file`
  (`MAP_TILES_KEY` in `env/dev.json`, git-ignored); without it the app still works and draws routes
  on a plain background.
- Step counts (feature 014) are read on device from Health Connect with a read-only steps
  permission. They are shown, never written to the app database, never synced and never sent
  anywhere; the user can turn the feature off in Settings, after which nothing is read.
- The app MUST never crash on bad data: DB errors are caught, logged, and shown as a short message;
  sync errors are silent and retried.

Rationale: a personal health log is private data; leaked keys are irreversible.

### VII. Scope Discipline (YAGNI)

- Build only what the PRD marks MUST/SHOULD for v1. LATER items (kg/lb, drop/failure sets, plate
  calculator, deload) MUST NOT be implemented early.
- Explicit non-goals MUST NOT appear in code or schema: no social/friends/feed/leaderboards, no
  `visibility` or friendship columns, no warm-up sets, no set-type column or W/D/F badges, no light
  theme, no videos, no AI workouts, no ads or paid features.
- Lightweight logging of sport activities besides gym workouts (feature 006, owner request) is in
  scope. Manual distance entry for running and cycling, with derived pace or speed (feature 009,
  owner request 2026-11-14), is in scope. Live GPS tracking for running and cycling (distance,
  pace, route, splits) with an in-app map via a tile provider (feature 010, owner approval
  2026-11-14) is in scope. Today's step total read from Android Health Connect (feature 014, owner
  approval 2026-11-15; this is how Google Fit data reaches the app) is in scope, on by default
  with a Settings switch, new data only; a selected day's total in the History calendar (feature
  015, owner request 2026-11-16) is in scope for the last 30 days. Live GPS tracking for
  snowboarding (feature 017, owner request 2026-11-16) with automatic run / lift / rest
  detection, current / average / max speed, ride distance, vertical drop and run count is in
  scope, using GPS altitude only. Barometer-based altitude, resort or piste names, 3D replay,
  HealthKit, writing to Health Connect, other health data types, step goals and charts, GPX
  export, miles and offline tile download remain out of scope until the owner requests them.
- Phase 2 cloud backup and sync with Google sign-in (feature 013, owner approval 2026-11-14) is in
  scope, Android only. Apple Sign-In, email magic link, live push between devices and any sharing
  between users remain out of scope until the owner requests them.

Rationale: the owner explicitly dropped these; speculative code is maintenance debt.

## Technology & Platform Constraints

- Flutter stable (latest) + Dart with sound null safety; Android first (APK), iOS later.
- Packages: `flutter_riverpod`, `go_router`, `drift` (+ SQLite libs), `fl_chart` or `CustomPainter`,
  `uuid`, `intl`, `geolocator` (location), `flutter_map` + `latlong2` (map), `supabase_flutter` +
  `google_sign_in` (sync, auth), `health` (Health Connect steps); tests with `flutter_test`, `mocktail` if needed.
- Backend schema, triggers and row-level security live as Supabase CLI migrations in
  `supabase/migrations/`, tested by SQL tests on PGlite (`node tool/db_test.mjs`, also in CI).
- Android application id `com.fitapp.app`; app name **FitApp**; kg only internally and in the UI.
- Builds are local (`flutter build apk`); no third-party build cloud.
- Generated code (`*.g.dart`) policy is chosen once (commit or generate in CI) and documented in
  the README.

## Development Workflow & Quality Gates

- Work proceeds milestone by milestone (M0 → M7) as defined in the PRD; M7 (sync) is feature 013.
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

**Version**: 1.8.0 | **Ratified**: 2026-11-12 | **Last Amended**: 2026-11-16
