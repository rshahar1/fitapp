# Research: FitApp v1

Phase 0 decisions. Package versions were checked on pub.dev on 2026-11-12; re-check at M0 and pin
with caret ranges in `pubspec.yaml`.

## R1. Flutter SDK and toolchain

- **Decision**: Flutter stable 3.50.0 (Dart 3.14), released 2026-11-11. JDK 17, Android SDK via
  command-line tools or Android Studio. `flutter doctor` must be green for Android.
- **Rationale**: PRD requires latest stable; all chosen packages support Dart ≥ 3.12.
- **Alternatives**: beta channel (rejected: stability), FVM pinning (optional; can add `.fvmrc` later).
- **Note**: Flutter is **not yet installed** on the development Mac (checked 2026-11-12); M0 starts by
  installing it.

## R2. State management

- **Decision**: `flutter_riverpod` ^3.5 using hand-written `Notifier`/`AsyncNotifier` and
  `StreamProvider`s over drift `watch()` queries. No `riverpod_generator`.
- **Rationale**: PRD makes codegen optional; avoiding it keeps one codegen pipeline (drift only) and
  avoids version coupling between riverpod_annotation 4.x and flutter_riverpod 3.x.
- **Alternatives**: Riverpod codegen (more boilerplate-free but extra build step), Bloc (heavier).

## R3. Routing

- **Decision**: `go_router` ^18.1 with a `StatefulShellRoute.indexedStack` for the three tabs and
  top-level full-screen routes (`/workout`, `/workout/:id`, `/exercise/:id`, `/add-exercise`,
  `/settings`). The picker is pushed as a fullscreen-dialog page.
- **Rationale**: keeps per-tab state, correct Android back handling, deep-linkable ids.
- **Alternatives**: Navigator 2 by hand (verbose), auto_route (codegen).

## R4. Local database and generated code

- **Decision**: `drift` ^2.35 + `drift_flutter` ^0.3 (`driftDatabase(name: 'fitapp')`), `drift_dev` +
  `build_runner` as dev deps. `PRAGMA foreign_keys = ON` in `beforeOpen`. `MigrationStrategy` with
  `schemaVersion = 1`, and drift's `make-migrations` / schema dumps (`drift_schemas/`) so future
  migrations are tested. **Generated `*.g.dart` files are committed**; CI runs
  `dart run build_runner build --delete-conflicting-outputs` and fails if `git diff` is non-empty.
- **Rationale**: committing generated code makes `flutter run` work right after clone; the CI diff
  check keeps it honest. `sqlite3_flutter_libs` is end-of-life (0.6.0+eol): current `sqlite3`/
  `drift_flutter` bundle SQLite via build hooks, so do **not** add `sqlite3_flutter_libs`.
- **Alternatives**: sqflite (no type safety or migrations tooling), Isar/Hive (not relational;
  progression needs joins and transactions).

## R5. Rest timer

- **Decision**: store `restStartedAt` (UTC) and `restTargetSeconds` in a Riverpod notifier, persisted
  to the `settings` table under `active_rest_*` keys so it survives process death. The pill derives
  `remaining = target − (now − start)` from an injectable `Clock`, redrawn by a 1 s `Ticker`/
  `Timer.periodic` that only triggers repaint. On crossing 0 (detected on tick or on app resume), fire
  haptic + sound once (`alerted` flag).
- **Background (SHOULD, FR-019)**: `flutter_local_notifications` ^23 `zonedSchedule` at rest end
  (requires `timezone`, Android 13+ POST_NOTIFICATIONS permission, exact-alarm permission optional —
  use inexact if denied). Cancel/reschedule on each logged set or dismiss. Implement after the core
  timer; skip if it threatens M3.
- **Sound (SHOULD)**: `audioplayers` ^6.8 with a short bundled asset; `SystemSound` is not usable for
  an alert on Android.
- **Alternatives**: ticking counter (drifts and breaks in background – rejected by PRD).

## R6. Charts

- **Decision**: `fl_chart` ^1.3 `LineChart` (curved, gradient below bar, shadow for glow, highlighted
  last spot) and `BarChart` for weekly bars. Backdrop drawn with `CustomPainter`.
- **Rationale**: mature, supports all required styling; CustomPainter fallback for glow if needed.
- **Alternatives**: syncfusion (license), custom painter only (more work).

## R7. Theming

- **Decision**: Material 3 `ThemeData` with `ColorScheme.dark` built from tokens; `MetricColors`
  `ThemeExtension`; tabular figures via `FontFeature.tabularFigures()` in number text styles;
  `SystemChrome.setPreferredOrientations([portraitUp])`.
- **Rationale**: constitution IV/V; no hard-coded colors.

## R8. Haptics

- **Decision**: wrapper over `HapticFeedback.selectionClick` (tick), `mediumImpact` (success),
  `heavyImpact` (warning); disabled when the rest-alert haptic toggle is off only for the timer
  pulse. Wrapper is injectable for widget tests.

## R9. Release build and signing

- **Decision**: `android/key.properties` + `upload-keystore.jks` outside git; `build.gradle.kts` reads
  them if present and falls back to debug signing. Document `keytool` creation in README. App icon and
  splash via `flutter_launcher_icons` / `flutter_native_splash` as dev deps (black background,
  placeholder green mark) in M6.

## R10. Lints, formatting, CI

- **Decision**: `very_good_analysis` ^11 in `analysis_options.yaml` (exclude `**/*.g.dart`), relax
  `public_member_api_docs` for app code. GitHub Actions (`subosito/flutter-action`, channel stable):
  pub get → build_runner diff check → `dart format --output=none --set-exit-if-changed .` →
  `flutter analyze` → `flutter test --coverage` → `flutter build apk --debug`.
- **Git identity**: commits use the owner's GitHub no-reply email; repo is private `fitapp`
  (create with `gh repo create fitapp --private` when the owner approves).

## R11. IDs and time

- **Decision**: `uuid` ^4.6 `Uuid().v4()` for all new rows; seed exercises use the fixed scheme
  `00000000-0000-4000-8000-%012x`. All timestamps stored as UTC ISO-8601 text via drift
  `DateTime` columns with `storeDateTimeValuesAsText: true`.

## Open items

None blocking. App icon artwork remains a placeholder (PRD §16).
