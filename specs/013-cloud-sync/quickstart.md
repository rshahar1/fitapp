# Quickstart: validating Cloud Backup and Sync (013)

## Prerequisites

- Docker running; Supabase CLI installed (`brew install supabase/tap/supabase`).
- `env/dev.json` (git-ignored) with `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_WEB_CLIENT_ID`; keys listed with
  empty values in `env/example.json`.
- For real Google sign-in: Google Cloud Web client + Android clients (debug and release SHA-1), registered on the
  Supabase Google provider (see `docs/sync-setup.md`, created in implementation).

## 1. Backend rules (pgTAP)

```bash
supabase start
supabase db reset          # applies supabase/migrations and seed (two test users)
supabase test db           # RLS isolation, LWW, delete-wins, tombstone cascade, sync_push isolation
```

Expected: all tests pass; SC-006 is covered by the RLS tests.

## 2. App logic (fast, offline)

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/data/sync test/data/db
```

Expected: two simulated devices converge for create / edit / conflicting edit / delete / offline-reconnect scenarios
(SC-007); migration v7→v8 keeps data (FR-025); full suite `flutter test` stays green.

## 3. End to end against the local stack

```bash
flutter test integration_test/sync_test.dart --dart-define-from-file=env/dev.json
```

Uses the seed test users (email/password sign-in is enabled only on the local stack for this test). Scenario: device A
logs history → syncs → fresh database B signs in as the same user → restore → contents equal (SC-001).

## 4. Manual on emulators (real Google sign-in)

1. Emulator A with existing history: Settings → Account & backup → Sign in with Google. Expect "Last backed up …"
   within 30 s (SC-003, SC-004).
2. Airplane mode on A, log and finish a workout, no errors; airplane mode off, reopen app → backed up within 30 s.
3. Fresh emulator B, sign in with the same account → restore progress → History, Progress, templates, plans,
   activities (with routes) match A; next workout suggestion continues the plan (US2).
4. Delete a workout on A, edit it on B offline, bring B online → it is gone on both and stays gone (FR-017).
5. Sign in on B with a second Google account → Replace prompt; Cancel leaves B unchanged (US4).
6. Sign out, Remove my data, Delete account flows (US5); check the Supabase dashboard shows no rows for the deleted
   user.
