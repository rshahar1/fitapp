# Research: Cloud Backup and Sync (013)

Background analysis: `docs/proposals/cloud-sync-supabase.md`. This file records the decisions the plan relies on.

## R1. Sync approach

- **Decision**: Hand-rolled local-first sync over the existing Drift database: push dirty rows and `pending_deletes`,
  pull changes since a per-table cursor.
- **Rationale**: The schema already carries client UUIDs, `updated_at`, `dirty` and a delete queue (constitution I).
  Data has a single owner, so conflicts are rare and last-writer-wins is enough. No new runtime service; all logic is
  testable with in-memory Drift and a fake remote.
- **Alternatives**: PowerSync (paid service, second SQLite layer, overkill for backup); Brick (replaces Drift and all
  repositories); online-first (breaks offline-first); file export (no merge or multi-device).

## R2. Backend

- **Decision**: Supabase (Postgres + Auth + row-level security), schema managed as Supabase CLI migrations in
  `supabase/migrations/`, tested with pgTAP via `supabase test db` against the local Docker stack.
- **Rationale**: Already chosen in PRD §8/§10; relational data, SQL, RLS, no per-read billing.
- **Alternatives**: Firebase (rejected in PRD); a custom server (more ops).

## R3. Deletions across devices

- **Decision**: Server rows are never hard-deleted by sync. Replaying a local `pending_delete` sets `deleted_at` on the
  server row (tombstone). Pull applies tombstones as local hard deletes. A trigger tombstones children of a tombstoned
  parent; a child upserted under an already-tombstoned parent is tombstoned on arrival.
- **Rationale**: Hard deletes are invisible to a device that pulls later (gap 1 in the proposal). Cascading tombstones
  keep a fresh restore free of orphans.
- **Alternatives**: Separate `deletions` log table (two places to query); periodic full resync (slow, still racy).

## R4. Conflict resolution

- **Decision**: Last-writer-wins on the client-set `updated_at`, enforced by a `BEFORE UPDATE` trigger; a tombstoned row
  ignores every later update (delete wins, FR-017). On pull, an incoming row never overwrites a local row that is dirty
  and newer (FR-019).
- **Rationale**: Simple, deterministic, matches the spec. Clock skew only affects which of two concurrent edits wins,
  never whether a change is delivered (delivery uses the server cursor, R5).
- **Alternatives**: Field-level merge or CRDTs (complexity without user value for one person's gym log).

## R5. Pull cursor

- **Decision**: Each server row has `server_updated_at` set by trigger to `clock_timestamp()` on every insert/update.
  The device keeps one cursor per table (`sync_state`) and pulls `server_updated_at > cursor − 2 min`, ordered, paged by
  1000. Re-applying rows is idempotent.
- **Rationale**: Server clock avoids device clock skew; the 2-minute overlap covers transactions that commit out of
  timestamp order.
- **Alternatives**: Bigint sequence (same commit-order caveat); logical replication (heavy).

## R6. Push transport

- **Decision**: One Postgres function `sync_push(payload jsonb)`, `SECURITY INVOKER` (RLS applies), called through
  `supabase.rpc`. Deletes first, then upserts in FK order. Each row runs in its own sub-block (`BEGIN … EXCEPTION`);
  rejected rows are returned with an error and stay dirty on the device, so one bad row never blocks the rest.
  Client sends pages of ≤ 500 rows, table by table in FK order.
- **Rationale**: One round trip per page, ordered, and failure-isolated.
- **Alternatives**: PostgREST bulk upsert per table (more round trips, one bad row fails the whole request).

## R7. Uniqueness on the server

- **Decision**: No name-uniqueness and no `(workout_exercise_id, set_no)` uniqueness on the server; only primary keys
  and FKs. The device keeps its local unique indexes. When a pulled row collides with a different local row:
  - template / custom exercise name: the **local** row is renamed with suffix " (2)", " (3)" … and marked dirty;
  - set `(workout_exercise_id, set_no)`: the older row (by `updated_at`) is deleted locally and queued for delete.
- **Rationale**: A server unique violation would reject a row forever and block that device's sync (poison pill).
  Resolving on pull converges both devices and implements the spec's merge rule (FR-023).
- **Alternatives**: Partial unique indexes `WHERE deleted_at IS NULL` (still a poison pill under concurrent offline
  edits).

## R8. Exercises model

- **Decision**: The built-in library stays in app code. Server tables: `custom_exercises` (local `exercises` rows with
  `is_custom = 1`) and `exercise_overrides (user_id, exercise_id, archived_at)` for built-ins the user hid. The local
  column `exercises.deleted_at` (feature 012 "archived": hidden but kept for history) maps to server `archived_at`,
  never to the sync tombstone `deleted_at`.
- **Rationale**: Fixed built-in UUIDs are shared by all users (gap 3); keeping them out of the server avoids a global
  table with an RLS exception. Separating "archived" from "tombstoned" avoids deleting history-referenced exercises.
- **Alternatives**: Global library table with `owner_id IS NULL` (PRD §8 draft) — more RLS surface, no benefit.

## R9. Per-user composite keys

- **Decision**: `exercise_state` and `exercise_overrides` use PK `(user_id, exercise_id)`. All other tables keep PK
  `id` (client UUID). `user_id` defaults to `auth.uid()` and is never sent by the client; the update trigger keeps it
  immutable.
- **Rationale**: Built-in exercise ids are shared across users.

## R10. Settings sync

- **Decision**: `user_settings (user_id PK, data jsonb, updated_at)` holds the whitelist `default_rest_seconds`,
  `rest_alert_haptic`, `rest_alert_sound`. Locally, `SettingsRepository` stamps `sync.settings_updated_at` and sets
  `sync.settings_dirty` when a whitelisted key changes. LWW as for rows.
- **Rationale**: FR-009; the local `settings` table is key/value without sync columns, and a migration of it is
  unnecessary for three keys.

## R11. Authentication

- **Decision**: Native Google sign-in with `google_sign_in` 7.x (`GoogleSignIn.instance.initialize(serverClientId:
  <web client id>)`, `authenticate()`, ID token from `account.authentication.idToken`, access token from
  `authorizationClient.authorizationForScopes(['email','profile'])`), then
  `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken:, accessToken:)`. Google Cloud: one Web
  client (server client id) and Android clients for the debug and release SHA-1; all client ids registered on the
  Supabase Google provider. If the Android ID token carries a nonce Supabase cannot verify, enable "Skip nonce check"
  on the provider (documented setup step; verified during Phase 4).
- **Rationale**: Native account picker (FR-004, SC-004), no browser redirect, follows Supabase's current Flutter
  guide.
- **Alternatives**: OAuth browser flow with deep link (more taps); anonymous auth + `linkIdentity` (rejected in the
  proposal §4.1: does not protect a lost phone, breaks the privacy principle).

## R12. Device binding and ownership

- **Decision**: Settings keys `sync.user_id` (account this phone's data belongs to) and `sync.last_success_at`.
  On sign-in the app picks one of: first backup, restore, merge prompt, or switch-account prompt (data-model §5).
- **Rationale**: FR-006, User Story 4.

## R13. Configuration and secrets

- **Decision**: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (publishable key), `GOOGLE_WEB_CLIENT_ID` via
  `--dart-define-from-file=env/dev.json` (git-ignored); `env/example.json` gets the keys with empty values. If they are
  empty the Account section shows "Backup not configured" and the app works locally. The service-role key is used
  only by the `delete-account` Edge Function (Supabase-managed secret), never in the app or repo.
- **Rationale**: Constitution VI; FR-027.

## R14. Account deletion

- **Decision**: Supabase Edge Function `delete-account` (verifies the caller's JWT, calls `auth.admin.deleteUser`); all
  tables reference `auth.users ON DELETE CASCADE`.
- **Rationale**: FR-007; Play Store account-deletion policy.

## R15. Testing strategy

- **Decision**:
  - pgTAP (`supabase/tests/`): RLS isolation (user A vs B vs anon), LWW, delete-wins, tombstone cascade, child under
    tombstoned parent, `sync_push` rejected-row isolation, `user_id` immutability.
  - Dart unit tests (`test/data/sync/`): `SyncService` against in-memory Drift + `FakeSyncRemote` that implements the
    same server rules (LWW, tombstones, cursors); two simulated devices converge (SC-007); edit during push stays dirty;
    pull never clobbers newer dirty rows; name/set collision resolution; drift migration v7→v8.
  - Widget tests: Account section states, sign-in decision dialogs.
  - Opt-in integration test (`integration_test/sync_test.dart`, tag `supabase`) against the local stack with two
    test users created by the seed script.
- **Rationale**: Constitution III; the fake keeps unit tests fast and offline while pgTAP proves the real rules.
