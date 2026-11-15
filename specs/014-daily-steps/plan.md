# Implementation Plan: Daily step count

**Branch**: `014-daily-steps` | **Spec**: [spec.md](spec.md)

## Technical Context

Flutter, Riverpod, drift (key/value settings only), go_router. New package `health` ^13.3.2
(Health Connect on Android). No schema change. Android `minSdk` 24 → 26 (required by the Health
Connect client; drops Android 7.x).

## Constitution Check (1.6.0)

- I Offline-first: steps are read on device; no network; every screen works when reading fails. ✅
- III Tests first: settings and source-state logic tested before UI; fake `StepSource` for widgets. ✅
- IV Layering: widgets never call `health`; they use `StepSource` through providers. ✅
- VI Privacy: read-only `READ_STEPS`; counts never stored, synced or sent. ✅
- VII Scope: today only, Android only, no goals/history/HealthKit/writes. ✅

## Design

### Core — `lib/core/step_source.dart`

```dart
enum StepAccess { unavailable, needsInstall, notGranted, granted }

abstract interface class StepSource {
  Future<StepAccess> access();             // SDK status + hasPermissions(STEPS, READ)
  Future<bool> requestAccess();            // requestAuthorization([STEPS], [READ])
  Future<void> installHealthConnect();     // store page (needsInstall)
  Future<int?> stepsBetween(DateTime start, DateTime end); // aggregate; null on error
}
class NoopStepSource implements StepSource { /* unavailable, null */ }
```

- `HealthConnectStepSource` (`lib/core/health_connect_step_source.dart`) wraps `Health()`:
  `configure()` once (lazy), `getHealthConnectSdkStatus()` → `sdkUnavailable` → `unavailable`,
  `sdkUnavailableProviderUpdateRequired` → `needsInstall`; `getTotalStepsInInterval` for counts.
  Every call is wrapped in try/catch + a 5 s timeout; errors log and return the safe value
  (`unavailable` / `false` / `null`). Non-Android platforms → `unavailable`.
- `todayStart(DateTime now)` = local midnight of `now` (pure helper, tested).

### Settings — `SettingsRepository`

- `steps_enabled` (default true): `watchStepsEnabled()`, `setStepsEnabled(bool)`.
- `steps_intro_shown` (default false): `stepsIntroShown()`, `markStepsIntroShown()`.
- Device-local: neither key marks settings dirty for sync.

### Providers — `lib/data/providers.dart`

- `stepSourceProvider` (Noop by default; `main.dart` overrides with `HealthConnectStepSource` on
  Android, same pattern as `restAlertsProvider`).
- `stepsEnabledProvider` (StreamProvider<bool>).
- `stepAccessProvider` (FutureProvider.autoDispose<StepAccess>) — returns `unavailable` without
  calling the source when disabled.
- `todayStepsProvider` (FutureProvider.autoDispose<int?>) — only when enabled and `granted`;
  uses `clockProvider`.
- Refresh: Train screen and Settings invalidate both on `AppLifecycleListener.onResume`.

### UI

- `lib/features/train/steps_card.dart` `StepsCard` placed after `_HeroCard` on the Train screen:
  hidden when disabled or `unavailable`; `granted` → big tabular count ("Steps today",
  `NumberFormat.decimalPattern`), "—" when null, hint "Turn on Health Connect sharing in Google
  Fit" when 0; `notGranted` → "Connect" button (requestAccess, then invalidate); `needsInstall` →
  "Get Health Connect".
- First-use sheet `StepsIntroSheet`: shown once from Train screen (post-frame) when enabled,
  intro not shown and access is `notGranted`. "Connect" → requestAccess; both buttons mark shown.
- Settings: new "Activity" `Group` before "Units" with a `SwitchListTile` "Daily steps" whose
  subtitle shows the access state. Turning on with access `notGranted` requests access directly;
  `needsInstall` → install.
- Theme tokens only; Semantics on the card and buttons; 48 dp targets.

### Android

- Manifest: `<uses-permission android:name="android.permission.health.READ_STEPS"/>`;
  queries `com.google.android.apps.healthdata` package + `ACTION_SHOW_PERMISSIONS_RATIONALE`;
  intent-filter `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` on `MainActivity`;
  `activity-alias ViewPermissionUsageActivity` (VIEW_PERMISSION_USAGE / HEALTH_PERMISSIONS,
  permission `START_VIEW_PERMISSION_USAGE`).
- `MainActivity : FlutterFragmentActivity()`, overriding `getInitialRoute()` to return
  `/privacy` when started by either rationale action.
- Router: `initialLocation` = `/privacy` when `PlatformDispatcher.instance.defaultRouteName ==
  '/privacy'`, else Train. New `PrivacyScreen` (`lib/features/settings/privacy_screen.dart`):
  short static text — what is read (steps, read-only), where it stays (on the phone), how to turn
  it off; also reachable from Settings → Activity ("How step data is used").
- `minSdk = 26` in `android/app/build.gradle.kts`.

## Risks

- Play Console health declaration and a hosted privacy policy URL are owner tasks before release.
- `FlutterFragmentActivity` switch: verify notifications, location and Google sign-in still work
  (debug APK build in CI; manual check on device).
