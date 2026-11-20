# Architecture

## Data flow

- Widgets (in `lib/features/` and `lib/widgets/`) never touch the database directly.
- Widgets read and mutate state through Riverpod providers.
- Providers call repositories (`WorkoutRepository`, `ExerciseRepository`, `TemplateRepository`, `ActivityRepository`, `TrackingRepository`), which own all business writes and transactions.
- Repositories use the drift database (local SQLite, source of truth); the progression logic in `lib/domain/` is pure Dart.
- Providers live in `lib/data/providers.dart` (Riverpod 3, no codegen).
- Read models are streams built with `watchQuery` in `lib/data/watch.dart`: it runs a loader and re-runs it whenever any table it reads is updated, so screens refresh automatically after writes.

```
widget -> provider (lib/data/providers.dart) -> repository -> drift (SQLite)
   ^                                                              |
   +---------------- watchQuery stream (lib/data/watch.dart) <----+
```

## Progression and edit rules

Rules follow PRD sections 4.2 to 4.4. The evaluation itself (`lib/domain/progression.dart`) is pure Dart: sets 1..N-1 at base, set N at base + increment, weights rounded to 0.25 kg. Only the working sets decide. Checked in order: working set missing gives `incomplete`; working set under target reps or under base weight gives `missed_reps`; otherwise `progressed` with next base `roundWeight(base + increment)`. The overload set never affects the result, and exercises without a plan never progress.

### Plan sources

A plan lives in one of two places, and each workout exercise resolves to one source:

- **Exercise plan**: `exercise_state`, used by ad-hoc workouts and exercises added ad hoc.
- **Template plan**: the plan on a `template_exercises` row. A workout started from a template sets `workout_exercises.template_exercise_id` (nullable, indexed, no FK) on each exercise.
- **Orphan**: the template exercise was deleted. Its finished sessions never change any plan. A live session with no snapshot is unlinked and falls back to the exercise plan.

Template workouts never update the exercise's own plan. `PlanStore` (`lib/data/repositories/plan_store.dart`, an extension used by the repositories) does the validated reads and writes for both kinds (`StoredPlan`, `PlanSourceKind` in `lib/data/models.dart`); `WorkoutRepository.savePlan(workoutExerciseId, StoredPlan)` writes to the source of that workout exercise.

Implementation in `WorkoutRepository`:

- On finish (transactional), for each planned exercise with logged sets: `plan = snapshot ?? current plan of its source`, evaluate, store a snapshot (plan base, reps, sets, increment, `resultBaseWeight`), then advance the base of that source if progressed.
- The base is advanced only if it still equals `plan.baseWeight`, so a hand-edited base is never overwritten.
- `canRewriteBase(isLatestSessionForPlan, currentBase, resultBaseWeight)` is true only if the workout is the latest finished session of the same plan (ad-hoc sessions of that exercise, or sessions of that template exercise) and the current base equals the `resultBaseWeight` it produced (after rounding).
- Editing a finished workout re-evaluates against the snapshot and rewrites the base if `canRewriteBase`; resume (latest finished workout only, none in progress) and delete undo progression under the same condition.
- Legacy sessions without a snapshot use the current plan of their source only if they are the latest session of that plan; otherwise they are not re-evaluated.
- Summary on finish lists each progressed or unchanged exercise; a workout with no logged sets is offered for discard.

## Sport activities

- Registry: `lib/domain/activity_types.dart` (pure Dart) holds the ordered `activityTypes` list of `ActivityType(id, label, {hasDistance})` with stable ids `functional`, `cycling` (distance), `snowboarding` (distance, live tracking), `running` (distance), `pilates`, plus `activityTypeById`, `activityLabel` ("Activity" for unknown ids) and `validateActivity` (known type, day not in the future, duration 1 to 1440 minutes, note at most 200 chars after trimming, distance 1 to 1,000,000 metres and only for types with `hasDistance`). Pure helpers `parseDistanceKm` (km text to metres, rounded to 10 m), `formatDistanceKm`, `formatPace` and `formatSpeed` serve the sheet and History. Rows store only `type_id`, so adding a sport is one registry entry plus one icon.
- Icons are a UI concern: `lib/features/activities/activity_icons.dart` maps type ids to icons; gym workouts use a dumbbell icon.
- Table `activities`: `id` (UUID), `type_id`, `started_at`, `duration_minutes` (nullable), `distance_meters` (nullable, v5), `notes` (nullable), `updated_at`, `dirty`, index on `started_at`. Deletes are queued in `pending_deletes`.
- `ActivityRepository` owns create, update, delete, list and watch.
- Merged history: `WorkoutRepository.historyEntries()` merges finished workouts and activities newest first as a sealed `HistoryEntry` (`WorkoutHistoryEntry` | `ActivityHistoryEntry`), exposed by `historyEntriesProvider`. History groups it by month; tapping an activity opens the sheet to edit or delete (delete confirmed).
- Stats: week stats use the union of finished-workout dates and activity dates, so activities count toward This week, Week streak and the Progress weekly bars. Total workouts stays gym only, the Train Recent list stays workouts only, and activities never affect volume, exercise stats or progression.

## Live GPS tracking

- Layers: pure domain in `lib/domain/tracking/` (`TrackSample`, `TrackProfile` for running and cycling, `TrackState`, `track_reducer.dart`, `TrackSummary`, `geo.dart`). The reducer folds samples into state (distance, moving time, auto-pause, per-km splits, elevation gain, route simplification), ignores fixes with accuracy over 20 m or impossible speed, and is replayable: the same stored points always give the same result. Below it, `TrackingRepository` (`lib/data/repositories/tracking_repository.dart`) owns start, append points, pause, load points, finish and discard; `LocationSource` (`lib/data/tracking/location_source.dart`, `GeolocatorLocationSource` the real one, fakes in tests) wraps permission, service state and the fix stream. `TrackingController` (`lib/features/tracking/tracking_controller.dart`, Riverpod) combines them into a `TrackingUiState` (idle, acquiring, live). Screens: `TrackSetupScreen`, `LiveTrackScreen`, `FinishSheet`, with `RouteMap` and footer controls in `widgets/`.
- Tables (schema v6): `tracking_sessions` (the single live session, local only), `track_points` (raw fixes, cascade delete) and the tracked columns on `activities` (`source`, `moving_seconds`, `elevation_gain_meters`, `route` encoded polyline, `splits` JSON).
- Route thinning (feature 017, `lib/domain/tracking/live_route.dart`): the live route keeps a point only when it is at least 10 m from the last kept one and halves itself past 2,000 points; this applies to every tracked type.
- Crash recovery: the controller buffers fixes and writes them in batches (every 5 s or 20 points). On launch `recoverTrackingOnLaunch` (`launch_recovery.dart`) looks for a leftover session, replays its points through the reducer, resumes the location stream and opens `/track/live`. At most about 5 s of track is lost.
- One live session: a gym workout in progress and a tracking session exclude each other; starting one while the other exists shows a message with a button to open it.
- Finish: `TrackingRepository.finish` runs in one transaction: it replays the points, writes one `activities` row (`source = gps`) with the simplified route and splits, and deletes the session and its raw points. Discard deletes them without an activity.
- Map and fallback: `RouteMap` uses `flutter_map` with MapTiler tiles when `MAP_TILES_KEY` (`--dart-define-from-file`) is set; with no key or no network it draws the route on a plain dark background. History thumbnails are drawn locally with no tiles. Location data never leaves the device; only tile requests do.

## Live snowboarding tracking (feature 017)

- Domain (pure Dart, `lib/domain/tracking/`), beside the unchanged `track_reducer.dart`: `snow_state.dart` (`SnowKind`, `SnowSegment`, immutable `SnowState` with closed segments, current segment, candidate and signal windows, and a getter per metric), `snow_reducer.dart` (the run / lift / rest classification state machine from GPS speed and smoothed GPS altitude, thresholds in `SnowTuning`; `startSnow`, `accumulateSnow`, `pauseSnow`, `replaySnow`, run count as descents between lifts with at least 30 m of drop), `snow_summary.dart` (`SnowSummary`, `summarizeSnow`, stored segment records, descents, `encodeSegments` / `decodeSegments`) and `snow_review.dart` (read side: day stats, best-run badges, run comparison, heatmap scale, replay interpolation). `TrackProfile.snowboarding` never auto-pauses; a manual pause closes the current segment.
- Controller: `TrackingController` carries a `SnowState?` next to the `TrackState` (fed with accepted fixes, rebuilt on recovery, paused and resumed with the track) and exposes it as `TrackingLive.snow`. `TrackingRepository.finish` replays the snow reducer over the accepted fixes and writes the snowboarding columns in the same transaction; other types are unchanged.
- Schema v9 (`from8To9`): six nullable columns on `activities`: `vertical_drop_meters`, `run_count`, `max_speed_mps`, `lift_seconds`, `rest_seconds` and `segments` (JSON list of run, lift and rest segments; run segments also carry per-route-point speed `p`, seconds `q` and altitude `h` arrays, so the heatmap and replay work after the raw points are deleted). `distance_meters` holds the ride distance and `moving_seconds` the ride time. Server migration `supabase/migrations/20261116000001_activities_snowboard.sql` adds the same columns and the sync whitelist; the six columns sync (`lib/data/sync/sync_table.dart`).
- Live UI: `snow_live_panel.dart` (speed hero, Riding / On lift / Resting chip, tiles), `RouteMap` sections so lifts draw muted, `snow_time_bar.dart` on the finish sheet and detail.
- Review tools (Activity detail): speed heatmap on the route, map style switch (Dark `dataviz-dark`, Winter `winter-v2`, Satellite `satellite`; MapTiler map ids, same key; `mapStyleProvider` stored in local settings, not synced), `snow_compare.dart` (run comparison with badges), `snow_timeline.dart` (runs and lifts), and `snow_replay_screen.dart` at `/activity/:id/replay/:run` (marker driven by a `Ticker` through `replayAt`, play / pause, scrubber, 1x / 4x / 16x).
- No new package dependencies. Raw fixes stay on the device; only the route and segment list sync.

## Sharing a session as an image (feature 027)

- Domain (pure Dart, `lib/domain/share/`): `share_card.dart` builds an immutable card model from a finished workout or activity (per-type metric lists, gym totals and exercise lines capped at 7 with "+N more exercises"; notes are never included) and `route_projection.dart` projects route points to a unit box for drawing without map tiles.
- UI (`lib/features/share/`): preview screens at `/share/workout/:id` and `/share/activity/:id` render the 1080x1350 card with a `RepaintBoundary` and encode it to PNG; Share icons sit on the activity detail and finished-workout app bars, and "Share workout" on the gym finish summary.
- `lib/core/image_sharer.dart` writes the PNG to a temporary cache file and hands it to the OS share sheet through `share_plus`; widgets reach it through a Riverpod provider so tests use a fake. No schema change and no network use by the app.

## Workout flow and exercise library

- Live session: a device-local record in settings under the key `live_workout` (`lib/data/repositories/live_session_store.dart`, exposed as `liveSessionProvider`) holds the live workout id and the duration already accumulated, so any finished workout can be resumed (while none is live) and keeps its earlier duration. Start, finish, discard and delete clear it. No schema change (v4).
- Pure helpers: `lib/domain/workout_dates.dart` (day moves keeping time of day and duration) and `lib/domain/calendar.dart` (month/week grids, navigation, day grouping). `WorkoutRepository.setLiveWorkoutDay` / `setWorkoutDay` apply a chosen day.
- `canRewriteBase` stays per plan: finishing rewrites a plan's base only when the workout is the newest session for that plan, so backdated or older resumed sessions never do.
- Screens: `/exercises` (`lib/features/exercises/exercise_library_screen.dart`, from the Train header and Progress "All exercises"; custom exercises are created and edited in `custom_exercise_sheet.dart` with a category); History has a List/Calendar switch (`history_calendar.dart`, `history_rows.dart`).

## Set milestone reward

- Rule: `firstTwoSetsHitTarget` in `lib/domain/milestones.dart` (pure). `ExerciseCard.didUpdateWidget` plays the burst only on a false→true change in a live workout, so opening a workout or editing history never replays it.
- `RewardBurst` (`lib/features/workout/widgets/reward/reward_burst.dart`) runs in an `OverlayEntry` under `IgnorePointer`: one controller drives the whole 3.3 s timeline; sparks use closed-form drag/gravity motion so any frame can be drawn directly. `MuscleFigurePainter` draws the figure from the approved SVG paths; the pill (`target_hit_pill.dart`) reuses it as an icon and never shifts the row.

## Rest timer

- `RestTimerController` (`lib/features/workout/rest_timer_controller.dart`) stores the start timestamp, target duration and exercise name in the settings table, so the timer survives app restarts.
- The displayed remaining time is derived from the clock (now minus start), never from a ticking counter, so it stays correct after backgrounding.
- In the foreground a single alarm `Timer` fires at 0: haptic if Vibrate is on, chime if Sound is on, once per timer (`_alerted`). A restored timer that already ended never alerts late.
- `onBackground()` schedules one OS notification at the timer end with the current Sound/Vibrate prefs and exercise name; `onForeground()` cancels it. `dismiss()` cancels it, a new `start()` while backgrounded reschedules, and changing prefs while backgrounded reschedules. Nothing is scheduled once the time has run out. In the background the OS notification is the alert, not the in-app chime.
- The first `start()` requests notification permission once (flag stored in settings); a denial never affects the in-app chime.

### RestAlerts boundary

- `lib/core/rest_alerts.dart` defines the `RestAlerts` interface (`init`, `status`, `requestNotificationPermission`, `openNotificationSettings`, `openExactAlarmSettings`, `playChime`, `schedule`, `cancel`), `AlertStatus`/`AlertPermission`, `NoopRestAlerts` (default for tests and unsupported platforms) and `restAlertsProvider`. Implementations must swallow and log platform errors; the in-app timer never depends on them.
- `lib/core/platform_rest_alerts.dart` is the production `PlatformRestAlerts`, overridden in `main()`. It uses `flutter_local_notifications` (four channels by sound/vibrate, one notification id, UTC `zonedSchedule`, exact mode when `canScheduleExactNotifications()` else inexact-while-idle, tap opens the workout screen) and `audioplayers` for the chime (notification-event usage, transient focus with ducking, `ambient` on iOS), plus `app_settings` for the system settings screens.
- `AppLifecycleListener` in `lib/app/app.dart` calls `onBackground()` on hide/pause and `onForeground()` on show/resume.
- Tests override `restAlertsProvider` with a no-op or fake.

## Daily steps (feature 014)

- `lib/core/step_source.dart`: `StepSource` (`access`, `requestAccess`, `installHealthConnect`, `stepsBetween`), `StepAccess`, `NoopStepSource` (default), `stepSourceProvider`, `todayStart`.
- `lib/core/health_connect_step_source.dart`: production adapter over the `health` package (Health Connect, `READ_STEPS` only); every call is caught, logged and time-limited; overridden in `main()`.
- Providers `stepsEnabledProvider`, `stepAccessProvider`, `todayStepsProvider` never call the source while the setting is off. Step counts are never stored, synced or sent; `steps_enabled` / `steps_intro_shown` are device-local settings outside the sync whitelist.
- Android: `MainActivity` is a `FlutterFragmentActivity`; Health Connect's rationale / permission-usage intents start the app at `/privacy` (`PrivacyScreen`).

## Data model: templates

- `templates`: `id`, `name` (trimmed, 1 to 40 chars, unique ignoring case via the `templates_name_ci` index on lower(name)), `created_at`, `last_used_at` (nullable), plus sync columns (`updated_at`, `dirty`).
- `template_exercises`: `id`, `template_id` (FK, ON DELETE CASCADE), `exercise_id` (FK), `position`, sync columns; `UNIQUE(template_id, exercise_id)`; plan columns `base_weight`, `target_reps`, `target_sets`, `increment`, `rest_seconds` (all nullable; null means no plan yet).
- `workout_exercises.template_exercise_id`: nullable, indexed, no FK; links a workout exercise to the template plan it uses.

### TemplateRepository

All operations run in a drift transaction, so a failure leaves no partial state.

- Each template exercise is seeded with a copy of the exercise's own plan when added (`create`, `update`, `saveFromWorkout` copies the plan the session used).
- `create`: validates the name (empty, too long, `DuplicateTemplateName`) and at least one exercise, drops duplicate exercise ids, inserts the template and its rows.
- `update`: validates, renames and writes the full ordered list as a diff against existing rows: removed rows are deleted and queued in `pending_deletes`, kept rows are re-positioned, new rows inserted.
- `delete`: queues the template in `pending_deletes` and deletes it (child rows cascade); workouts are untouched.
- `saveFromWorkout`: creates a template from a workout's exercises in workout order.
- `startWorkout`: all or nothing, links each workout exercise to its template exercise; throws `StateError` if a workout is in progress or the template is missing, otherwise creates the workout with its exercises in order and sets `last_used_at`.
- `list` orders by `last_used_at` desc (nulls last), then `created_at` desc.

## Schema versioning and migration testing

- `schemaVersion` is 9 (v7 and v8 belong to feature 013: sync columns and the `sync_state` table; v9 belongs to feature 017: the snowboarding columns on `activities`). Migrations use drift's generated `stepByStep` (`lib/data/db/app_database.steps.dart`): v1 to v2 creates both template tables and the `templates_name_ci` index; v2 to v3 adds the plan columns to `template_exercises` (filled from `exercise_state`) and `workout_exercises.template_exercise_id` with its index; v3 to v4 (`from3To4`) creates `activities` and its `started_at` index; v4 to v5 (`from4To5`) adds the nullable `activities.distance_meters` column; v5 to v6 adds `tracking_sessions`, `track_points` and the tracked columns on `activities`; v8 to v9 (`from8To9`) adds the six snowboarding columns to `activities`. `onCreate` creates the index too.
- Schema dumps are in `drift_schemas/`; generated migration test helpers and tests are in `test/drift/`, plus `test/data/migration_test.dart` (upgrades keep existing workouts and sets; v3 copies exercise plans into templates; v4 keeps all existing data).
- After a schema change, run `dart run drift_dev make-migrations` to produce the new dump and helpers.

## Error handling

- Async UI actions are wrapped in `guard()` (`lib/widgets/guard.dart`): exceptions are caught and shown to the user as a SnackBar instead of crashing or failing silently.
- Multi-row writes run in drift transactions so a failure leaves no partial state.

## Testing strategy

- Domain logic (progression, stats) is covered by pure unit tests, written first.
- Data tests run repositories against an in-memory drift database (finish, edit, resume, delete, `canRewriteBase`).
- Widget tests cover screens and shared widgets; an end-to-end widget test lives in `test/e2e`.
- `integration_test/` runs key flows on a device or emulator (`flutter test integration_test`).

## Sync design (feature 013)

Opt-in cloud backup on Supabase (Postgres, Auth, RLS). The local drift database stays the source of truth; nothing
is sent until the user signs in. Local schema v8 adds the `sync_state` table (per-table pull cursors).

### Client (`lib/data/sync/`)

- `sync_table.dart`: registry of synced tables in FK order (custom_exercises, exercise_overrides, exercise_state, templates, template_exercises, workouts, workout_exercises, sets, activities, user_settings) with their local/server column mapping.
- `push_collector.dart`: gathers `pending_deletes` (children first) and dirty rows into pages of at most 500; clears `dirty` only where `updated_at` is unchanged.
- `pull_applier.dart`: applies pulled pages in one transaction per page (tombstone, overwrite, keep-local-if-dirty-newer, rename or drop on name/set collisions) and advances the cursor.
- `sync_service.dart`: one cycle (pull, then push), single-flight, 5 s debounce, status stream; failures are silent.
- `sync_remote.dart` / `supabase_sync_remote.dart`: the remote interface and its Supabase implementation (`sync_push` RPC, paged PostgREST selects, cloud-has-data probe).
- `device_binding.dart`: remembers which account the phone's data belongs to and decides first backup, restore, merge or replace on sign-in.
- `account_service.dart`: sign out, remove local data, delete account (calls the `delete-account` Edge Function).
- `lib/domain/sync_rules.dart`: pure rules (last-writer-wins, delete wins, collision renaming, settings whitelist).
- `lib/data/repositories/auth_repository.dart`: native Google sign-in then `signInWithIdToken`. Providers (`authRepositoryProvider`, `syncServiceProvider`, `accountServiceProvider`, `syncStatusProvider`) are in `lib/data/providers.dart` and are null when backup is not configured.
- Triggers: app start, return to foreground, after finishing a workout, after sign-in, manual "Back up now".

### Backend (`supabase/`)

- `migrations/`: tables (`user_id`, `deleted_at`, `server_updated_at`), triggers (LWW guard, delete wins, cascade and child-of-tombstone), owner-only RLS, `sync_push` (`SECURITY INVOKER`, per-row rejection).
- `functions/delete-account/`: Edge Function that deletes the caller's auth user; tables cascade.
- No server-side uniqueness; collisions are resolved on pull. Built-in exercises are not stored per user; hidden ones sync as `exercise_overrides.archived_at`. Raw GPS points and live sessions are never synced.

### Testing

- Backend rules run on PGlite with a stub of Supabase's `auth` schema: `supabase/tests/*.sql` via `npm ci && node tool/db_test.mjs` (RLS, LWW, tombstones, `sync_push`). No Docker needed.
- Client logic runs against `FakeSyncRemote`, an in-memory remote that mirrors the SQL rules, with two simulated devices on in-memory drift (`flutter test test/data/sync`).
