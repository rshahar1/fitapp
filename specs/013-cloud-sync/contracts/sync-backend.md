# Contract: Sync backend (Supabase)

All calls use the signed-in user's JWT (`authenticated` role). Table shapes: [data-model.md §2](../data-model.md).
Timestamps are ISO-8601 UTC strings; ids are UUID strings; column names are snake_case as on the server.

## Push — `rpc('sync_push', { payload })`

Request:

```json
{
  "payload": {
    "deletes": [ { "table": "sets", "id": "…" }, { "table": "workouts", "id": "…" } ],
    "upserts": {
      "custom_exercises":   [ { "id": "…", "name": "…", "muscle_group": null, "is_per_hand": false,
                                "default_increment": 2.5, "archived_at": null, "updated_at": "…" } ],
      "exercise_overrides": [ { "exercise_id": "…", "archived_at": "…", "updated_at": "…" } ],
      "exercise_state":     [ { "exercise_id": "…", "base_weight": 60, "target_reps": 8, "target_sets": 3,
                                "increment": 2.5, "rest_seconds": null, "updated_at": "…" } ],
      "templates": [], "template_exercises": [], "workouts": [], "workout_exercises": [], "sets": [],
      "activities": [],
      "user_settings": [ { "data": { "default_rest_seconds": 90 }, "updated_at": "…" } ]
    }
  }
}
```

- Any key may be omitted or empty. At most 500 rows per call (deletes + upserts).
- `deletes[].table` ∈ the synced table names; for composite-key tables the client never sends deletes.
- Clients never send `user_id`, `deleted_at` or `server_updated_at`.

Server behaviour (one transaction):

1. For each delete, in the order given: `update <table> set deleted_at = now(), updated_at = now() where id = $id`
   (no row → no-op).
2. Upserts in the fixed order custom_exercises → exercise_overrides → exercise_state → templates → template_exercises
   → workouts → workout_exercises → sets → activities → user_settings; `insert … on conflict (pk) do update`.
   Triggers apply LWW, delete-wins and tombstone rules.
3. Each row is isolated: an error (FK, CHECK, type) rejects only that row.

Response:

```json
{ "applied": 123, "rejected": [ { "table": "sets", "id": "…", "error": "23503: …" } ] }
```

Client handling: clear `dirty` / remove `pending_deletes` for every sent row **not** in `rejected` (and, for dirty
rows, only if local `updated_at` is unchanged). Rejected rows stay pending and are retried next cycle. A transport
error (network, 401, 5xx) changes nothing locally.

Note: a row skipped by LWW or delete-wins counts as applied (the server state is authoritative and will arrive on the
next pull).

## Pull — PostgREST select per table

```
GET /rest/v1/<table>?select=*&server_updated_at=gt.<cursor − 2 min>&order=server_updated_at.asc,<pk>.asc&limit=1000
```

- RLS limits rows to the caller. Tombstoned rows are included (`deleted_at` not null).
- Page by repeating with `server_updated_at=gte.<last seen>` and skipping already-seen PKs, until fewer than 1000 rows
  return. Cursor for a never-synced table: epoch.

## Cloud-has-data probe

`HEAD /rest/v1/<table>?select=id&deleted_at=is.null&limit=1` with `Prefer: count=exact` on `workouts`, `activities`,
`templates`; any count > 0 → cloud has data.

## Edge Function — `POST /functions/v1/delete-account`

- Auth: caller JWT required. Body: none.
- Effect: deletes the caller's `auth.users` row with the service role; FK cascades delete every synced row.
- Response: `204` on success; `401` without a valid JWT; `500` on failure (client shows an error and stays signed in).

## Auth

`supabase.auth.signInWithIdToken(provider: google, idToken, accessToken)` → session persisted by `supabase_flutter`.
`supabase.auth.signOut()` on sign-out. No other auth endpoints are used.
