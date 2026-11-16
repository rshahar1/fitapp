# FitApp

FitApp is an offline-first gym logger for Android (Flutter) with automatic progressive overload. You set a
plan per exercise (base weight, reps, sets, increment) and log sets during a workout; when you finish, the
app decides whether to raise the base weight for next time. All data lives in a local SQLite database
(drift); optional cloud backup (see below) is available. Besides gym workouts you can log other sports as simple activities
(see below).

## The progression rule

For a plan `{base, reps, sets = N, inc}`: sets 1..N-1 use `base`; set N uses `base + inc` (the overload
set). Weights are rounded to 0.25 kg. Only the working sets 1..N-1 decide. On finish, checked in order:

| Condition | Result | Reason |
|---|---|---|
| A working set (1..N-1) not logged | base unchanged | `incomplete` |
| A working set with reps < target or weight < base | base unchanged | `missed_reps` |
| Every working set logged at weight >= base with reps >= target | next base = `roundWeight(base + inc)` | `progressed` |

The overload set is still prescribed at `base + inc` and marked with an up arrow, but skipping or failing it never
changes the result, and lifting more than prescribed does not make the base jump. Exercises without a plan are
logged but never progressed.

A plan is either the exercise's own plan (ad-hoc workouts) or a template plan (see below).

## Setup

Prerequisites: Flutter (stable channel), JDK 17, Android SDK. `flutter doctor` should be green for Android.

```sh
flutter pub get
cp env/example.json env/dev.json   # fill in values; env/dev.json is git-ignored
flutter run --dart-define-from-file=env/dev.json
```

`MAP_TILES_KEY` is a free [MapTiler](https://www.maptiler.com/) API key used for the map tiles behind recorded
routes (live GPS tracking). It is optional: without a key the app works normally and shows a plain background
behind the route line. Pass it with `--dart-define-from-file`. Put the key only in `env/dev.json` (git-ignored), never in source control.

Optional cloud backup (Supabase + Google sign-in) is configured with `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`GOOGLE_WEB_CLIENT_ID` in `env/dev.json`. Leave them empty to disable backup; the app works fully offline. See
[docs/sync-setup.md](docs/sync-setup.md).

## Test

```sh
flutter analyze
flutter test                      # unit, data, widget, and the end-to-end widget test in test/e2e
flutter test integration_test     # needs a device or emulator
```

## Release build

Debug build (personal use): `flutter build apk --debug`.

For sharing or the Play Store, build a signed release: create the keystore once with
`tool/make_release_keystore.sh`, then `flutter build apk --release --dart-define-from-file=env/dev.json`
(APK at `build/app/outputs/flutter-apk/app-release.apk`). A release build without
`android/key.properties` fails unless `FITAPP_ALLOW_DEBUG_SIGNING=1` is set (local testing only).
Keystore and `key.properties` are never committed. Full guide: [docs/release.md](docs/release.md).

## Install on your phone

Enable install from unknown sources on the phone, copy the APK to it and open it. Or, with USB debugging:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Cloud backup (optional)

Sign in with Google (Settings) to back up your history to your own Supabase account and restore it on a new
phone; two phones on one account stay in step (last change wins, deletions win). Backup runs in the background
and never blocks logging, also offline.

- **Privacy:** nothing leaves the phone until you sign in. Raw GPS points never leave the phone; saved routes go
  only to your own account. Settings can sign out, remove your data from the phone, or delete your account.
- **Enable:** set `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `GOOGLE_WEB_CLIENT_ID` in `env/dev.json` and follow
  [docs/sync-setup.md](docs/sync-setup.md).
- **Backend tests** (PGlite, no Docker): `npm ci && node tool/db_test.mjs`. App sync tests: `flutter test test/data/sync`.

## Workout templates

Templates are reusable exercise lists you start in one tap from the Train tab. Only user-created templates exist; there are no built-in ones.

- Create from scratch (Train tab, "New") by naming it (1 to 40 characters, unique ignoring case) and adding exercises, or save a running workout as a template from the workout screen menu ("Save as template").
- Edit, reorder (drag handles) and delete templates in the template editor. Deleting a template never touches past workouts.
- START on a template card creates the live workout with its exercises in order, all or nothing. If a workout is already in progress you are offered to continue it instead.
- Each template exercise has its own plan (base weight, reps, sets >= 2, increment, optional rest), seeded from the exercise's own plan when it is added (create, edit, save from workout; an app upgrade copies the existing plans). The editor rows show it (for example "3 x 10 @ 20 kg · overload +2.5", or "No plan yet"); tap a row to edit it, saved with the template.
- A workout started from a template links each exercise to its template exercise. Finishing, editing, resuming or deleting that workout progresses or undoes the template plan only. The exercise's own plan is not touched, so the same exercise in two templates progresses independently. Ad-hoc workouts, and exercises added ad hoc, keep using the exercise's own plan.
- In the live workout, cards from a template show "· template plan" and "Edit plan" edits the template plan.

## Other sport activities

The Train tab has a **Log activity** button for Functional training, Cycling, Snowboarding, Running and Pilates: pick
the type and date (today by default, never in the future) and optionally a duration and a note. Running and
cycling also take an optional distance in km (typed with `.` or `,`); History then shows the distance and, with a
duration, the pace (running) or speed (cycling). **History**
lists workouts and activities together by month, with a dumbbell icon for gym workouts and a sport icon for
activities; tap an activity to edit or delete it. Activities count toward **This week**, **Week streak** and
the Progress weekly bars; **Total workouts** counts gym workouts only, and activities never affect volume,
exercise stats or progression. The sports are a code-level registry in `lib/domain/activity_types.dart`;
adding one means one registry entry plus one icon in `lib/features/activities/activity_icons.dart`.

## Live GPS tracking (running and cycling)

Pick Running or Cycling in **Log activity** and tap **Start live**: a setup screen waits for a good GPS fix
(accuracy 20 m or better, or Start anyway), then the live screen shows time, distance, pace or speed and the
route on a map, with Pause/Resume, Lock and a hold-to-finish button. Tracking continues with the screen off
(Android foreground service with a notification) and auto-pauses when you stand still. A finish sheet shows the
route and metrics; Save stores one activity with distance, duration, moving time, elevation gain, a simplified
route and per-km splits, and deletes the raw GPS points. History shows a route thumbnail and opens an activity
detail with the map and splits. GPS points are saved every few seconds, so after a crash or kill the app reopens
the live screen and continues. Only one live session (gym workout or tracked activity) at a time. Location data
never leaves the device; only map tile requests go to MapTiler (see `MAP_TILES_KEY` in Setup). Android
permissions added: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`,
`FOREGROUND_SERVICE_LOCATION` (while-in-use only, no background-location permission). New packages: `geolocator`,
`flutter_map`, `latlong2`. Schema v6 adds the tracking tables and the tracked columns on `activities`.

## Workout flow and exercise library

- **Resume** any finished workout (while none is live), from History or the finish summary; a resumed workout
  keeps its earlier duration. The live session is a device-local record (settings key `live_workout`,
  `lib/data/repositories/live_session_store.dart`).
- **Discard workout** is in the live workout menu, with a confirmation (stronger warning for resumed workouts).
- The **Date** row on the workout screen (live and finished) logs past gym sessions; time of day and duration
  are kept. Finishing only progresses a plan when the workout is the newest session for that plan.
  Pure helpers live in `lib/domain/workout_dates.dart`.
- **Exercises** library (`/exercises`, header icon on Train and "All exercises" on Progress): create and edit
  custom exercises, with a category (Chest, Back, Legs, Shoulders, Arms, Custom).
- **History** has a List/Calendar switch: Month or Week calendar with prev/next, month and year picker, Today,
  a first-session icon per day and "+N" for more (pure helpers in `lib/domain/calendar.dart`).

No schema change (still v4) and no new packages.

## Database schema and migrations

The schema is at version 6 (v6 adds `tracking_sessions`, `track_points` and the tracked-activity columns on `activities`; v2 adds `templates` and `template_exercises`; v3 adds the plan columns on `template_exercises` and `workout_exercises.template_exercise_id`; v4 adds `activities`; v5 adds `activities.distance_meters`). Migrations use drift's generated `stepByStep` helper (`lib/data/db/app_database.steps.dart`). Schema dumps live in `drift_schemas/` and the migration tests in `test/drift/` (plus `test/data/migration_test.dart`). After any schema change, regenerate the dumps and test helpers with:

```sh
dart run drift_dev make-migrations
```

## Project layout

```
lib/
  main.dart
  app/                 app.dart, backdrop.dart, router.dart, theme/ (app_theme.dart, tokens.dart)
  core/                format.dart, haptics.dart, rest_alerts.dart, platform_rest_alerts.dart
  domain/              pure Dart: progression.dart, stats.dart, activity_types.dart (sport registry), workout_dates.dart, calendar.dart
  data/
    db/                app_database.dart, tables.dart, seed_library.dart (+ generated *.g.dart)
    repositories/      WorkoutRepository, ExerciseRepository, SettingsRepository, TemplateRepository (template_repository.dart), ActivityRepository (activity_repository.dart), plan_store.dart (PlanStore: validated plan reads/writes), live_session_store.dart (device-local live workout record)
    sync/              cloud backup: sync service, push/pull, device binding, account actions (see docs/ARCHITECTURE.md)
    models.dart        plain data/read models
    providers.dart     Riverpod providers
    watch.dart         watchQuery: stream that re-runs a loader on table updates
  features/
    shell/             bottom-navigation shell
    train/             start/resume workout
    workout/           workout screen, rest timer, widgets/ (exercise card, set table/sheet, ...)
    history/           workouts and activities by month or calendar (history_calendar.dart, history_rows.dart), edit/resume/delete
    activities/        log/edit activity sheet, activity_icons.dart
    progress/          overview and per-exercise detail
    exercises/         exercise library screen, exercise picker and custom exercise sheet
    templates/         template editor screen (create/edit/reorder/delete)
    settings/          settings screen
  widgets/             shared UI kit (buttons, cards, charts, guard.dart, ...)
supabase/              migrations, SQL tests, Edge Function delete-account
drift_schemas/         drift schema dumps (v1 to v4)
test/                  unit, data, widget, drift/ (migration tests), and e2e/ (end-to-end widget test)
integration_test/      key end-to-end flows (device/emulator)
```

## Toolchain

- Flutter 3.50 stable (Dart 3.14). Material is imported from `package:material_ui/material_ui.dart`.
- State management: Riverpod 3, without codegen.
- Database: drift. The generated output is committed and regenerated with `dart run build_runner build`.

## Generated code policy

Drift-generated `*.g.dart` files are committed so the app runs right after clone. Regenerate with:

```sh
dart run build_runner build
```

CI re-runs the generator and fails if `git diff` is not empty.

## Background image

Every screen shows a blurred photo backdrop (Pexels photo 6389516 by Tima Miroshnichenko, Pexels
License; see `assets/images/BACKDROP_LICENSE.md`). The two bundled images
(`assets/images/backdrop_fill.jpg`, `assets/images/backdrop_band.jpg`, ~24 KB together) are
generated by `tool/make_backdrop.py` and composed in `lib/app/backdrop.dart`, so the barbell sits
at ~60 % of the screen height on any screen shape.

## Rest timer alerts

- In-app chime at 0: respects the phone's silent mode and ducks music.
- Background notification: when the app is in the background or the screen is off, the OS shows the alert. Timing is exact if "Alarms & reminders" (precise timing) is allowed; otherwise it may be late while the phone is idle.
- Notification permission is requested on the first rest timer. Settings → Rest timer alert shows the status and opens the system settings.
- Android permissions used: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `VIBRATE`. There is no boot receiver, so alerts do not fire after a reboot.
- `compileSdk 37` is set in `android/app/build.gradle.kts` (required by flutter_local_notifications 23).

## Known limitations / not yet done

- Daily steps (feature 014) read today's total from Health Connect (Google Fit writes there), read-only, on by default, off in Settings → Activity. Needs Android 8.0+ (`minSdk 26`). Before a Play release, file the Health Connect permission declaration and a hosted privacy policy URL in the Play Console. History shows a selected day's total (last 30 days; feature 015), and the Train steps card sits below Templates.
- Cloud backup (M7, feature 013) is built; the real two-phone Google sign-in check is manual (see `specs/013-cloud-sync/quickstart.md`).

## Roadmap

- "Repeat last workout"
- Snowboarding tracking, HealthKit, step goals/history, GPX export, miles, offline map tiles
- Drop and failure set types
- kg / lb setting
- Plate calculator
- Deload suggestion after repeated `missed_reps`
- iOS release
