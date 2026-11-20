# Quickstart: validate sharing

1. `flutter test test/domain/share test/features/share_test.dart` — domain rules and layouts.
2. `flutter run --dart-define-from-file=env/dev.json` on an Android device/emulator.
3. Finish a gym workout → summary → **Share workout** → preview lists exercises → **Share image**
   → pick WhatsApp/Messages: one image arrives.
4. History → a GPS run → Share icon → route + pace card. Repeat for a ride (speed), a snowboarding
   day (heat route + ride/lift/rest bar; use the Val Thorens simulation to create one), a pilates
   entry (duration only) and a manual run (no route area).
5. Workout with > 7 exercises → `+N more exercises`; empty manual entry → "Logged in FitApp".
