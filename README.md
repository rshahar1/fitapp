# FitApp

FitApp is an offline-first gym logger for Android (Flutter) with automatic progressive overload. You set a
plan per exercise (base weight, reps, sets, increment) and log sets during a workout; when you finish, the
app decides whether to raise the base weight for next time. All data lives in a local SQLite database
(drift); cloud sync is a later phase.

## The progression rule

For a plan `{base, reps, sets = N, inc}`: sets 1..N-1 use `base`; set N uses `base + inc` (the overload
set). Weights are rounded to 0.25 kg. On finish, checked in order:

| Condition | Result | Reason |
|---|---|---|
| A working set (1..N-1) not logged | base unchanged | `incomplete` |
| A working set with reps < target or weight < base | base unchanged | `missed_reps` |
| Overload set (N) not logged | base unchanged | `no_overload_set` |
| Overload set weight <= base | base unchanged | `overload_not_heavier` |
| Otherwise | next base = weight lifted on set N | `progressed` |

Reps on the overload set do not matter. Exercises without a plan are logged but never progressed.

## Setup

Prerequisites: Flutter (stable channel), JDK 17, Android SDK. `flutter doctor` should be green for Android.

```sh
flutter pub get
cp env/example.json env/dev.json   # fill in values; env/dev.json is git-ignored
flutter run --dart-define-from-file=env/dev.json
```

## Test

```sh
flutter analyze
flutter test                      # unit, data, widget, and the end-to-end widget test in test/e2e
flutter test integration_test     # needs a device or emulator
```

## Build APK

Debug (personal use):

```sh
flutter build apk --debug
```

Release, signed with your own keystore. Create it once (keep it outside git):

```sh
keytool -genkey -v -keystore ~/upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties`:

```properties
storePassword=<your store password>
keyPassword=<your key password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Then run `flutter build apk --release`; the APK is at `build/app/outputs/flutter-apk/app-release.apk`.
It is signed with `android/key.properties` and the keystore when present, otherwise debug-signed. A
debug-signed APK is fine for personal sideloading but NOT for the Play Store.
Neither the keystore (`*.jks`, `*.keystore`) nor `android/key.properties` is ever committed.

## Install on your phone

Enable install from unknown sources on the phone, copy the APK to it and open it. Or, with USB debugging:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Project layout

```
lib/
  main.dart
  app/                 app.dart, backdrop.dart, router.dart, theme/ (app_theme.dart, tokens.dart)
  core/                format.dart, haptics.dart, rest_alerts.dart, platform_rest_alerts.dart
  domain/              pure Dart: progression.dart, stats.dart
  data/
    db/                app_database.dart, tables.dart, seed_library.dart (+ generated *.g.dart)
    repositories/      WorkoutRepository, ExerciseRepository, SettingsRepository
    models.dart        plain data/read models
    providers.dart     Riverpod providers
    watch.dart         watchQuery: stream that re-runs a loader on table updates
  features/
    shell/             bottom-navigation shell
    train/             start/resume workout
    workout/           workout screen, rest timer, widgets/ (exercise card, set table/sheet, ...)
    history/           finished workouts, edit/resume/delete
    progress/          overview and per-exercise detail
    exercises/         exercise picker and custom exercise sheet
    settings/          settings screen
  widgets/             shared UI kit (buttons, cards, charts, guard.dart, ...)
test/                  unit, data, widget, and e2e/ (end-to-end widget test)
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

## Rest timer alerts

- In-app chime at 0: respects the phone's silent mode and ducks music.
- Background notification: when the app is in the background or the screen is off, the OS shows the alert. Timing is exact if "Alarms & reminders" (precise timing) is allowed; otherwise it may be late while the phone is idle.
- Notification permission is requested on the first rest timer. Settings → Rest timer alert shows the status and opens the system settings.
- Android permissions used: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `VIBRATE`. There is no boot receiver, so alerts do not fire after a reboot.
- `compileSdk 37` is set in `android/app/build.gradle.kts` (required by flutter_local_notifications 23).

## Known limitations / not yet done

- Phase 2 sync (M7) has not been started.

## Roadmap

- Sign-in with cloud backup and restore
- Routines and workout templates, "repeat last workout"
- Drop and failure set types
- kg / lb setting
- Plate calculator
- Deload suggestion after repeated `missed_reps`
- iOS release
