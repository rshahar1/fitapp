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
flutter test
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
Neither the keystore (`*.jks`, `*.keystore`) nor `android/key.properties` is ever committed.

## Project layout

```
lib/
  main.dart
  app/                 app widget, router, theme
  core/                formatting, ISO-week utils, haptics, result types
  domain/              pure Dart: progression.dart, stats.dart
  data/
    db/                drift database, tables, migrations, seed library
    repositories/      WorkoutRepository, ExerciseRepository
    sync/              (Phase 2) push/pull, delete queue
  features/            train, workout, history, progress, exercises, settings
  widgets/             shared UI kit
test/                  mirrors lib/
integration_test/      key end-to-end flows
```

## Generated code policy

Drift-generated `*.g.dart` files are committed so the app runs right after clone. Regenerate with:

```sh
dart run build_runner build
```

CI re-runs the generator and fails if `git diff` is not empty.

## Roadmap

- Sign-in with cloud backup and restore
- Routines and workout templates, "repeat last workout"
- Drop and failure set types
- Rest-timer notifications in the background
- kg / lb setting
- Plate calculator
- Deload suggestion after repeated `missed_reps`
- iOS release
