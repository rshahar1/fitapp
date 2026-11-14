# Implementation Plan: Start/Log Hub (center "+" action)

**Branch**: `011-start-hub` | **Date**: 2026-11-14 | **Spec**: [spec.md](./spec.md)

## Summary

A pure-Dart **start guard** (`lib/domain/start_guard.dart`) names the session in progress (gym
workout or GPS sport) and decides whether a new start is allowed. A shared **start service**
(`lib/features/start/start_actions.dart`, Riverpod `Provider`) reads the stored state at tap time,
applies the guard and either starts (empty gym, gym template, GPS setup route) or shows one
blocked-start snackbar with Open. The shell gets a custom 5-slot bottom bar (`Train · History ·
[+] · Progress · You`) where `[+]` opens the **Start/Log hub sheet** and is never a branch. Train
keeps its one-tap gym hero (now also the GPS "in progress" surface) and template STARTs, both via
the start service; header icons and "Log activity" go. A new **You** branch lists Exercise
library and Settings. The activity sheet loses Start live and becomes the past-session/edit form.

## Technical Context

**Language/Version**: Dart 3.14, Flutter 3.50 (unchanged)

**Primary Dependencies**: `flutter_riverpod`, `go_router` (`StatefulShellRoute.indexedStack`).
No new packages.

**Storage**: drift, no schema change (v6). `TemplateRepository.startWorkout` additionally refuses
while a tracking session exists (FR-014).

**Testing**: domain unit tests for the guard first (100% lines of `start_guard.dart`); repository
test for the template/tracking refusal; widget tests with the real router (`buildRouter()` +
in-memory DB, as in `gps_activity_test.dart`): hub from every tab, gym 1 tap, run start route,
blocked starts, You tab, no Start live in the sheet; existing tests updated for removed UI.

**Target Platform**: Android first; portrait.

**Constraints**: offline; 48 dp targets; semantics labels; gym start stays 1 tap from Train.

## Constitution Check

| Principle | Status |
|---|---|
| I Offline-first | Pass: no network, no schema change. |
| II Pure domain | Pass: guard logic in `lib/domain/start_guard.dart`, no Flutter/DB imports, tests first. |
| III Test-first gates | Pass: domain + repository tests before code; widget tests; format/analyze/test per milestone. |
| IV Layered architecture | Pass: business writes stay in repositories; `features/start` orchestrates UI flow only. |
| V One-tap gym UX | Pass: Train hero and template START remain 1 tap; 48 dp; `[+]` labelled "Start or log a session". |
| VI Privacy/secrets | Pass: nothing new leaves the device; no secrets. |
| VII Scope | Pass: no timed non-GPS sessions, no cardio templates, no feed changes (slices 2–3). |

No violations; Complexity Tracking empty.

## Design

### Domain — `lib/domain/start_guard.dart`

```dart
enum SessionKind { gym, tracking }

@immutable
class SessionInProgress {            // equality by kind + typeId
  const SessionInProgress.gym();
  const SessionInProgress.tracking(String typeId);
  final SessionKind kind;
  final String? typeId;              // tracking only
  String get label;                  // 'Workout' | activityLabel(typeId)
  String get continueLabel;          // 'Continue workout' | 'Continue running'
  String get blockedMessage;         // '<label> in progress. Finish it first.'
}

/// The session in progress; tracking wins if both exist (should not happen).
SessionInProgress? sessionInProgress({required bool hasActiveWorkout, String? trackingTypeId});

/// Null when a new start is allowed, otherwise the session that blocks it.
SessionInProgress? blockingSession(SessionInProgress? current) => current;
```

### Start service — `lib/features/start/start_actions.dart`

`StartActions(Ref)` via `startActionsProvider`:
- `Future<SessionInProgress?> current()` — reads `WorkoutRepository.activeWorkout()` and
  `TrackingRepository.session()` (stored state, not the stream cache).
- `startGym(BuildContext, {String? templateId})` — guard → `WorkoutRepository.startWorkout` or
  `TemplateRepository.startWorkout(id)` inside `guard()` → success haptic → push `/workout`.
- `startTracking(BuildContext, String typeId)` — guard → push `/track/new?type=<id>`.
- `open(BuildContext, SessionInProgress)` — push `/workout` or `/track/live`.
- Blocked → `showBlockedStart(messenger, router, session)`: hide current snackbar, show
  `blockedMessage` with action Open → `open`.
- `sessionInProgressProvider` (sync `Provider`) combines `activeWorkoutProvider` and
  `activeTrackingProvider` for display (hub Continue row, Train hero).

### Hub — `lib/features/start/start_hub_sheet.dart`

`showStartHub(BuildContext context)` opens a modal bottom sheet (drag handle, scroll-controlled).
Rows pop the sheet with a `HubChoice` (sealed: `ContinueChoice`, `GymChoice(templateId?)`,
`TrackChoice(typeId)`, `LogPastChoice(typeId?)`); after the sheet closes the caller executes the
choice with the *outer* context (so snackbars and navigation do not depend on the dead sheet
context). "More sports" expands in place to the non-live sports. Sections: "START NOW",
"EARLIER". Each row ≥ 48 dp with an icon (`activityIcon`, `fitness_center`, `history`).

### Shell — `lib/features/shell/shell_scaffold.dart`

Custom `_BottomBar` (`Material` + `SafeArea` + `Row` of 5 slots). Slots 0,1,3,4 map to branches
0..3 (`Train, History, Progress, You`); slot 2 is `_PlusButton` (accent circle, 56 dp, tooltip
and semantics "Start or log a session") that calls `showStartHub`. Tabs show icon + label,
accent when selected, `Semantics(selected:, button:)`.

### Router — `lib/app/router.dart`

New branch 4 `Routes.you = '/you'` → `YouScreen`. `/settings` and `/exercises` unchanged
(root-navigator routes).

### Screens

- `lib/features/you/you_screen.dart`: title "You", `Group` with rows Exercise library
  (`Routes.exercises`) and Settings (`Routes.settings`).
- `TrainScreen`: header = date kicker + title only. Hero: nothing in progress → "Ready to
  train?" + `Start gym workout`; gym → as today + `Continue workout`; tracking → "<Sport> in
  progress" + live `Tick` line "mm:ss · x.x km" (moved from `_TrackingBanner`) +
  `Continue <sport>`. Template START → `startGym(templateId:)` (dialog removed). "Log activity"
  button and `_TrackingBanner` removed.
- `activity_sheet.dart`: drop `_canStartLive`, `_startLive`, the Start live button and the "or
  log it manually below" text, plus unused imports; new-entry title "Log a past session".

### Docs

PRD §6 (5-slot nav, hub, You, routes `/you`), PRD changelog 2.7 and version; 001 route contract
(`specs/001-fitapp-v1/contracts/ui-routes.md`) gets `/you`, the bottom bar, hub and the new Train
tab; `CLAUDE.md` active feature → 011. Commit `docs/ux/unified-start-proposal.md`.

## Project Structure

```text
specs/011-start-hub/   spec.md, plan.md, research.md, quickstart.md, contracts/start-hub.md, tasks.md
lib/domain/start_guard.dart                         (new, pure)
lib/features/start/start_actions.dart               (new)
lib/features/start/start_hub_sheet.dart             (new)
lib/features/you/you_screen.dart                    (new)
lib/features/shell/shell_scaffold.dart              (rewrite: custom 5-slot bar)
lib/app/router.dart                                 (+ /you branch)
lib/features/train/train_screen.dart                (hero merge, start service, removals)
lib/features/activities/activity_sheet.dart         (Start live removed)
lib/data/repositories/template_repository.dart      (refuse while tracking)
test/domain/start_guard_test.dart                   (new, first)
test/data/template_repository_test.dart             (+ tracking refusal)
test/features/start_hub_test.dart                   (new)
test/features/{train_screen,activities,templates,workout_flow_ui}_test.dart,
test/features/tracking/tracking_ui_test.dart, test/e2e/gps_flow.dart (updated)
```

## Complexity Tracking

None.
