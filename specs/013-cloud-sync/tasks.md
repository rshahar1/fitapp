---
description: "Task list for cloud backup and sync"
---

# Tasks: Cloud Backup and Sync

**Input**: `specs/013-cloud-sync/` (spec, plan, research, data-model, contracts, quickstart). **Tests**: REQUIRED
(constitution III), written before the code they cover. `[P]` = parallel (different files). `[USn]` = user story.

## Phase 1: Setup

- [x] T001 Add `supabase_flutter`, `google_sign_in` to pubspec; `package.json` with devDependency `@electric-sql/pglite`; `node_modules/` in .gitignore
- [x] T002 [P] `env/example.json` + `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID` (empty); `lib/core/env.dart` reads them via `String.fromEnvironment`, exposes `isSyncConfigured`
- [x] T003 [P] `supabase/config.toml` (`supabase init` layout, project not linked); `docs/sync-setup.md` (Google Cloud web + Android clients with debug/release SHA-1, Supabase Google provider, nonce note, `supabase db push`, deploy `delete-account`)

## Phase 2: Foundational (blocks all stories)

### Backend (tests first)

- [x] T004 PGlite runner `tool/db_test.mjs` + auth stub `supabase/tests/_auth_stub.sql` (schema `auth`, `auth.users`, `auth.uid()` from `request.jwt.claim.sub`, roles `anon`/`authenticated`, helper to act as a user)
- [x] T005 SQL tests (fail first) — `supabase/tests/`: `rls_test.sql` (A vs B vs anon on every table, user_id immutable), `lww_test.sql`, `tombstone_test.sql` (delete wins, cascade, child under tombstoned parent), `sync_push_test.sql` (order, rejected-row isolation, deletes of unknown ids)
- [x] T006 Migration `supabase/migrations/<ts>_sync_tables.sql`: 10 tables per data-model §2, indexes `(user_id, server_updated_at)`, CHECKs
- [x] T007 Migration `<ts>_sync_triggers.sql`: `sync_guard`, `sync_child_of_tombstone`, `sync_cascade_tombstone`
- [x] T008 Migration `<ts>_sync_rls.sql`: RLS + owner policy + grants
- [x] T009 Migration `<ts>_sync_push.sql`: `sync_push(payload jsonb)` per contracts/sync-backend.md; T005 green
- [x] T010 [P] CI: job step `npm ci && node tool/db_test.mjs` in `.github/workflows/ci.yml`

### Local schema v8

- [x] T011 Tests: migration v7→v8 keeps data, creates `sync_state` — test/drift/fitapp/migration_test.dart
- [x] T012 `SyncState` table, schemaVersion 8, `from7To8`, regenerate, `make-migrations` (drift_schema_v8.json)
- [x] T013 [P] Delete-queue audit: a test per hard-delete path asserting `pending_deletes` (workout, workout exercise, set, template, template exercise, activity); fix any gap
- [x] T014 [P] `SettingsRepository`: whitelisted keys stamp `sync.settings_updated_at` / `sync.settings_dirty`; `syncedSettings()` / `applySyncedSettings()`; tests

### Sync engine (tests first)

- [x] T015 Pure rules + tests first — `lib/domain/sync_rules.dart`: `resolveIncoming` (data-model §6 table), `suffixName`, `pickSetSurvivor`; test/domain/sync_rules_test.dart
- [x] T016 Table registry `lib/data/sync/sync_table.dart`: local↔server mapping, FK order, row (de)serialisers (incl. exercises split into custom/overrides, `deleted_at`→`archived_at`, settings)
- [x] T017 `SyncRemote` interface + `PushBatch`/`PushResult` — lib/data/sync/sync_remote.dart; `FakeSyncRemote` in test/data/sync/fake_sync_remote.dart mirroring server rules
- [x] T018 Tests then `PushCollector` (pages ≤ 500, FK order, deletes first, clear-if-unchanged, rejected stay dirty) — lib/data/sync/push_collector.dart
- [x] T019 Tests then `PullApplier` (apply rules, collisions, tombstones, cursors with overlap, page transaction) — lib/data/sync/pull_applier.dart
- [x] T020 Tests then `SyncService` (pull→push cycle, single-flight, debounce, status stream, never throws) — lib/data/sync/sync_service.dart
- [x] T021 Two-device convergence tests (create/edit/conflict/delete/offline) — test/data/sync/two_device_test.dart (SC-007)
- [x] T022 Milestone gate: format, analyze, test, db tests; commit

## Phase 3: US1 — Turn on backup with Google (P1) 🎯 MVP

Independent test: sign in on a phone with history → all rows reach the backend; signed-out app sends nothing.

- [x] T023 [US1] `SupabaseSyncRemote` (rpc push, paged select, cloud-data probe) + unit tests on request/response mapping — lib/data/sync/supabase_sync_remote.dart
- [x] T024 [US1] `AuthRepository` (google_sign_in 7.x → `signInWithIdToken`, account stream, sign out, `isConfigured`) — lib/data/repositories/auth_repository.dart; tests with mocked auth seams
- [x] T025 [US1] `Supabase.initialize` only when configured; providers for client, auth, sync service — lib/main.dart, lib/data/providers.dart
- [x] T026 [US1] Settings "Account & backup" section (states per contracts/app-interfaces.md, Back up now, last backed up) + widget tests — lib/features/settings/
- [x] T027 [US1] Sync triggers: start, resume, after finish, after sign-in — lib/app/app.dart, workout finish call site
- [x] T028 [US1] Milestone gate; commit

## Phase 4: US2 — Restore on a new phone (P1)

- [x] T029 [US2] `DeviceBinding.decide/bind` (+ tests for each branch of data-model §5) — lib/data/sync/device_binding.dart
- [x] T030 [US2] `SyncService.restore` with progress; resumable (cursors) + tests incl. interrupted restore
- [x] T031 [US2] Restore progress UI in the account section; restored plans drive next suggestion (test)
- [x] T032 [US2] Milestone gate; commit

## Phase 5: US3 — Two phones in step (P2)

- [x] T033 [US3] Extend two-device tests: delete-vs-offline-edit, plan conflict, template deleted while used, hidden built-in stays hidden
- [x] T034 [US3] Milestone gate; commit

## Phase 6: US4 — Sign-in on a phone with data (P2)

- [x] T035 [US4] Merge and Replace dialogs wired to `DeviceBinding` decisions + widget tests
- [x] T036 [US4] `wipeUserData` (keeps built-ins, clears queues/cursors) + tests; name-clash merge test
- [x] T037 [US4] Milestone gate; commit

## Phase 7: US5 — Sign out, remove data, delete account (P3)

- [x] T038 [P] [US5] Edge Function `supabase/functions/delete-account/index.ts`
- [x] T039 [US5] Sign out / Remove data / Delete account actions with confirmations + widget tests
- [x] T040 [US5] Milestone gate; commit

## Phase 8: Polish

- [x] T041 [P] One-time backup nudge after 3rd finished workout (setting `sync.nudge_shown`) + test
- [x] T042 [P] Docs: PRD §8, `docs/ARCHITECTURE.md` sync design, README (setup, privacy, sync)
- [x] T043 Performance check: generated 300 workouts / 15k sets restore through `FakeSyncRemote` under budget (SC-002)
- [x] T044 Final gate; quickstart §1–2; owner steps for §3–4 listed in docs/sync-setup.md; commit
- [ ] T045 Owner: hosted Supabase project + Google Cloud OAuth clients (docs/sync-setup.md), then quickstart §4 on two phones

## Phase 9: Fix — merge prompt offers "Use my backup instead" (FR-023 amended 2026-11-15)

Found in the reinstall test: Android's own app backup restored a 2-day-old, pre-sign-in copy of the database, so
sign-in offered only Merge (re-uploading deleted items) or Cancel.

- [x] T046 [US4] Tests first: `AccountService.signIn` merge choice `useBackup` wipes, binds and restores without
  uploading phone rows — test/data/sync/account_service_test.dart; implement in lib/data/sync/account_service.dart
- [x] T047 [US4] Merge dialog gets a third action "Use my backup instead" + widget tests —
  lib/features/settings/account_section.dart, test/features/account_section_test.dart
- [x] T048 Gate: format, analyze, test; commit

## Phase 10: Hardening for public release (2026-11-15)

- [x] T049 Server size and range limits (migration `20261115000001_sync_limits.sql`), tests first —
  supabase/tests/limits_test.sql; limits sit above every app limit so real data is never rejected
- [x] T050 Release builds refuse to sign with the debug key unless `FITAPP_ALLOW_DEBUG_SIGNING=1`;
  `tool/make_release_keystore.sh` creates the release key outside the repo — android/app/build.gradle.kts
- [x] T051 Skip lint "vital" release checks for third-party plugin modules (lint crashes on plugin sources) —
  android/build.gradle.kts
- [x] T052 Docs: docs/release.md (signing, what is public in the APK, pre-publish checklist), README, sync-setup
- [x] T053 Verified: release APK (debug-signed, local test) runs on a Pixel 11 Pro, signed in, backs up

## Dependencies

Setup → Foundational (backend T004–T010 ∥ local T011–T014, then engine T015–T021) → US1 → US2 → US3, US4 → US5 →
Polish. US3 and US4 are independent of each other.

## Parallel examples

- Foundational: backend migrations/tests (T004–T010) alongside local schema work (T011–T014).
- US1: `SupabaseSyncRemote` (T023) alongside `AuthRepository` (T024); UI (T026) after both.

## Implementation strategy

MVP = Phases 1–3 (backup works, data is safe). Phase 4 makes restore usable; 5–7 harden multi-device and account
control. Hosted Supabase project and Google Cloud clients are owner steps (docs/sync-setup.md); everything else is
testable offline.
