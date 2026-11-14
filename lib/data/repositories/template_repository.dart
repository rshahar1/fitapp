import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/live_session_store.dart';
import 'package:fitapp/data/repositories/plan_store.dart';
import 'package:fitapp/data/watch.dart';
import 'package:uuid/uuid.dart';

/// Thrown when another template already uses the name (ignoring case).
class DuplicateTemplateName implements Exception {
  const new(this.name);

  final String name;

  @override
  String toString() => 'A template named "$name" already exists';
}

/// User-created workout templates (specs/003-workout-templates).
class TemplateRepository {
  new(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();
  static const maxNameLength = 40;

  Stream<List<TemplateSummary>> watchTemplates() => watchQuery(_db, list);

  /// All templates: most recently used first, then newest.
  Future<List<TemplateSummary>> list() async {
    final rows =
        await (_db.select(_db.templates)..orderBy([
              (t) => OrderingTerm(
                expression: t.lastUsedAt,
                mode: OrderingMode.desc,
                nulls: NullsOrder.last,
              ),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
            .get();
    return [for (final r in rows) await _summary(r)];
  }

  Future<TemplateSummary?> template(String id) async {
    final row = await (_db.select(
      _db.templates,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : await _summary(row);
  }

  /// Creates a template. Each exercise's template plan is `plans[id]` when
  /// given, otherwise a copy of the exercise's own plan (or none).
  Future<String> create({
    required String name,
    required List<String> exerciseIds,
    Map<String, StoredPlan> plans = const {},
  }) => _db.transaction(() async {
    final clean = await _validate(name, exerciseIds);
    final now = _db.now();
    final id = _uuid.v4();
    await _db
        .into(_db.templates)
        .insert(
          TemplatesCompanion.insert(
            id: id,
            name: clean,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _writeExercises(id, _distinct(exerciseIds), plans);
    return id;
  });

  /// Saves name and the complete ordered exercise list in one transaction.
  /// New exercises get `plans[id]` or a copy of the exercise's own plan; kept
  /// exercises change plan only when [plans] has an entry for them.
  Future<void> update(
    String id, {
    required String name,
    required List<String> exerciseIds,
    Map<String, StoredPlan> plans = const {},
  }) => _db.transaction(() async {
    final clean = await _validate(name, exerciseIds, excludeId: id);
    await (_db.update(_db.templates)..where((t) => t.id.equals(id))).write(
      TemplatesCompanion(
        name: Value(clean),
        updatedAt: Value(_db.now()),
        dirty: const Value(true),
      ),
    );
    await _writeExercises(id, _distinct(exerciseIds), plans);
  });

  Future<void> delete(String id) => _db.transaction(() async {
    final teIds = await (_db.select(
      _db.templateExercises,
    )..where((t) => t.templateId.equals(id))).map((r) => r.id).get();
    await _unlinkLiveSessions(teIds);
    await _queueDelete('templates', id);
    await (_db.delete(_db.templates)..where((t) => t.id.equals(id))).go();
  });

  /// Creates a template from a workout's exercises (in workout order). Each
  /// plan is seeded from the plan that session currently uses.
  Future<String> saveFromWorkout(String workoutId, {required String name}) =>
      _db.transaction(() async {
        final rows =
            await (_db.select(_db.workoutExercises)
                  ..where((t) => t.workoutId.equals(workoutId))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();
        final plans = <String, StoredPlan>{};
        for (final r in rows) {
          final teId = r.templateExerciseId;
          final te = teId == null ? null : await _db.templateExercise(teId);
          final plan = te != null
              ? StoredPlan.ofTemplate(te)
              : await _db.exercisePlan(r.exerciseId);
          if (plan != null) plans.putIfAbsent(r.exerciseId, () => plan);
        }
        return await create(
          name: name,
          exerciseIds: [for (final r in rows) r.exerciseId],
          plans: plans,
        );
      });

  /// Starts a live workout with the template's exercises, all or nothing.
  Future<String> startWorkout(String templateId) => _db.transaction(() async {
    final active = await (_db.select(
      _db.workouts,
    )..where((w) => w.endedAt.isNull())).get();
    if (active.isNotEmpty) {
      throw StateError('A workout is already in progress');
    }
    if (await template(templateId) == null) {
      throw StateError('Template not found');
    }
    final te = _db.templateExercises;
    final items =
        await (_db.select(te)
              ..where((t) => t.templateId.equals(templateId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    final now = _db.now();
    final workoutId = _uuid.v4();
    await _db
        .into(_db.workouts)
        .insert(
          WorkoutsCompanion.insert(
            id: workoutId,
            startedAt: now,
            updatedAt: now,
          ),
        );
    await _db.writeLiveSession(
      LiveSession(workoutId: workoutId, liveSince: now),
    );
    for (final (i, item) in items.indexed) {
      await _db
          .into(_db.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              id: _uuid.v4(),
              workoutId: workoutId,
              exerciseId: item.exerciseId,
              position: i,
              updatedAt: now,
              templateExerciseId: Value(item.id),
            ),
          );
    }
    await (_db.update(
      _db.templates,
    )..where((t) => t.id.equals(templateId))).write(
      TemplatesCompanion(
        lastUsedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    return workoutId;
  });

  // ---------------------------------------------------------------------------

  Future<TemplateSummary> _summary(TemplateRow row) async {
    final te = _db.templateExercises;
    final e = _db.exercises;
    final q = _db.select(te).join([innerJoin(e, e.id.equalsExp(te.exerciseId))])
      ..where(te.templateId.equals(row.id))
      ..orderBy([OrderingTerm.asc(te.position)]);
    final rows = await q.get();
    return TemplateSummary(
      id: row.id,
      name: row.name,
      exercises: [for (final r in rows) r.readTable(e)],
      plans: {
        for (final r in rows)
          r.readTable(te).exerciseId: StoredPlan.ofTemplate(r.readTable(te)),
      },
      createdAt: row.createdAt,
      lastUsedAt: row.lastUsedAt,
    );
  }

  Future<String> _validate(
    String name,
    List<String> exerciseIds, {
    String? excludeId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Name is required');
    if (clean.length > maxNameLength) {
      throw ArgumentError('Name is too long (max $maxNameLength)');
    }
    if (exerciseIds.isEmpty) throw ArgumentError('Add at least one exercise');
    final clash =
        await (_db.select(_db.templates)..where(
              (t) =>
                  t.name.lower().equals(clean.toLowerCase()) &
                  (excludeId == null
                      ? const Constant(true)
                      : t.id.equals(excludeId).not()),
            ))
            .getSingleOrNull();
    if (clash != null) throw DuplicateTemplateName(clash.name);
    return clean;
  }

  static List<String> _distinct(List<String> ids) => ids.toSet().toList();

  /// Diffs the template's rows against [ids]: deletes removed rows (queued
  /// for sync), re-positions kept rows, inserts new ones.
  Future<void> _writeExercises(
    String templateId,
    List<String> ids,
    Map<String, StoredPlan> plans,
  ) async {
    final existing = await (_db.select(
      _db.templateExercises,
    )..where((t) => t.templateId.equals(templateId))).get();
    final byExercise = {for (final r in existing) r.exerciseId: r};
    final now = _db.now();
    await _unlinkLiveSessions([
      for (final r in existing)
        if (!ids.contains(r.exerciseId)) r.id,
    ]);
    for (final r in existing) {
      if (!ids.contains(r.exerciseId)) {
        await _queueDelete('template_exercises', r.id);
        await (_db.delete(
          _db.templateExercises,
        )..where((t) => t.id.equals(r.id))).go();
      }
    }
    for (final (i, exerciseId) in ids.indexed) {
      final row = byExercise[exerciseId];
      if (row == null) {
        final given = plans[exerciseId];
        final plan = given == null
            ? await _db.exercisePlan(exerciseId)
            : _db.validatedPlan(given);
        final id = _uuid.v4();
        await _db
            .into(_db.templateExercises)
            .insert(
              TemplateExercisesCompanion.insert(
                id: id,
                templateId: templateId,
                exerciseId: exerciseId,
                position: i,
                updatedAt: now,
              ),
            );
        if (plan != null) await _db.writeTemplatePlan(id, plan);
        continue;
      }
      final given = plans[exerciseId];
      if (given != null &&
          _db.validatedPlan(given) != StoredPlan.ofTemplate(row)) {
        await _db.writeTemplatePlan(row.id, given);
      }
      if (row.position != i) {
        await (_db.update(
          _db.templateExercises,
        )..where((t) => t.id.equals(row.id))).write(
          TemplateExercisesCompanion(
            position: Value(i),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
      }
    }
  }

  /// Template exercises [teIds] are going away: sessions of unfinished
  /// workouts that still have no snapshot fall back to the exercise's own
  /// plan. Everything else keeps the (then dangling) link and never rewrites
  /// a plan (research R3).
  Future<void> _unlinkLiveSessions(List<String> teIds) async {
    if (teIds.isEmpty) return;
    final we = _db.workoutExercises;
    final live = _db.selectOnly(_db.workouts)
      ..addColumns([_db.workouts.id])
      ..where(_db.workouts.endedAt.isNull());
    await (_db.update(we)..where(
          (t) =>
              t.templateExerciseId.isIn(teIds) &
              t.planBaseWeight.isNull() &
              t.workoutId.isInQuery(live),
        ))
        .write(
          WorkoutExercisesCompanion(
            templateExerciseId: const Value(null),
            updatedAt: Value(_db.now()),
            dirty: const Value(true),
          ),
        );
  }

  Future<void> _queueDelete(String table, String id) => _db
      .into(_db.pendingDeletes)
      .insert(
        PendingDeletesCompanion.insert(tableNameValue: table, rowId: id),
        mode: InsertMode.insertOrIgnore,
      );
}
