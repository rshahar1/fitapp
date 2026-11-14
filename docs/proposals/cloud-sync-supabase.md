# Proposal: Cloud backup and sync with Supabase (PRD §8 / M7)

Status: accepted · 2026-11-14 — superseded in detail by `specs/013-cloud-sync/` (plan, research, data-model).
Notable changes there: no server-side uniqueness beyond primary keys (collisions resolved on pull), pull runs
before push, per-row rejection in `sync_push`, and feature-012 archived exercises map to `archived_at`.

## 1. Where we start from

The app was built with sync in mind, so most of the local groundwork already exists:

| Already in place | Where |
|---|---|
| Client-generated UUID v4 ids on every row (no id collisions between devices or users) | constitution, PRD §7 |
| `updated_at` + `dirty` on every syncable table (`SyncColumns` mixin) | `lib/data/db/tables.dart` |
| `pending_deletes` delete queue, written by the repositories | `workout_repository.dart`, `template_repository.dart`, `activity_repository.dart` |
| Fixed UUIDs for the built-in exercise library | `lib/data/db/seed_library.dart` |
| Drift with versioned `stepByStep` migrations (schema v7) | `lib/data/db/app_database.dart` |
| `env/*.json` git-ignored, `env/example.json` committed | `.gitignore` |
| Supabase already chosen over Firebase (relational data, RLS, no per-read billing) | PRD §10 decisions |

The PRD's sync design (push dirty rows, replay deletes first, clear `dirty` only if `updated_at` did not change) is
correct for **backup**. It has four gaps that show up once a second device **pulls**:

1. **Deletes are invisible to other devices.** Push replays `pending_deletes` as hard deletes on the server, so a
   device that pulls later never learns the row is gone. Fix: server **tombstones** (`deleted_at`).
2. **No pull cursor.** "Download the user's rows" works for a first restore but not for incremental pulls.
   Fix: a server-assigned `server_updated_at` per row (trigger), and a per-table cursor on the device.
3. **Per-user rows keyed by a shared id.** `exercise_state` is keyed by `exercise_id`, and built-in exercises use the
   same fixed UUID for every user; a soft-deleted built-in (feature 012, `exercises.deleted_at`) is per-user state on a
   global row. Fix: composite keys `(user_id, exercise_id)` on the server and a per-user table for built-in overrides.
4. **No conflict rule.** Two devices editing the same plan need a rule. Fix: last-writer-wins on the client
   `updated_at`, enforced on the server, with **deletes always winning** (no resurrection).

## 2. Options considered

| Option | What it is | Verdict |
|---|---|---|
| **A. Local-first, hand-rolled push/pull over Drift** | Drift stays the source of truth; a `SyncService` pushes dirty rows and pending deletes to Supabase and pulls changes since a cursor. | **Recommended.** Builds on the scaffolding we already have, no new runtime, everything testable with in-memory Drift. Data is single-owner, so conflicts are rare and LWW is enough. |
| B. PowerSync (Supabase partner) | Managed Postgres→SQLite replication with a Drift integration and an upload queue. | Good if we later need real-time multi-device sync. Adds a paid service, a second SQLite layer, and a rewrite of the DB setup. Overkill for backup/restore. |
| C. Brick (`brick_offline_first_with_supabase`) | Offline-first ORM with its own models and queue. | Would replace Drift and every repository. Rejected. |
| D. Online-first (Supabase as source of truth, cache locally) | Read/write the API directly. | Breaks the offline gym-logging promise (constitution). Rejected. |
| E. File backup (export DB to Drive / iCloud) | Snapshot the SQLite file. | Cheap, but no merge, no multi-device, and restoring overwrites. Fine as an extra, not as the answer. |

## 3. Recommended architecture

```
 UI ─▶ Repositories ─▶ Drift (SQLite, source of truth)
                         │  dirty rows + pending_deletes
                         ▼
                    SyncService (lib/data/sync/)
                         │  push: rpc('sync_push', batch)      ─┐
                         │  pull: select ... where server_updated_at > cursor
                         ▼                                       │
                    Supabase: Auth ── Postgres (RLS owner-only) ◀┘
```

Principles:

- **The UI never talks to Supabase.** Repositories keep writing to Drift exactly as today; sync is a background
  concern. The app works identically when signed out or offline.
- **Sync is opt-in by signing in** (constitution: "data stays on device until the user opts into Phase 2 sync").
- **Idempotent everything.** Client UUIDs + upserts mean any push or pull can be retried safely.
- **Silent on failure, retried on the next trigger** (PRD §8). Show only "Last backed up …" in Settings.

### 3.1 What syncs

| Local table | Sync? | Server table |
|---|---|---|
| `exercises` (custom, `is_custom = 1`) | yes | `custom_exercises` |
| `exercises` (built-in) | only the per-user `deleted_at` | `exercise_overrides (user_id, exercise_id, deleted_at)` |
| `exercise_state` | yes | `exercise_state`, PK `(user_id, exercise_id)` |
| `templates`, `template_exercises` | yes | same names |
| `workouts`, `workout_exercises`, `sets` | yes | same names |
| `activities` | yes (route/splits are small text) | `activities` |
| `settings` | a whitelist only (default rest, haptic, sound) | `user_settings (user_id PK, data jsonb)` |
| `tracking_sessions`, `track_points` | **never** (live scratch data) | — |
| `pending_deletes` | local queue only | — |

The built-in library stays in app code (`seed_library.dart`), not on the server: it ships with each app version and
needs no RLS exception. (This simplifies PRD §8's "global library with `owner_id IS NULL`".)

### 3.2 Server table shape (example: `workouts`)

```sql
create table public.workouts (
  id                uuid primary key,                         -- client UUID
  user_id           uuid not null default auth.uid()
                      references auth.users on delete cascade,
  name              text,
  started_at        timestamptz not null,
  ended_at          timestamptz,
  notes             text,
  updated_at        timestamptz not null,                     -- client clock: LWW
  deleted_at        timestamptz,                              -- tombstone
  server_updated_at timestamptz not null default clock_timestamp()  -- pull cursor
);
create index on public.workouts (user_id, server_updated_at);
```

Every synced table gets the same four bookkeeping columns. Rules per table:

- Child FKs mirror local ones (`workout_exercises.workout_id → workouts`, `sets.workout_exercise_id → workout_exercises`,
  `template_exercises.template_id → templates`). `exercise_id` is **not** a server FK (it may point at a built-in).
- Uniques become **partial** so tombstones don't block re-logging:
  `unique (workout_exercise_id, set_no) where deleted_at is null`,
  `unique (user_id, lower(name)) where deleted_at is null` on `templates` and `custom_exercises`.
- `user_id` is never sent by the client; it comes from the column default `auth.uid()`.

### 3.3 Triggers (one shared function set, attached to each table)

```sql
-- BEFORE INSERT OR UPDATE
create function sync_guard() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' then
    if old.deleted_at is not null then return null; end if;          -- deletes win, no resurrection
    if new.deleted_at is null and new.updated_at < old.updated_at then
      return null;                                                    -- older write loses (LWW)
    end if;
    new.user_id := old.user_id;                                       -- ownership is immutable
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end $$;
```

Plus an `AFTER UPDATE OF deleted_at` trigger on parents that tombstones their children
(workout → workout_exercises → sets, template → template_exercises), so a fresh restore never pulls an orphan.

### 3.4 Row Level Security

Same policy on every table:

```sql
alter table public.workouts enable row level security;

create policy "owner can do everything" on public.workouts
  for all to authenticated
  using      (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
```

- `(select auth.uid())` instead of `auth.uid()` lets Postgres cache it per statement (Supabase perf advice).
- No `anon` policies at all. No `delete` from clients in practice (deletes are tombstone updates), but the policy
  allows it for account deletion.
- Hardening (optional): composite FKs `(workout_id, user_id) → workouts (id, user_id)` so a row can never point at
  another user's parent even by a guessed UUID.
- RLS is tested with **pgTAP** (`supabase test db`): user A cannot select, update or reference user B's rows;
  `anon` sees nothing.

### 3.5 Push (device → server)

One RPC, one transaction, `security invoker` (so RLS applies):

```
sync_push(payload jsonb) → { applied: int }
payload = { deletes: [{table, id}], upserts: { custom_exercises: [...], exercise_state: [...], templates: [...],
            template_exercises: [...], workouts: [...], workout_exercises: [...], sets: [...], activities: [...] } }
```

Order inside the function: tombstone the deletes (children first), then upsert in FK order. On the device:

1. Read `pending_deletes` and all `dirty = 1` rows (remember each row's `updated_at`), in pages of ~500.
2. Call `sync_push`.
3. On success, in one Drift transaction: delete the sent `pending_deletes` entries; set `dirty = 0` **only where
   `updated_at` still equals what was read** (a row edited during the push stays dirty).
4. On failure: change nothing; retry on the next trigger.

Note: today every user row is still `dirty = 1` (nothing has ever cleared it), so the **first push uploads the whole
history** with no extra code. Built-in exercise rows that were never touched are `dirty = 0` and are skipped.

### 3.6 Pull (server → device)

Per table, in FK order: `select * where server_updated_at > cursor - 2 minutes order by server_updated_at limit 1000`,
page until done, store the max `server_updated_at` as the table's cursor (new local `sync_state` table).
The 2-minute overlap covers transactions that committed out of timestamp order; re-applying rows is harmless.

Applying a pulled row in Drift:

- `deleted_at` set → hard-delete locally (local cascades handle children). Do **not** queue a `pending_delete`.
- Local row missing → insert with `dirty = 0`.
- Local row clean, or local `updated_at` older → overwrite, `dirty = 0`.
- Local row dirty and newer → keep it (it will win on the next push).
- After pulling `exercise_state` / `template_exercises`, no progression is re-run: plans are synced as values,
  and workout snapshots (`plan_*`, `result_base_weight`) travel with their rows.

Pull runs **after** push in every sync cycle, so local edits are never overwritten by stale server copies.

### 3.7 When it runs

App start, app resume, after finishing a workout, right after sign-in, and manual "Back up now" in Settings.
One sync at a time (single-flight lock), debounced ~5 s, skipped when signed out. No connectivity package needed:
a failed request is the offline signal.

## 4. Google Sign-In and data ownership

### 4.1 Options

| | Anonymous Supabase user first, link Google later | **Local-only until sign-in (recommended)** | Require sign-in at first launch |
|---|---|---|---|
| Survives a lost phone before linking? | **No** — the anonymous session lives on the lost phone | No (same) | Yes |
| Privacy promise (data stays on device until opt-in) | Broken | Kept | Changed |
| Extra work | Anonymous auth, CAPTCHA/abuse limits, `linkIdentity`, handling "Google account already exists" merges | One "claim local data" step | Onboarding gate, breaks offline first run |
| Fits current app | Partly | **Fully** | Poorly |

Anonymous auth sounds attractive, but it does not solve the actual problem (a lost device): until the user links an
identity, the anonymous user is unrecoverable. It costs a server user per install and adds the hardest edge case
(linking to a Google identity that already has data). So: **stay local-only, and make Google sign-in the switch that
turns on backup.** Encourage it with a one-time nudge (e.g. after the 3rd finished workout: "Back up your history").

### 4.2 Sign-in flow (native, no browser redirect)

1. Google Cloud: create a **Web** OAuth client (used as `serverClientId`) and an **Android** OAuth client per signing
   key (debug + release SHA-1). iOS client later.
2. Supabase dashboard: enable the Google provider, add the client IDs.
3. App: `google_sign_in` gets an ID token → `supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: …)`.
   Follow the current Supabase Flutter guide for the nonce setting; the `google_sign_in` 7.x API differs from older
   examples.
4. iOS later: Apple Sign-In is required by App Store rules when Google login is offered (already in PRD §8).

The anon key and URL go in `env/dev.json` (git-ignored), passed with `--dart-define-from-file`; `env/example.json`
gets empty keys. No service-role key ever ships in the app.

### 4.3 Claiming local data on first sign-in

The device remembers which account it is bound to (`settings.sync_user_id`).

| Situation | Behaviour |
|---|---|
| Device unbound, account has no cloud data (first device) | Bind, push everything (all rows are already dirty). |
| Device unbound, **no local user data**, account has cloud data (new / reinstalled phone) | Bind, full pull = **restore**. Show progress. |
| Device unbound, both have data (two phones used before signing in) | Ask once: "Merge this phone's history into your account?" Merge = push then pull; UUIDs never collide so it is a union. Name clashes on templates / custom exercises get a " (2)" suffix; the same exercise's `exercise_state` resolves by LWW. |
| Device bound to account X, user signs in as Y | Ask: "This phone holds X's data. Replace it with Y's?" → wipe local user data, bind to Y, restore. Never merge two accounts silently. |
| Sign out | Default: keep data on the phone, stop syncing (device stays bound to X). Offer "Remove my data from this phone". |
| Delete account (Play policy requires it once accounts exist) | Edge function with the service-role key deletes `auth.users` row → `on delete cascade` removes all data. |

## 5. Step-by-step implementation plan

This is a new feature, so it goes through Spec Kit: `/speckit-specify` → `/speckit-clarify` → `/speckit-plan` →
`/speckit-tasks` → `/speckit-implement` as **`013-cloud-sync`** on its own branch. Suggested phases:

**Phase 0 — Governance (docs only)**
1. `/speckit-constitution` amendment: Phase 2 is now in scope; allow `supabase_flutter`, `google_sign_in`.
2. Update PRD §8 and `docs/ARCHITECTURE.md` "Sync design" with tombstones, pull cursors, the exercise model (§3.1),
   LWW + delete-wins, and the ownership rules (§4.3).

**Phase 1 — Backend schema (no app changes)**
3. `supabase init`; migrations in `supabase/migrations/`; local stack with `supabase start` (Docker).
4. Tables from §3.1 with the bookkeeping columns, partial uniques, indexes, `sync_guard` + tombstone-cascade triggers,
   RLS policies, `sync_push` RPC.
5. pgTAP tests: RLS isolation, LWW, delete-wins, tombstone cascade, partial-unique re-log of a set number.

**Phase 2 — Local schema v8 (Drift)**
6. New `sync_state (table_name PK, cursor)` table; settings keys `sync_user_id`, `last_synced_at`.
7. Check every delete path queues `pending_deletes` (workout, workout exercise, set, template, template exercise,
   activity, custom exercise). Migration test from v7 keeps all data.

**Phase 3 — Sync engine (`lib/data/sync/`, tests first)**
8. A `SyncRemote` interface (push batch, pull page) with a Supabase implementation and an in-memory fake.
9. `SyncService.push`: paging, ordering, dirty-clear-if-unchanged, failure keeps state.
10. `SyncService.pull`: cursors with overlap, apply rules from §3.6, never marks rows dirty or queues deletes.
11. Unit tests with in-memory Drift + fake remote: two simulated devices converge; delete propagates; edit during push
    stays dirty; pull never clobbers a newer dirty row.

**Phase 4 — Auth**
12. Google Cloud + Supabase provider setup (manual, documented in `docs/`).
13. `AuthRepository` (Riverpod) wrapping `google_sign_in` + `supabase.auth`; session restore on start.
14. Settings → **Account** section: Sign in with Google, "Last backed up …", Back up now, Sign out, Remove data from
    this phone, Delete account.

**Phase 5 — Ownership flows and triggers**
15. Claim / restore / merge / switch-account flows from §4.3 with confirmation dialogs (widget tests).
16. Sync triggers (start, resume, after finishing a workout, after sign-in), single-flight + debounce.
17. Delete-account edge function.

**Phase 6 — End-to-end verification**
18. Integration test against the local Supabase stack: log on device A → sign in on a fresh install B → B shows the
    full history (the M7 acceptance criterion: "Sign in on a second phone restores full history").
19. Manual run on two emulators, airplane-mode edits, then reconnect.
20. Create the hosted Supabase project, apply migrations, release build with the real Android OAuth client.

## 6. Open questions for the owner

- Should restoring on a new phone also restore **in-progress** workouts, or only finished ones? (Proposal: all rows;
  an unfinished workout simply shows up as resumable.)
- Which settings sync? (Proposal: default rest time and alert preferences; never the active-rest timer keys.)
- iOS timing: Apple Sign-In becomes mandatory the moment an iOS build offers Google login.
