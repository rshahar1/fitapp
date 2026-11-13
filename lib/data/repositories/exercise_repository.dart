import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/plan_store.dart';
import 'package:fitapp/data/watch.dart';
import 'package:fitapp/domain/progression.dart';
import 'package:uuid/uuid.dart';

/// Thrown when a custom exercise name already exists (case-insensitive).
class DuplicateExerciseName implements Exception {
  const new(this.name);

  final String name;

  @override
  String toString() => 'An exercise named "$name" already exists';
}

/// Exercise library and plans.
class ExerciseRepository {
  new(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// All exercises (optionally filtered by a case-insensitive [query]),
  /// ordered by name.
  Stream<List<ExerciseRow>> watchExercises({String? query}) {
    final q = _db.select(_db.exercises)
      ..orderBy([(e) => OrderingTerm.asc(e.name.lower())]);
    final text = query?.trim().toLowerCase() ?? '';
    if (text.isNotEmpty) q.where((e) => e.name.lower().contains(text));
    return q.watch();
  }

  Future<ExerciseRow?> exercise(String id) => (_db.select(
    _db.exercises,
  )..where((e) => e.id.equals(id))).getSingleOrNull();

  Stream<ExerciseRow?> watchExercise(String id) => (_db.select(
    _db.exercises,
  )..where((e) => e.id.equals(id))).watchSingleOrNull();

  /// Creates a custom exercise. Names are unique, case-insensitive.
  Future<ExerciseRow> createCustom({
    required String name,
    required bool perHand,
    required double increment,
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name must not be empty');
    if (!(increment > 0)) throw ArgumentError('Increment must be > 0');
    final existing =
        await (_db.select(_db.exercises)
              ..where((e) => e.name.lower().equals(trimmed.toLowerCase())))
            .getSingleOrNull();
    if (existing != null) throw DuplicateExerciseName(existing.name);
    return await _db
        .into(_db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            id: _uuid.v4(),
            name: trimmed,
            isPerHand: perHand,
            defaultIncrement: roundWeight(increment),
            isCustom: true,
            updatedAt: _db.now(),
          ),
        );
  });

  Future<PlanRow?> plan(String exerciseId) => (_db.select(
    _db.exerciseState,
  )..where((p) => p.exerciseId.equals(exerciseId))).getSingleOrNull();

  Stream<PlanRow?> watchPlan(String exerciseId) => (_db.select(
    _db.exerciseState,
  )..where((p) => p.exerciseId.equals(exerciseId))).watchSingleOrNull();

  /// Creates or replaces the plan. Validates via the domain [Plan].
  /// [restSeconds] null means "use the default rest time".
  Future<void> savePlan(
    String exerciseId, {
    required double baseWeight,
    required int targetReps,
    required int targetSets,
    required double increment,
    int? restSeconds,
  }) => _db.writeExercisePlan(
    exerciseId,
    StoredPlan(
      baseWeight: baseWeight,
      targetReps: targetReps,
      targetSets: targetSets,
      increment: increment,
      restSeconds: restSeconds,
    ),
  );

  /// Creates or replaces the plan from a [StoredPlan].
  Future<void> writePlan(String exerciseId, StoredPlan plan) =>
      _db.writeExercisePlan(exerciseId, plan);

  Stream<List<TrainedExercise>> watchTrainedExercises() =>
      watchQuery(_db, trainedExercises);

  /// Exercises with at least one finished session, most recent first.
  Future<List<TrainedExercise>> trainedExercises() async {
    final w = _db.workouts;
    final we = _db.workoutExercises;
    final e = _db.exercises;
    final last = w.startedAt.max();
    final q = _db.selectOnly(we)
      ..addColumns([we.exerciseId, last])
      ..join([
        innerJoin(w, w.id.equalsExp(we.workoutId)),
        innerJoin(e, e.id.equalsExp(we.exerciseId)),
      ])
      ..where(w.endedAt.isNotNull())
      ..groupBy([we.exerciseId]);
    final rows = await q.get();
    final result = <TrainedExercise>[];
    for (final r in rows) {
      final id = r.read(we.exerciseId)!;
      result.add(
        TrainedExercise(
          exercise: (await exercise(id))!,
          plan: await plan(id),
          lastTrained: r.read(last)!,
        ),
      );
    }
    result.sort((a, b) => b.lastTrained.compareTo(a.lastTrained));
    return result;
  }

  Stream<List<ExerciseSession>> watchHistory(String exerciseId, {int? limit}) =>
      watchQuery(_db, () => history(exerciseId, limit: limit));

  /// Finished sessions of [exerciseId] with at least one set, newest first.
  Future<List<ExerciseSession>> history(String exerciseId, {int? limit}) async {
    final ex = await exercise(exerciseId);
    if (ex == null) return const [];
    final w = _db.workouts;
    final we = _db.workoutExercises;
    final q = _db.select(we).join([innerJoin(w, w.id.equalsExp(we.workoutId))])
      ..where(we.exerciseId.equals(exerciseId) & w.endedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(w.startedAt), OrderingTerm.desc(w.id)]);
    final sessions = <ExerciseSession>[];
    for (final row in await q.get()) {
      final sets =
          await (_db.select(_db.sets)
                ..where((s) => s.workoutExerciseId.equals(row.readTable(we).id))
                ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
              .get();
      if (sets.isEmpty) continue;
      final workout = row.readTable(w);
      sessions.add(
        ExerciseSession(
          workoutId: workout.id,
          date: workout.startedAt,
          sets: sets,
          perHand: ex.isPerHand,
        ),
      );
      if (limit != null && sessions.length >= limit) break;
    }
    return sessions;
  }
}
