---
description: "Task list for rest-end alerts"
---

# Tasks: Rest-End Alerts That Work

**Input**: Design documents from `/specs/002-rest-alerts/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/rest-alerts.md, quickstart.md

**Tests**: REQUIRED (constitution III: test-first). Controller rules are tested with a fake
`RestAlerts`; platform behaviour is validated on the phone per quickstart.md.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [x] T001 Add dependencies `flutter_local_notifications`, `timezone`, `audioplayers`, `app_settings` (keep pubspec.yaml lists sorted) in pubspec.yaml
- [x] T002 [P] Generate an original two-tone chime (~0.7 s, 880 Hz → 1320 Hz, soft attack/decay, OGG Vorbis < 30 KB) to assets/sounds/rest_chime.ogg and copy it to android/app/src/main/res/raw/rest_chime.ogg; register `assets/sounds/` in pubspec.yaml
- [x] T003 [P] Android config: `POST_NOTIFICATIONS` and `SCHEDULE_EXACT_ALARM` permissions, the plugin's `ScheduledNotificationReceiver` (NO boot receiver, no `USE_EXACT_ALARM`) in android/app/src/main/AndroidManifest.xml; enable core library desugaring in android/app/build.gradle.kts; keep `rest_chime` in res/raw via android/app/src/main/res/raw/keep.xml

## Phase 2: Foundational

- [x] T004 Define `RestAlerts`, `AlertStatus`, `AlertPermission`, `restAlertsProvider` exactly as in contracts/rest-alerts.md in lib/core/rest_alerts.dart
- [x] T005 Extend `ActiveRest` with optional `exerciseName` (key `active_rest_exercise`, removed with the timer) and add `notificationPermissionAsked()` / `markNotificationPermissionAsked()` (key `notif_permission_asked`) in lib/data/repositories/settings_repository.dart, with tests in test/data/settings_repository_test.dart

## Phase 3: User Story 1 – Hear when rest is over (P1) 🎯 MVP

**Independent test**: with Sound on, a 10 s rest chimes once at 0 with the app open; Sound off → vibration only.

- [x] T006 [US1] Tests with a fake RestAlerts + fake clock: chime once at 0 when Sound on; none when Sound off; vibration per Vibrate; no chime after an early next set; no late chime for a restored, already-ended timer — in test/features/rest_alerts_test.dart
- [x] T007 [US1] Use `restAlertsProvider.playChime()` instead of SystemSound, track `alerted`, accept `exerciseName` in `start`/`startFor` in lib/features/workout/rest_timer_controller.dart; pass the exercise name from lib/features/workout/widgets/exercise_card.dart
- [x] T008 [US1] Implement `playChime()` in `PlatformRestAlerts` with audioplayers: asset `sounds/rest_chime.ogg`, AudioContext Android usage `notificationEvent`, content type `sonification`, focus `gainTransientMayDuck`; iOS category `ambient` — in lib/core/platform_rest_alerts.dart

## Phase 4: User Story 2 – Background notification (P1)

**Independent test**: rest 30 s, lock phone → notification within 5 s of 0; tap opens the live workout; early next set → no stale alert.

- [x] T009 [US2] Tests: `onBackground()` schedules at the timer end with current prefs and exercise name; `onForeground()` cancels; `dismiss()` cancels; new `start()` while backgrounded reschedules; changing prefs while backgrounded reschedules; nothing scheduled once remaining ≤ 0 — in test/features/rest_alerts_test.dart
- [x] T010 [US2] Implement `onBackground()`, `onForeground()`, prefs-change rescheduling and cancel-on-dismiss in lib/features/workout/rest_timer_controller.dart
- [x] T011 [US2] Implement `init` (timezone init, 4 channels from data-model.md, tap + launch-details → `onOpenWorkout`), `schedule` (UTC zonedSchedule, id 4201, exact if `canScheduleExactNotifications()` else inexactAllowWhileIdle, channel by sound/vibrate, title "Rest over", body "Time for your next set · <exercise>") and `cancel` in lib/core/platform_rest_alerts.dart
- [x] T012 [US2] Wire `AppLifecycleListener` (hide/pause → onBackground, resume → onForeground) and notification tap → `router.go('/workout')` in lib/app/app.dart; init RestAlerts and override the provider in lib/main.dart

## Phase 5: User Story 3 – Permission and timing (P2)

**Independent test**: fresh install → one permission prompt on first set; deny → app works; Settings shows status and opens system settings.

- [x] T013 [US3] Tests: first `start()` requests permission once and marks it asked; later starts don't; denial doesn't affect the in-app chime — in test/features/rest_alerts_test.dart
- [x] T014 [US3] Request permission on the first timer start in lib/features/workout/rest_timer_controller.dart; implement `status`, `requestNotificationPermission`, `openNotificationSettings` (app_settings), `openExactAlarmSettings` in lib/core/platform_rest_alerts.dart
- [x] T015 [US3] Settings rows "Notifications" and "Precise timing" (status text, tap opens system settings, refresh on resume) in lib/features/settings/settings_screen.dart with a widget test in test/features/settings_screen_test.dart

## Phase 6: Polish

- [x] T016 Override `restAlertsProvider` with a no-op fake in all existing widget/e2e tests that build the workout screen or app (test/features/*, test/e2e/workout_flow.dart)
- [x] T017 Update README.md (remove the "silent on Android" limitation; document permissions) and mark T056/T057 done in specs/001-fitapp-v1/tasks.md
- [ ] T018 Run format/analyze/tests; build the release APK; owner validates quickstart.md Q1–Q10 on the phone (APK built; on-phone validation by owner pending)

## Dependencies

Setup → Foundational → US1 → US2 → US3 → Polish. US1 and US2 touch the same controller file, so they
run sequentially; T002/T003 and T008/T011 (different files) can run in parallel.

## Implementation Strategy

US1 alone fixes the reported bug (MVP). US2 adds the lock-screen alert; US3 makes permissions and
timing robust.
