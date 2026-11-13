# Quickstart & Validation: Rest-End Alerts (002)

## Automated

```bash
flutter analyze
flutter test test/features/rest_alerts_test.dart test/features/workout_screen_test.dart
```

Covered with a fake `RestAlerts`: chime once at 0 only when Sound is on; no chime after the next set
is logged early; schedule on background / cancel on foreground; cancel on dismiss and finish;
reschedule on settings change; permission requested once; no late chime after restore.

## On the phone (release APK)

| # | Steps | Expected |
|---|---|---|
| Q1 | Sound on, rest 10 s (custom), log a set, keep app open | chime at 0:00 once, vibration |
| Q2 | Sound off, repeat | vibration only |
| Q3 | Phone on silent, repeat | no sound |
| Q4 | Play music, repeat Q1 | music ducks briefly and continues |
| Q5 | Rest 30 s, log set, lock phone | notification "Rest over" within 5 s of 0:00 (precise timing on) |
| Q6 | Tap the notification | live workout opens, showing overtime |
| Q7 | Rest 30 s, background app, return after 10 s, log next set, background again | only the new timer alerts |
| Q8 | Fresh install, first set | permission prompt once; deny → still works; Settings shows "Off — tap to enable" |
| Q9 | Force-stop the app during rest | notification still fires |
| Q10 | Reboot during rest | no late notification after boot |
