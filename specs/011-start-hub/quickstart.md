# Quickstart: validate the Start/Log hub

```bash
dart format --set-exit-if-changed . && flutter analyze && flutter test
flutter run --dart-define-from-file=env/dev.json
```

Manual checks on a device:

1. Bottom bar shows Train · History · + · Progress · You; tapping + on each tab opens the hub and
   keeps the tab selected.
2. Train → Start gym workout opens the live workout in one tap. Finish or discard it.
3. + → Running opens "GPS setup" for running. Start, then go back: Train's hero shows "Running in
   progress · mm:ss · x.x km" and "Continue running".
4. While running: + shows "Continue running" first; + → Gym workout shows "Running in progress.
   Finish it first." with Open; Train template START shows the same.
5. + → Log a past session: form titled "Log a past session", no Start live for Running.
6. + → More sports → Pilates: form with Pilates and Today preselected.
7. You → Exercise library / Settings open; back returns to You.
