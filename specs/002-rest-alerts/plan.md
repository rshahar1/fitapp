# Implementation Plan: Rest-End Alerts That Work

**Branch**: `002-rest-alerts` | **Date**: 2026-11-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-rest-alerts/spec.md`

## Summary

Fix the silent rest timer and add background alerts. A bundled original chime is played through a
real audio player when the countdown ends in the foreground; while the app is backgrounded the
end-of-rest moment is handed to the OS as a scheduled local notification (exact when allowed),
cancelled whenever the timer changes or the app returns to the foreground. All platform calls sit
behind a small `RestAlerts` interface so the existing `RestTimerController` rules stay unit-testable.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 stable

**Primary Dependencies**: new — `flutter_local_notifications` ^23.0, `timezone` ^0.11,
`audioplayers` ^6.8, `app_settings` ^9.0; existing Riverpod 3, drift

**Storage**: existing `settings` table (2 new keys, no migration) — see [data-model.md](./data-model.md)

**Testing**: flutter_test with a fake `RestAlerts` and the injectable clock; manual device checks
in [quickstart.md](./quickstart.md)

**Target Platform**: Android 7+ (Flutter default minSdk); permissions differ on 13+ and 14+

**Project Type**: mobile-app (feature added to the existing app)

**Performance Goals**: background alert within 5 s of the target with precise alarms; chime starts
< 200 ms after 0:00 in the foreground

**Constraints**: offline only; respect silent/DND; never stop the user's music; one pending alert

**Scale/Scope**: 1 interface + 1 platform implementation, controller changes, Settings rows,
Android manifest/resources, 1 sound asset

## Constitution Check

| Principle | Gate | Status |
|---|---|---|
| I. Offline-first | No network; alerts are local OS notifications | ✅ |
| II. Pure domain | Domain untouched | ✅ |
| III. Test-first | Controller rules tested with a fake before wiring the platform implementation | ✅ |
| IV. Layering | Platform calls isolated in `lib/core/rest_alerts.dart`; widgets call the controller | ✅ |
| V. One-tap UX | No layout shift; footer pill unchanged; no new prompts during logging beyond the one-time permission | ✅ |
| VI. Safety & privacy | No trackers; only local notifications; minimal permissions (no `USE_EXACT_ALARM`, no boot receiver) | ✅ |
| VII. Scope | Implements PRD §5.3 SHOULD + §5.7 sound toggle; nothing beyond | ✅ |

Post-design re-check: ✅ (no violations).

## Project Structure

### Documentation (this feature)

```text
specs/002-rest-alerts/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/rest-alerts.md
├── checklists/requirements.md
└── tasks.md
```

### Source Code

```text
assets/sounds/rest_chime.ogg                         # new, original chime
android/app/src/main/res/raw/rest_chime.ogg          # same sound for notification channels
android/app/src/main/AndroidManifest.xml             # POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, plugin receiver
android/app/build.gradle.kts                         # core library desugaring (required by the plugin)
lib/core/rest_alerts.dart                            # RestAlerts interface, AlertStatus, provider
lib/core/platform_rest_alerts.dart                   # flutter_local_notifications + audioplayers impl
lib/data/repositories/settings_repository.dart       # ActiveRest.exerciseName, notif_permission_asked
lib/features/workout/rest_timer_controller.dart      # rules from contracts/rest-alerts.md
lib/features/workout/widgets/exercise_card.dart      # pass exercise name to startFor()
lib/app/app.dart                                     # AppLifecycleListener → onBackground/onForeground; init with tap → /workout
lib/main.dart                                        # init RestAlerts before runApp
lib/features/settings/settings_screen.dart           # Notifications + Precise timing rows
test/features/rest_alerts_test.dart                  # controller rules with fake RestAlerts
```

**Structure Decision**: extend existing feature folders; the only new module is the `RestAlerts`
boundary in `lib/core/`.

## Complexity Tracking

None.
