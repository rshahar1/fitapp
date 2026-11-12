# Contract: Repositories (`lib/data/repositories/`)

Repositories are the only writers to the database. Every method marked **[txn]** runs inside one
`db.transaction`. All methods catch drift/SQLite exceptions, log them, and rethrow a typed
`DataException` that the UI turns into a short message (never a crash). Streams are drift
`watch()` queries exposed to Riverpod.

## ExerciseRepository

```dart
Future<void> seedLibrary();                                   // [txn] idempotent upsert, on startup
Stream<List<Exercise>> watchExercises({String? query});       // search, grouped in UI by muscle group
Future<Exercise> createCustom({required String name,
    required bool perHand, required double increment});       // throws DuplicateName (case-insensitive)
Stream<ExercisePlan?> watchPlan(String exerciseId);
Future<void> savePlan(String exerciseId, PlanInput plan, {int? restSeconds}); // validates via domain
Stream<List<TrainedExercise>> watchTrainedExercises();        // most recent first + current base
Future<ExerciseHistory> history(String exerciseId, {int limit = 20}); // sessions newest first
```

## WorkoutRepository

```dart
Stream<Workout?> watchActiveWorkout();
Future<Workout> startWorkout();                    // throws if an active workout exists
Future<WorkoutExercise> addExercise(String workoutId, String exerciseId); // appends position
Future<void> removeExercise(String workoutExerciseId); // [txn] queue pending delete, cascade,
                                                       // recalculate affected exercise if finished
Future<void> logSet(String workoutExerciseId, {required int setNo,
    required double weight, required int reps});  // upsert on (we_id, set_no); isOverload from plan;
                                                   // if workout finished → recalculate [txn]
Future<void> clearSet(String workoutExerciseId, int setNo); // delete + pending delete; recalc if finished
Future<void> setExerciseNotes(String workoutExerciseId, String? notes);

Future<FinishResult> finishWorkout(String workoutId);   // [txn] PRD §4.3 steps 1–5
// FinishResult: list of {exerciseName, fromBase, toBase, progressed, reason}
Future<void> discardWorkout(String workoutId);          // [txn] only when 0 sets logged
Future<bool> canResume(String workoutId);               // most recent finished && no active
Future<void> resumeWorkout(String workoutId);           // [txn] PRD §4.4 Resume
Future<void> deleteWorkout(String workoutId);           // [txn] PRD §4.4 Delete
Future<void> recalculate(String workoutExerciseId);     // [txn] re-evaluate vs snapshot (or current plan
                                                        // if no snapshot and latest), update
                                                        // result_base_weight, rewrite base if canRewriteBase

Stream<WorkoutDetail> watchWorkout(String workoutId);   // exercises, sets, plans, prescriptions
Future<PreviousSession?> previousSession(String exerciseId, {required String beforeWorkoutId});
Stream<List<WorkoutListItem>> watchHistory();           // finished, newest first; volume (per-hand ×2),
                                                        // exercise names, set count, duration
Stream<HomeStats> watchHomeStats(DateTime now);         // this week, streak, total, 3 recent
Stream<Map<String,int>> watchWorkoutsPerWeek(DateTime now);
```

### Behavioral guarantees (tested in `test/data/`)

1. Every `logSet` is committed before the future completes (no data loss on kill).
2. Re-logging a set number overwrites; no duplicate `(workout_exercise_id, set_no)`.
3. Exercises without a plan never progress and get no snapshot.
4. `finishWorkout` writes a snapshot for each planned exercise with ≥ 1 set, raises the base only if
   current base == snapshot base, and sets `ended_at`, atomically.
5. PRD §11 scenarios 1–8 produce the documented base weights.
6. Resume is refused when another workout is active or the workout is not the most recent finished.
7. Legacy finished workouts without snapshots are recalculated against the current plan only when
   they are the latest session.
8. Deleting a workout cascades to its exercises and sets and queues one `pending_deletes` row for it.

## SettingsRepository

```dart
Stream<int> watchDefaultRestSeconds();          // default 60
Future<void> setDefaultRestSeconds(int seconds); // clamp 10..600, snap to 5
Stream<RestAlertPrefs> watchAlertPrefs();        // haptic, sound (default true, true)
Future<void> setAlertPrefs(RestAlertPrefs prefs);
Future<ActiveRest?> readActiveRest();            // restore timer after process death
Future<void> writeActiveRest(ActiveRest? rest);  // null clears
```
