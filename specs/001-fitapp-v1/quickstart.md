# Quickstart & Validation Guide: FitApp v1

## Prerequisites (macOS)

1. Flutter stable (3.50+) — not installed yet on this Mac. Install from https://flutter.dev
   (or `brew install --cask flutter`), then `flutter --version`.
2. JDK 17 and the Android SDK (Android Studio or command-line tools); accept licenses with
   `flutter doctor --android-licenses`.
3. `flutter doctor` green for Android. An Android phone with USB debugging, or an emulator.
4. `gh` authenticated for the private `fitapp` repo; git configured with the owner's GitHub
   no-reply email for this repo.

## Setup

```bash
flutter pub get
dart run build_runner build   # drift codegen (committed output)
cp env/example.json env/dev.json                            # local config, git-ignored
flutter run --dart-define-from-file=env/dev.json
```

## Quality gates (every milestone)

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
```

Domain coverage: `lib/domain/progression.dart` must show 100% in `coverage/lcov.info`.

## Validation scenarios

| # | Scenario | Expected | Covered by |
|---|---|---|---|
| V1 | PRD §11 scenarios 1–8 | base weights as documented | `test/data/workout_repository_test.dart` |
| V2 | Domain test list | all green | `test/domain/` (see contracts/domain-api.md) |
| V3 | Start → add Incline DB Press → plan 20×10×3 +2.5 → tap ✓ three times (edit set 3 to 6 reps) → Finish | summary `20 kg → 22.5 kg`; exercise detail shows base 22.5 and one chart point | `integration_test/workout_flow_test.dart` |
| V4 | Log a set | rest pill counts down from 1:00 in the footer; no row moves | widget test + manual |
| V5 | Settings default 90 s, restart, log set | counts down from 1:30; exercise with custom 120 s uses 2:00 | widget test + manual |
| V6 | Background the app 40 s during rest | ≈ 0:20 remains on return | widget test with fake clock + manual |
| V7 | Force-stop mid-workout, reopen | all logged sets present; Continue workout shown | manual on device |
| V8 | Airplane mode, full workout | everything works | manual on device |
| V9 | History: scenarios 4–8 via UI | base weights as in §11 | manual (M4) |
| V10 | Exercise detail with 1, 2, 25 sessions | charts render, PR badge correct | widget tests (M5) |
| V11 | TalkBack pass over workout screen | every control announced meaningfully | manual (M6) |

## Release APK (M6)

```bash
keytool -genkey -v -keystore ~/fitapp-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
# create android/key.properties (git-ignored) pointing at the keystore
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk ; copy to the phone and install
```

Never commit the keystore, `android/key.properties`, or `env/*.json` other than `env/example.json`.
