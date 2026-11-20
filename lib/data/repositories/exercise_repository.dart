import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/db/seed_library.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/plan_store.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/watch.dart';
import 'package:fitapp/domain/progression.dart';
import 'package:fitapp/domain/stats.dart' show displayWeight;
import 'package:uuid/uuid.dart';

/// Thrown when a custom exercise name already exists (case-insensitive).
class DuplicateExerciseName implements Exception {
  const new(this.name);

  final String name;

  @override
  String toString() => 'An exercise named "$name" already exists';
}

/// A template that contains an exercise about to be deleted.
class TemplateUsage {
  const new({required this.id, required this.name, required this.wouldBeEmpty});

  final String id;
  final String name;

  /// The exercise is the template's only one: deleting it deletes the
  /// template too.
  final bool wouldBeEmpty;
}

/// Exercise library and plans.
class ExerciseRepository {
  new(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// All active (not deleted) exercises, optionally filtered by a
  /// case-insensitive [query], ordered by name.
  Stream<List<ExerciseRow>> watchExercises({String? query}) {
    final q = _db.select(_db.exercises)
      ..where((e) => e.deletedAt.isNull())
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
  /// [muscleGroup] must be one of [muscleGroups]; null means "Custom".
  /// A deleted exercise with the same name is restored instead (feature
  /// 012); a custom one takes the given settings, a built-in keeps its own.
  Future<ExerciseRow> createCustom({
    required String name,
    required bool perHand,
    required double increment,
    String? muscleGroup,
  }) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name must not be empty');
    if (!(increment > 0)) throw ArgumentError('Increment must be > 0');
    _checkMuscleGroup(muscleGroup);
    final existing =
        await (_db.select(_db.exercises)
              ..where((e) => e.name.lower().equals(trimmed.toLowerCase())))
            .getSingleOrNull();
    if (existing != null && existing.deletedAt == null) {
      throw DuplicateExerciseName(existing.name);
    }
    if (existing != null) {
      await (_db.update(
        _db.exercises,
      )..where((e) => e.id.equals(existing.id))).write(
        ExercisesCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(_db.now()),
          dirty: const Value(true),
          name: existing.isCustom ? Value(trimmed) : const Value.absent(),
          muscleGroup: existing.isCustom
              ? Value(muscleGroup)
              : const Value.absent(),
          isPerHand: existing.isCustom ? Value(perHand) : const Value.absent(),
          defaultIncrement: existing.isCustom
              ? Value(roundWeight(increment))
              : const Value.absent(),
        ),
      );
      return (await exercise(existing.id))!;
    }
    return await _db
        .into(_db.exercises)
        .insertReturning(
          ExercisesCompanion.insert(
            id: _uuid.v4(),
            name: trimmed,
            muscleGroup: Value(muscleGroup),
            isPerHand: perHand,
            defaultIncrement: roundWeight(increment),
            isCustom: true,
            updatedAt: _db.now(),
          ),
        );
  });

  static void _checkMuscleGroup(String? muscleGroup) {
    if (muscleGroup != null && !muscleGroups.contains(muscleGroup)) {
      throw ArgumentError.value(muscleGroup, 'muscleGroup', 'Unknown category');
    }
  }

  /// Edits a custom exercise (built-in exercises are read-only). Names stay
  /// unique, case-insensitive; renaming to another casing of its own name is
  /// allowed. Throws [StateError] if [id] is unknown or not custom.
  Future<ExerciseRow> updateCustom(
    String id, {
    required String name,
    required String? muscleGroup,
    required bool perHand,
    required double increment,
  }) => _db.transaction(() async {
    final current = await exercise(id);
    if (current == null || current.deletedAt != null) {
      throw StateError('Exercise not found: $id');
    }
    if (!current.isCustom) {
      throw StateError('Built-in exercises cannot be edited');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name must not be empty');
    if (!(increment > 0)) throw ArgumentError('Increment must be > 0');
    _checkMuscleGroup(muscleGroup);
    final clash =
        await (_db.select(_db.exercises)..where(
              (e) =>
                  e.name.lower().equals(trimmed.toLowerCase()) &
                  e.id.equals(id).not(),
            ))
            .getSingleOrNull();
    if (clash != null) throw DuplicateExerciseName(clash.name);
    await (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        name: Value(trimmed),
        muscleGroup: Value(muscleGroup),
        isPerHand: Value(perHand),
        defaultIncrement: Value(roundWeight(increment)),
        updatedAt: Value(_db.now()),
        dirty: const Value(true),
      ),
    );
    return (await exercise(id))!;
  });

  /// Templates containing [id], by name, for the delete confirmation.
  Future<List<TemplateUsage>> templatesUsing(String id) async {
    final te = _db.templateExercises;
    final t = _db.templates;
    final rows =
        await (_db.select(t).join([
                innerJoin(te, te.templateId.equalsExp(t.id)),
              ])
              ..where(te.exerciseId.equals(id))
              ..orderBy([OrderingTerm.asc(t.name.lower())]))
            .get();
    final result = <TemplateUsage>[];
    for (final r in rows) {
      final template = r.readTable(t);
      final count = await (_db.select(
        te,
      )..where((x) => x.templateId.equals(template.id))).get();
      result.add(
        TemplateUsage(
          id: template.id,
          name: template.name,
          wouldBeEmpty: count.length == 1,
        ),
      );
    }
    return result;
  }

  /// Soft-deletes exercise [id], custom or built-in (feature 012): hidden
  /// from the library, picker and Progress; finished workouts, sets and its
  /// plan are kept. It is removed from every template, and templates left
  /// without exercises are deleted. Throws [StateError] if [id] is unknown.
  Future<void> delete(String id) => _db.transaction(() async {
    final current = await exercise(id);
    if (current == null) throw StateError('Exercise not found: $id');
    if (current.deletedAt != null) return;
    await TemplateRepository(_db).removeExercise(id);
    final now = _db.now();
    await (_db.update(_db.exercises)..where((e) => e.id.equals(id))).write(
      ExercisesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
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

  /// Active exercises with at least one finished session, most recent first.
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
      ..where(w.endedAt.isNotNull() & e.deletedAt.isNull())
      ..groupBy([we.exerciseId]);
    final rows = await q.get();
    final result = <TrainedExercise>[];
    for (final r in rows) {
      final id = r.read(we.exerciseId)!;
      result.add(
        TrainedExercise(
          exercise: (await exercise(id))!,
          plan: await plan(id),
          currentWeight: await currentWeight(id),
          lastTrained: r.read(last)!,
        ),
      );
    }
    result.sort((a, b) => b.lastTrained.compareTo(a.lastTrained));
    return result;
  }

  Stream<double?> watchCurrentWeight(String exerciseId) =>
      watchQuery(_db, () => currentWeight(exerciseId));

  /// Weight shown for [exerciseId] on Progress (feature 028): the base of the
  /// plan its latest finished session with sets used (the template exercise
  /// plan for a template session, else the exercise's own plan), else that
  /// session's working weight. Null when it has no such session.
  Future<double?> currentWeight(String exerciseId) async {
    final ex = await exercise(exerciseId);
    if (ex == null) return null;
    final w = _db.workouts;
    final we = _db.workoutExercises;
    final q = _db.select(we).join([innerJoin(w, w.id.equalsExp(we.workoutId))])
      ..where(we.exerciseId.equals(exerciseId) & w.endedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(w.startedAt), OrderingTerm.desc(w.id)]);
    for (final row in await q.get()) {
      final session = row.readTable(we);
      final sets = await (_db.select(
        _db.sets,
      )..where((s) => s.workoutExerciseId.equals(session.id))).get();
      if (sets.isEmpty) continue;
      final teId = session.templateExerciseId;
      final StoredPlan? plan;
      if (teId == null) {
        plan = await _db.exercisePlan(exerciseId);
      } else {
        final te = await _db.templateExercise(teId);
        plan = te == null ? null : StoredPlan.ofTemplate(te);
      }
      final summary = ExerciseSession(
        workoutId: session.workoutId,
        date: row.readTable(w).startedAt,
        sets: sets,
        perHand: ex.isPerHand,
      ).summary;
      return displayWeight(
        planBase: plan?.baseWeight,
        workingWeight: summary.workingWeight,
        topWeight: summary.topWeight,
      );
    }
    return null;
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
