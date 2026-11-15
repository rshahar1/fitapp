---
description: "Task list for daily step count"
---

# Tasks: Daily step count

**Input**: `/specs/014-daily-steps/` (spec, plan). **Tests**: REQUIRED. `[P]` = parallel.

## Phase 1: Setup

- [x] T001 Constitution 1.6.0; spec, plan, tasks on branch `014-daily-steps`; `CLAUDE.md` active feature → 014
- [x] T002 Add `health` ^13.3.2 to pubspec

## Phase 2: Foundational — core, settings, providers, Android (tests first)

- [ ] T003 Tests: `todayStart`; settings `steps_enabled` default true / toggle / not marking sync dirty; `steps_intro_shown`; providers (disabled → no source calls, `unavailable`; granted → count; error → null) — test/core/step_source_test.dart, test/data/settings_repository_test.dart, test/data/step_providers_test.dart
- [ ] T004 `StepSource`, `StepAccess`, `NoopStepSource`, `todayStart` — lib/core/step_source.dart
- [ ] T005 `HealthConnectStepSource` (configure, status mapping, timeouts, try/catch) — lib/core/health_connect_step_source.dart
- [ ] T006 Settings keys + providers; `main.dart` override on Android — lib/data/repositories/settings_repository.dart, lib/data/providers.dart, lib/main.dart
- [ ] T007 Android: manifest permission/queries/rationale filter/alias, `FlutterFragmentActivity` + `getInitialRoute`, minSdk 26
- [ ] T008 Milestone gate: format, analyze, test; commit

## Phase 3: UI

- [ ] T009 [US1][US2] `StepsCard` + `StepsIntroSheet` on Train screen, resume refresh — lib/features/train/steps_card.dart, train_screen.dart; widget tests for every access state, intro shown once
- [ ] T010 [US3] Settings "Activity" group: Daily steps switch + access subtitle + privacy row — lib/features/settings/settings_screen.dart; widget tests
- [ ] T011 `PrivacyScreen` + `/privacy` route and initial-location switch — lib/features/settings/privacy_screen.dart, lib/app/router.dart; widget test
- [ ] T012 Milestone gate: format, analyze, test, `flutter build apk --debug`; commit

## Phase 4: Polish

- [ ] T013 README roadmap + docs/ARCHITECTURE.md (StepSource), PRD note; mark spec Implemented
