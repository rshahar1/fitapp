# Data Model: Cloud Backup and Sync (013)

Decisions referenced as R# are in [research.md](research.md).

## 1. Local (Drift) changes — schema v7 → v8

| Change | Detail |
|---|---|
| New table `sync_state` | `table_name TEXT PK`, `cursor DATETIME NOT NULL` (max `server_updated_at` pulled). Local only. |
| Settings keys (no schema change) | `sync.user_id` (bound account), `sync.last_success_at`, `sync.settings_updated_at`, `sync.settings_dirty` |
| Delete-queue coverage | Every hard delete of a synced row queues `pending_deletes`: workouts, workout_exercises, sets, templates, template_exercises, activities. Exercises are archived (soft), never hard-deleted. |
| Unchanged | All existing tables and columns. `dirty` defaults stay; existing user rows are already `dirty = 1`, so the first push uploads all history (FR-015). |

Migration `from7To8` only creates `sync_state`; no existing data is touched (FR-025). `make-migrations` dumps
`drift_schemas/fitapp/drift_schema_v8.json`.

## 2. Server (Postgres) tables

Common columns on every synced table (except where noted):

| Column | Type | Notes |
|---|---|---|
| `user_id` | `uuid not null default auth.uid() references auth.users on delete cascade` | Never sent by client; immutable (R9) |
| `updated_at` | `timestamptz not null` | Client clock, LWW (R4) |
| `deleted_at` | `timestamptz` | Tombstone (R3) |
| `server_updated_at` | `timestamptz not null` | Set by trigger, pull cursor (R5); index `(user_id, server_updated_at)` |

| Server table | PK | Columns (besides common) | Local source |
|---|---|---|---|
| `custom_exercises` | `id` | `name`, `muscle_group?`, `is_per_hand`, `default_increment`, `archived_at?` | `exercises` where `is_custom = 1` (`deleted_at` → `archived_at`) |
| `exercise_overrides` | `(user_id, exercise_id)` | `archived_at?` | `exercises` where `is_custom = 0` and `dirty = 1` |
| `exercise_state` | `(user_id, exercise_id)` | `base_weight`, `target_reps`, `target_sets`, `increment`, `rest_seconds?` | `exercise_state` |
| `templates` | `id` | `name`, `created_at`, `last_used_at?` | `templates` |
| `template_exercises` | `id` | `template_id → templates`, `exercise_id`, `position`, `base_weight?`, `target_reps?`, `target_sets?`, `increment?`, `rest_seconds?` | `template_exercises` |
| `workouts` | `id` | `name?`, `started_at`, `ended_at?`, `notes?` | `workouts` |
| `workout_exercises` | `id` | `workout_id → workouts`, `exercise_id`, `position`, `notes?`, `template_exercise_id?`, `plan_base_weight?`, `plan_target_reps?`, `plan_target_sets?`, `plan_increment?`, `result_base_weight?` | `workout_exercises` |
| `sets` | `id` | `workout_exercise_id → workout_exercises`, `set_no`, `weight`, `reps`, `is_overload`, `completed_at` | `sets` |
| `activities` | `id` | `type_id`, `started_at`, `duration_minutes?`, `distance_meters?`, `notes?`, `source`, `moving_seconds?`, `elevation_gain_meters?`, `route?`, `splits?` | `activities` |
| `user_settings` | `user_id` | `data jsonb` (whitelist R10); no `deleted_at` | `settings` keys `default_rest_seconds`, `rest_alert_haptic`, `rest_alert_sound` |

Not on the server: `tracking_sessions`, `track_points`, `pending_deletes`, `sync_state`, the built-in library (FR-010,
FR-012).

Rules:

- FKs only parent → child as listed (`ON DELETE CASCADE` for account deletion). `exercise_id` and
  `template_exercise_id` are not FKs (R8, matches local design).
- No uniqueness beyond PKs (R7).
- Light `CHECK`s mirroring app validation (e.g. `reps >= 0`, `weight >= 0`, `source in ('manual','gps')`) so obviously
  corrupt rows are rejected per row, not per batch.

## 3. Server triggers

| Trigger | When | Behaviour |
|---|---|---|
| `sync_guard` | `BEFORE INSERT OR UPDATE`, every table | UPDATE: if `old.deleted_at` set → skip (delete wins); if not a tombstone and `new.updated_at < old.updated_at` → skip (LWW); keep `old.user_id`. INSERT/UPDATE: `server_updated_at := clock_timestamp()`. |
| `sync_child_of_tombstone` | `BEFORE INSERT`, child tables | If the parent row is tombstoned, set `new.deleted_at := parent.deleted_at`. |
| `sync_cascade_tombstone` | `AFTER UPDATE OF deleted_at`, parent tables | Tombstone children: workouts → workout_exercises → sets; templates → template_exercises. |

## 4. Row-level security

On every table: RLS enabled; one policy `for all to authenticated using (user_id = (select auth.uid())) with check
(user_id = (select auth.uid()))`. No policies for `anon`. `sync_push` is `SECURITY INVOKER`. Grants: `authenticated`
gets select/insert/update; `delete` only via account deletion (service role).

## 5. Device binding state machine

```
                ┌──────────── sign out (keep data) ─────────────┐
                ▼                                               │
  [Unbound] ──sign in──▶ decide ──▶ [Bound to X, syncing] ──────┘
                           │               │
                           │               └─ sign in as Y ≠ X ─▶ confirm "replace" ─▶ wipe ▶ bind Y ▶ restore
                           │                                       cancel ─▶ stay bound to X, signed out
                           ├─ no local history, cloud empty  ─▶ bind ▶ (nothing to do)
                           ├─ no local history, cloud has data ─▶ bind ▶ restore (full pull, progress)
                           ├─ local history, cloud empty     ─▶ bind ▶ first backup (push all)
                           └─ local history, cloud has data  ─▶ ask "Merge?"
                                                                  merge ─▶ bind ▶ pull ▶ push
                                                                  use backup ─▶ wipe ▶ bind ▶ restore
                                                                  cancel ─▶ sign out, unbound
  [Any] ──remove data from phone──▶ wipe user data, keep built-ins, clear cursors ─▶ [Unbound]
  [Bound] ──delete account──▶ server delete ─▶ ask keep/remove local ─▶ [Unbound]
```

- "Local history" = any row in workouts, activities, templates, custom exercises, or a dirty exercise_state/override.
- "Cloud has data" = one `head` count query on `workouts` + `activities` + `templates` for the user.
- A session that expires keeps the binding; Settings shows "Sign in again" (signing in again as X resumes).

## 6. Sync cycle (per run)

1. **Guard**: signed in, bound to the session's user, not already running (single-flight), debounce 5 s.
2. **Pull** in FK order: `custom_exercises`, `exercise_overrides`, `exercise_state`, `templates`, `template_exercises`,
   `workouts`, `workout_exercises`, `sets`, `activities`, `user_settings`. Apply rules below. Advance each table's
   cursor after its pages are applied (one Drift transaction per page).
3. **Push**: `pending_deletes` (children first), then dirty rows in the same FK order, pages ≤ 500. After each page:
   remove sent deletes; clear `dirty` only where `updated_at` equals the value read; leave rejected rows dirty.
4. Record `sync.last_success_at` when both phases complete with no transport error.

Pull runs before push so name/set collisions (R7) are resolved locally before pushing; FR-019 rules keep local
unsynced edits safe in either order.

### Pull apply rules (per incoming row)

| Incoming | Local state | Action |
|---|---|---|
| `deleted_at` set | exists | hard-delete locally (cascades); remove any matching `pending_deletes`; do not queue a delete |
| `deleted_at` set | missing | nothing |
| live | missing | insert with `dirty = 0` (after collision check) |
| live | clean, or dirty with `updated_at` ≤ incoming | overwrite, `dirty = 0` |
| live | dirty and newer | keep local |
| live | local id is in `pending_deletes` | skip (local delete will win on push) |
| template/custom-exercise name equals another local row's name | — | rename the local row " (n)", mark dirty, then apply |
| set with same `(workout_exercise_id, set_no)` as another local set | — | keep the newer by `updated_at`; delete + queue the older |

Pulled rows never re-run progression (FR-024); plan values and snapshots arrive as data.

## 7. Validation rules carried over

Existing repository validation (names 1–40 chars, durations 1–1440, notes ≤ 200, weights rounded via `roundWeight`)
is unchanged; pulled data is trusted as already validated by the app that wrote it, and server `CHECK`s catch gross
corruption.
