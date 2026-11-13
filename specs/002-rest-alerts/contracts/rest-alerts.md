# Contract: RestAlerts (platform boundary) and controller rules

## Interface (`lib/core/rest_alerts.dart`)

```dart
enum AlertPermission { granted, denied, notAsked }

class AlertStatus {
  final AlertPermission notifications;
  final bool exactAlarms;          // true if precise background alerts are allowed
}

abstract interface class RestAlerts {
  Future<void> init({required void Function() onOpenWorkout}); // tap + cold-start launch handling
  Future<AlertStatus> status();
  Future<bool> requestNotificationPermission();   // system prompt where required
  Future<void> openNotificationSettings();
  Future<void> openExactAlarmSettings();
  Future<void> playChime();                       // foreground sound, respects silent mode
  Future<void> schedule({                         // replaces any pending rest alert
    required DateTime at,                         // UTC
    required String exerciseName,
    required bool sound,
    required bool vibrate,
  });
  Future<void> cancel();                          // removes pending AND shown rest alert
}

final restAlertsProvider = Provider<RestAlerts>(...); // PlatformRestAlerts in the app, fake in tests
```

## RestTimerController rules (extends feature 001's controller)

| Event | Behaviour |
|---|---|
| `start(targetSeconds, exerciseName)` | persist ActiveRest (+ exerciseName); schedule in-app alarm; if first timer ever and permission notAsked → `requestNotificationPermission()` once and store `notif_permission_asked`; if app is backgrounded → `schedule(...)` |
| in-app alarm fires (foreground) | if still the same timer: vibrate if `haptic`, `playChime()` if `sound`; mark `alerted` |
| `dismiss()` | clear state; `cancel()` |
| workout finished / discarded | `dismiss()` (already called by the workout screen) |
| `onBackground()` (app hidden/paused) | if a timer is running and remaining > 0 and not alerted → `schedule(at: end, ...)` with current prefs |
| `onForeground()` (app resumed) | `cancel()`; if the timer ended while away, mark alerted (no late chime) |
| alert prefs changed while a timer runs and the app is backgrounded | reschedule with new prefs |
| `_restore()` after process start | restore ActiveRest; never chime for an already-ended timer |

At most one pending/shown rest notification exists (fixed id). All methods are no-ops on failure
(caught and logged); the in-app timer never depends on notification permission.

## Settings UI additions (`/settings`, group "Rest timer alert")

- Row "Notifications": status text `On` / `Off — tap to enable` → `openNotificationSettings()`.
- Row "Precise timing": `On` / `Off — alerts may be late while the phone is idle` →
  `openExactAlarmSettings()`. Status refreshes when the app returns to the foreground.
