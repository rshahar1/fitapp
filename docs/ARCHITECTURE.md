# Architecture

## Data flow

- Widgets (in `lib/features/` and `lib/widgets/`) never touch the database directly.
- Widgets read and mutate state through Riverpod providers.
- Providers call repositories (`WorkoutRepository`, `ExerciseRepository`), which own all business writes and transactions.
- Repositories use the drift database (local SQLite, source of truth); the progression logic in `lib/domain/` is pure Dart.

## Progression and edit rules

- On finish (transactional), for each planned exercise with logged sets: `plan = snapshot ?? currentPlan`, evaluate, store a snapshot (plan base, reps, sets, increment, `resultBaseWeight`), then advance the current base if progressed.
- The current base is advanced only if it still equals `plan.baseWeight`, so a hand-edited base is never overwritten.
- `canRewriteBase` is true only if the workout is the latest finished session containing that exercise and the current base equals the `resultBaseWeight` it produced (after rounding).
- Editing a finished workout re-evaluates against the snapshot and rewrites the base if `canRewriteBase`; resume (latest finished workout only, none in progress) and delete undo progression under the same condition.

## Sync design (Phase 2)

- Supabase (Postgres, Auth, RLS owner-only on every table); the server schema mirrors the local one plus `user_id`.
- Push: replay `pending_deletes` first (sets, then workout_exercises, then workouts), then upsert dirty rows in FK order, clearing `dirty` only if `updated_at` is unchanged since read.
- Failures leave rows dirty for retry; sync is silent on failure.
- Pull/restore downloads the user's rows into the local DB on a new device; triggers are app start, foreground, and after finishing a workout.
