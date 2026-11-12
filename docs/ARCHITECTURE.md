# Architecture

## Data flow

- Widgets (in `lib/features/` and `lib/widgets/`) never touch the database directly.
- Widgets read and mutate state through Riverpod providers.
- Providers call repositories (`WorkoutRepository`, `ExerciseRepository`), which own all business writes and transactions.
- Repositories use the drift database (local SQLite, source of truth); the progression logic in `lib/domain/` is pure Dart.
- Providers live in `lib/data/providers.dart` (Riverpod 3, no codegen).
- Read models are streams built with `watchQuery` in `lib/data/watch.dart`: it runs a loader and re-runs it whenever any table it reads is updated, so screens refresh automatically after writes.

```
widget -> provider (lib/data/providers.dart) -> repository -> drift (SQLite)
   ^                                                              |
   +---------------- watchQuery stream (lib/data/watch.dart) <----+
```

## Progression and edit rules

Rules follow PRD sections 4.2 to 4.4. The evaluation itself (`lib/domain/progression.dart`) is pure Dart: sets 1..N-1 at base, set N at base + increment, weights rounded to 0.25 kg. Checked in order: working set missing gives `incomplete`; working set under target reps or under base weight gives `missed_reps`; overload set missing gives `no_overload_set`; overload weight <= base gives `overload_not_heavier`; otherwise next base is the weight lifted on set N (`progressed`). Overload-set reps do not matter, and exercises without a plan never progress.

Implementation in `WorkoutRepository`:


- On finish (transactional), for each planned exercise with logged sets: `plan = snapshot ?? currentPlan`, evaluate, store a snapshot (plan base, reps, sets, increment, `resultBaseWeight`), then advance the current base if progressed.
- The current base is advanced only if it still equals `plan.baseWeight`, so a hand-edited base is never overwritten.
- `canRewriteBase` is true only if the workout is the latest finished session containing that exercise and the current base equals the `resultBaseWeight` it produced (after rounding).
- Editing a finished workout re-evaluates against the snapshot and rewrites the base if `canRewriteBase`; resume (latest finished workout only, none in progress) and delete undo progression under the same condition.

- Legacy sessions without a snapshot use the current plan only if they are the latest session of that exercise; otherwise they are not re-evaluated.
- Summary on finish lists each progressed or unchanged exercise; a workout with no logged sets is offered for discard.

## Rest timer

- `RestTimerController` (`lib/features/workout/rest_timer_controller.dart`) stores the start timestamp and target duration in the settings table, so the timer survives app restarts.
- The displayed remaining time is derived from the clock (now minus start), never from a ticking counter, so it stays correct after backgrounding.
- A separate alarm `Timer` fires the haptic and sound at the end while the app is alive. Background notification and an audible Android sound are not implemented yet.

## Error handling

- Async UI actions are wrapped in `guard()` (`lib/widgets/guard.dart`): exceptions are caught and shown to the user as a SnackBar instead of crashing or failing silently.
- Multi-row writes run in drift transactions so a failure leaves no partial state.

## Testing strategy

- Domain logic (progression, stats) is covered by pure unit tests, written first.
- Data tests run repositories against an in-memory drift database (finish, edit, resume, delete, `canRewriteBase`).
- Widget tests cover screens and shared widgets; an end-to-end widget test lives in `test/e2e`.
- `integration_test/` runs key flows on a device or emulator (`flutter test integration_test`).

## Sync design (Phase 2)

- Supabase (Postgres, Auth, RLS owner-only on every table); the server schema mirrors the local one plus `user_id`.
- Push: replay `pending_deletes` first (sets, then workout_exercises, then workouts), then upsert dirty rows in FK order, clearing `dirty` only if `updated_at` is unchanged since read.
- Failures leave rows dirty for retry; sync is silent on failure.
- Server-side library (`owner_id IS NULL`) is readable by all; there are no friendship tables.
- Pull/restore downloads the user's rows into the local DB on a new device; triggers are app start, foreground, and after finishing a workout.
