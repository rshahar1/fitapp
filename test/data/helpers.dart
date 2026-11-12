import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';

/// Incline Dumbbell Bench Press (per hand, +2.5).
const inclineId = '00000000-0000-4000-8000-000000000002';

/// Lat Pulldown (not per hand).
const latId = '00000000-0000-4000-8000-000000000009';

/// A test harness with an in-memory database and a controllable clock.
class Harness {
  new() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory()),
      clock: () => now,
    );
    workouts = WorkoutRepository(db);
    exercises = ExerciseRepository(db);
    settings = SettingsRepository(db);
  }

  DateTime now = DateTime.utc(2026, 11, 2, 18);
  late final AppDatabase db;
  late final WorkoutRepository workouts;
  late final ExerciseRepository exercises;
  late final SettingsRepository settings;

  Future<void> close() => db.close();

  void advance([Duration d = const Duration(days: 1)]) => now = now.add(d);

  Future<void> plan({
    String exerciseId = inclineId,
    double base = 20,
    int reps = 10,
    int sets = 3,
    double inc = 2.5,
  }) => exercises.savePlan(
    exerciseId,
    baseWeight: base,
    targetReps: reps,
    targetSets: sets,
    increment: inc,
  );

  Future<double> base([String exerciseId = inclineId]) async =>
      (await exercises.plan(exerciseId))!.baseWeight;

  /// Starts a workout, adds [exerciseId], logs [sets] as (weight, reps) for set
  /// numbers 1.., and finishes unless [finish] is false. Advances the clock a
  /// day first. Returns (workoutId, workoutExerciseId).
  Future<(String, String)> session(
    List<(double, int)> sets, {
    String exerciseId = inclineId,
    bool finish = true,
  }) async {
    advance();
    final w = await workouts.startWorkout();
    final we = await workouts.addExercise(w.id, exerciseId);
    for (var i = 0; i < sets.length; i++) {
      advance(const Duration(minutes: 3));
      await workouts.logSet(
        we.id,
        setNo: i + 1,
        weight: sets[i].$1,
        reps: sets[i].$2,
      );
    }
    if (finish) {
      advance(const Duration(minutes: 3));
      await workouts.finishWorkout(w.id);
    }
    return (w.id, we.id);
  }
}
