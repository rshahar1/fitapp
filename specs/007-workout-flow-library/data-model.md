# Data Model: 007 Workout Flow Fixes, Exercise Library and History Calendar

No schema change (stays v4).

## Live session (settings key `live_workout`, device-local JSON)

| Field | Type | Meaning |
|---|---|---|
| workoutId | String | The workout in progress |
| liveSince | UTC ISO-8601 | When it last became live (start or resume) |
| priorSeconds | int ≥ 0 | Duration accumulated before resuming (0 for a new workout) |
| day | `yyyy-MM-dd` or null | Day chosen with the Date row; null = keep the start day |

Ignored when `workoutId` is not the in-progress workout (stale record).

## Exercises (existing columns)

- `muscle_group`: one of `Chest, Back, Legs, Shoulders, Arms` or NULL (= "Custom"). Now settable
  for custom exercises on create and edit.
- Built-in rows (`is_custom = false`) are never updated by `updateCustom`.

## Workouts (existing columns)

- `started_at` / `ended_at` may be shifted by whole local days (`setWorkoutDay`, or on finish
  with a chosen day). Duration is preserved.
