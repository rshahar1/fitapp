import 'dart:async';

import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/watch.dart';
import 'package:fitapp/domain/progression.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:uuid/uuid.dart';

/// All workout writes and queries (PRD §4.3, §4.4). Multi-row writes run in
/// one transaction.
class WorkoutRepository {
  new(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // Live workout
  // ---------------------------------------------------------------------------

  Future<WorkoutRow?> activeWorkout() =>
      (_db.select(_db.workouts)
            ..where((w) => w.endedAt.isNull())
            ..limit(1))
          .getSingleOrNull();

  Stream<WorkoutRow?> watchActiveWorkout() =>
      (_db.select(_db.workouts)
            ..where((w) => w.endedAt.isNull())
            ..limit(1))
          .watchSingleOrNull();

  Future<WorkoutRow> startWorkout() => _db.transaction(() async {
    if (await activeWorkout() != null) {
      throw StateError('A workout is already in progress');
    }
    final now = _db.now();
    final row = WorkoutsCompanion.insert(
      id: _uuid.v4(),
      startedAt: now,
      updatedAt: now,
    );
    return await _db.into(_db.workouts).insertReturning(row);
  });

  Future<WorkoutExerciseRow> addExercise(String workoutId, String exerciseId) =>
      _db.transaction(() async {
        final max = _db.workoutExercises.position.max();
        final q = _db.selectOnly(_db.workoutExercises)
          ..addColumns([max])
          ..where(_db.workoutExercises.workoutId.equals(workoutId));
        final current = await q.map((r) => r.read(max)).getSingle();
        final now = _db.now();
        await _touchWorkout(workoutId);
        return await _db
            .into(_db.workoutExercises)
            .insertReturning(
              WorkoutExercisesCompanion.insert(
                id: _uuid.v4(),
                workoutId: workoutId,
                exerciseId: exerciseId,
                position: (current ?? -1) + 1,
                updatedAt: now,
              ),
            );
      });

  /// Removes an exercise (and its sets) from a workout. For a finished
  /// workout, undoes that session's progression when safe.
  Future<void> removeExercise(String workoutExerciseId) =>
      _db.transaction(() async {
        final we = await _we(workoutExerciseId);
        final workout = await _workout(we.workoutId);
        if (workout.endedAt != null) await _undoProgression(we);
        final setIds =
            await (_db.select(_db.sets)
                  ..where((s) => s.workoutExerciseId.equals(workoutExerciseId)))
                .map((s) => s.id)
                .get();
        for (final id in setIds) {
          await _queueDelete('sets', id);
        }
        await _queueDelete('workout_exercises', workoutExerciseId);
        await (_db.delete(
          _db.workoutExercises,
        )..where((t) => t.id.equals(workoutExerciseId))).go();
        await _touchWorkout(we.workoutId);
      });

  Future<void> setExerciseNotes(String workoutExerciseId, String? notes) =>
      (_db.update(
        _db.workoutExercises,
      )..where((t) => t.id.equals(workoutExerciseId))).write(
        WorkoutExercisesCompanion(
          notes: Value(notes == null || notes.trim().isEmpty ? null : notes),
          updatedAt: Value(_db.now()),
          dirty: const Value(true),
        ),
      );

  /// Logs (or overwrites) set [setNo]. Re-evaluates a finished workout.
  Future<void> logSet(
    String workoutExerciseId, {
    required int setNo,
    required double weight,
    required int reps,
  }) => _db.transaction(() async {
    if (setNo < 1 || weight < 0 || reps < 0) {
      throw ArgumentError('Invalid set: #$setNo $weight x $reps');
    }
    final we = await _we(workoutExerciseId);
    final plan = await _effectivePlan(we);
    final now = _db.now();
    final w = roundWeight(weight);
    final existing =
        await (_db.select(_db.sets)..where(
              (s) =>
                  s.workoutExerciseId.equals(workoutExerciseId) &
                  s.setNo.equals(setNo),
            ))
            .getSingleOrNull();
    final isOverload = plan != null && plan.targetSets == setNo;
    if (existing == null) {
      await _db
          .into(_db.sets)
          .insert(
            SetsCompanion.insert(
              id: _uuid.v4(),
              workoutExerciseId: workoutExerciseId,
              setNo: setNo,
              weight: w,
              reps: reps,
              isOverload: isOverload,
              completedAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_db.update(
        _db.sets,
      )..where((s) => s.id.equals(existing.id))).write(
        SetsCompanion(
          weight: Value(w),
          reps: Value(reps),
          isOverload: Value(isOverload),
          completedAt: Value(now),
          updatedAt: Value(now),
          dirty: const Value(true),
        ),
      );
    }
    await _touchWorkout(we.workoutId);
    if ((await _workout(we.workoutId)).endedAt != null) {
      await _recalculate(we.id);
    }
  });

  /// Clears a logged set; it returns to "not logged".
  Future<void> clearSet(String workoutExerciseId, int setNo) => _db.transaction(
    () async {
      final we = await _we(workoutExerciseId);
      final existing =
          await (_db.select(_db.sets)..where(
                (s) =>
                    s.workoutExerciseId.equals(workoutExerciseId) &
                    s.setNo.equals(setNo),
              ))
              .getSingleOrNull();
      if (existing == null) return;
      await _queueDelete('sets', existing.id);
      await (_db.delete(_db.sets)..where((s) => s.id.equals(existing.id))).go();
      await _touchWorkout(we.workoutId);
      if ((await _workout(we.workoutId)).endedAt != null) {
        await _recalculate(we.id);
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Finish / discard / resume / delete
  // ---------------------------------------------------------------------------

  /// Finishes a workout (PRD §4.3). With no logged sets, the workout is
  /// discarded instead and [FinishResult.discarded] is true.
  Future<FinishResult> finishWorkout(String workoutId) =>
      _db.transaction(() async {
        final workout = await _workout(workoutId);
        if (workout.endedAt != null) {
          throw StateError('Workout is already finished');
        }
        final wes = await _wesOf(workoutId);
        final setsByWe = {for (final we in wes) we.id: await _setsOf(we.id)};
        if (setsByWe.values.every((s) => s.isEmpty)) {
          await _deleteWorkoutRows(workoutId);
          return const FinishResult(outcomes: [], discarded: true);
        }
        final outcomes = <FinishOutcome>[];
        for (final we in wes) {
          final sets = setsByWe[we.id]!;
          if (sets.isEmpty) continue;
          final current = await _currentPlan(we.exerciseId);
          final plan =
              snapshotOf(we) ?? (current == null ? null : planFromRow(current));
          if (plan == null) continue;
          final result = evaluate(plan, sets.map(loggedFromRow));
          await _writeSnapshot(we.id, plan, result.nextBaseWeight);
          var toBase = current?.baseWeight ?? plan.baseWeight;
          if (current != null &&
              result.progressed &&
              roundWeight(current.baseWeight) == plan.baseWeight) {
            await _setBase(we.exerciseId, result.nextBaseWeight);
            toBase = result.nextBaseWeight;
          }
          outcomes.add(
            FinishOutcome(
              exerciseName: (await _exercise(we.exerciseId)).name,
              fromBase: current?.baseWeight ?? plan.baseWeight,
              toBase: toBase,
              reason: result.reason,
            ),
          );
        }
        final now = _db.now();
        await (_db.update(
          _db.workouts,
        )..where((w) => w.id.equals(workoutId))).write(
          WorkoutsCompanion(
            endedAt: Value(now),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
        return FinishResult(outcomes: outcomes, discarded: false);
      });

  /// Discards an in-progress workout.
  Future<void> discardWorkout(String workoutId) => _db.transaction(() async {
    final workout = await _workout(workoutId);
    if (workout.endedAt != null) {
      throw StateError('Only an active workout can be discarded');
    }
    await _deleteWorkoutRows(workoutId);
  });

  /// Resume is allowed only for the most recent finished workout overall and
  /// only when no other workout is in progress.
  Future<bool> canResume(String workoutId) async {
    if (await activeWorkout() != null) return false;
    final latest = await _latestFinishedWorkout();
    return latest?.id == workoutId;
  }

  Future<void> resumeWorkout(String workoutId) => _db.transaction(() async {
    if (!await canResume(workoutId)) {
      throw StateError('This workout cannot be resumed');
    }
    for (final we in await _wesOf(workoutId)) {
      await _undoProgression(we);
      await (_db.update(
        _db.workoutExercises,
      )..where((t) => t.id.equals(we.id))).write(
        WorkoutExercisesCompanion(
          resultBaseWeight: const Value(null),
          updatedAt: Value(_db.now()),
          dirty: const Value(true),
        ),
      );
    }
    await (_db.update(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(
        endedAt: const Value(null),
        updatedAt: Value(_db.now()),
        dirty: const Value(true),
      ),
    );
  });

  /// Deletes a workout, undoing its progression where safe.
  Future<void> deleteWorkout(String workoutId) => _db.transaction(() async {
    final workout = await _workout(workoutId);
    if (workout.endedAt != null) {
      for (final we in await _wesOf(workoutId)) {
        await _undoProgression(we);
      }
    }
    await _deleteWorkoutRows(workoutId);
  });

  /// Re-evaluates one session of a finished workout (after an edit).
  Future<void> recalculate(String workoutExerciseId) =>
      _db.transaction(() => _recalculate(workoutExerciseId));

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  Stream<WorkoutDetail?> watchWorkout(String workoutId) =>
      watchQuery(_db, () => workoutDetail(workoutId));

  Future<WorkoutDetail?> workoutDetail(String workoutId) async {
    final workout = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingleOrNull();
    if (workout == null) return null;
    final details = <WorkoutExerciseDetail>[];
    for (final we in await _wesOf(workoutId)) {
      final exercise = await _exercise(we.exerciseId);
      final plan = await _currentPlan(we.exerciseId);
      final prev = await previousSession(we.exerciseId, before: workout);
      details.add(
        WorkoutExerciseDetail(
          row: we,
          exercise: exercise,
          currentPlan: plan,
          sets: await _setsOf(we.id),
          previous: prev,
          restSeconds: plan?.restSeconds,
        ),
      );
    }
    return WorkoutDetail(workout: workout, exercises: details);
  }

  /// Sets of the most recent finished session of [exerciseId] that started
  /// before [before], or null if there is none.
  Future<List<SetRow>?> previousSession(
    String exerciseId, {
    required WorkoutRow before,
  }) async {
    final w = _db.workouts;
    final we = _db.workoutExercises;
    final q = _db.select(we).join([innerJoin(w, w.id.equalsExp(we.workoutId))])
      ..where(
        we.exerciseId.equals(exerciseId) &
            w.endedAt.isNotNull() &
            w.id.equals(before.id).not() &
            w.startedAt.isSmallerThanValue(before.startedAt),
      )
      ..orderBy([OrderingTerm.desc(w.startedAt), OrderingTerm.desc(w.id)]);
    for (final row in await q.get()) {
      final sets = await _setsOf(row.readTable(we).id);
      if (sets.isNotEmpty) return sets;
    }
    return null;
  }

  Stream<List<WorkoutListItem>> watchHistory() => watchQuery(_db, history);

  /// Finished workouts, newest first.
  Future<List<WorkoutListItem>> history({int? limit}) async {
    final q = _db.select(_db.workouts)
      ..where((w) => w.endedAt.isNotNull())
      ..orderBy([
        (w) => OrderingTerm.desc(w.startedAt),
        (w) => OrderingTerm.desc(w.id),
      ]);
    if (limit != null) q.limit(limit);
    final items = <WorkoutListItem>[];
    for (final w in await q.get()) {
      final names = <String>[];
      var vol = 0.0;
      var count = 0;
      for (final we in await _wesOf(w.id)) {
        final ex = await _exercise(we.exerciseId);
        final sets = await _setsOf(we.id);
        names.add(ex.name);
        count += sets.length;
        vol += volume(sets.map(loggedFromRow), perHand: ex.isPerHand);
      }
      items.add(
        WorkoutListItem(
          id: w.id,
          startedAt: w.startedAt,
          endedAt: w.endedAt,
          exerciseNames: names,
          volume: vol,
          setCount: count,
        ),
      );
    }
    return items;
  }

  Stream<HomeStats> watchHomeStats(DateTime Function() now) =>
      watchQuery(_db, () => homeStats(now()));

  Future<HomeStats> homeStats(DateTime now) async {
    final dates = await _finishedStartDates();
    final thisWeek = isoWeekKey(now);
    return HomeStats(
      thisWeek: dates.where((d) => isoWeekKey(d) == thisWeek).length,
      streak: weeklyStreak(dates, now: now),
      total: dates.length,
      recent: await history(limit: 3),
    );
  }

  Stream<Map<String, int>> watchWorkoutsPerWeek(DateTime Function() now) =>
      watchQuery(
        _db,
        () async => workoutsPerWeek(await _finishedStartDates(), now: now()),
      );

  Future<List<DateTime>> _finishedStartDates() async {
    final rows = await (_db.select(
      _db.workouts,
    )..where((w) => w.endedAt.isNotNull())).get();
    return [for (final r in rows) r.startedAt.toLocal()];
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _recalculate(String workoutExerciseId) async {
    final we = await _we(workoutExerciseId);
    final workout = await _workout(we.workoutId);
    if (workout.endedAt == null) return; // live workouts evaluate on finish
    final current = await _currentPlan(we.exerciseId);
    final isLatest = await _isLatestSession(we.exerciseId, we.workoutId);
    final snapshot = snapshotOf(we);
    final Plan plan;
    final double? oldResult;
    if (snapshot != null) {
      plan = snapshot;
      oldResult = we.resultBaseWeight;
    } else {
      // Legacy session without a snapshot: use the current plan, only if this
      // is the latest session. Its result is assumed to be the current base.
      if (current == null || !isLatest) return;
      plan = planFromRow(current);
      oldResult = current.baseWeight;
    }
    final sets = await _setsOf(we.id);
    final result = evaluate(plan, sets.map(loggedFromRow));
    final rewrite =
        current != null &&
        canRewriteBase(
          isLatestSessionForExercise: isLatest,
          currentBase: current.baseWeight,
          resultBaseWeight: oldResult,
        );
    await _writeSnapshot(we.id, plan, result.nextBaseWeight);
    if (rewrite) await _setBase(we.exerciseId, result.nextBaseWeight);
  }

  /// Restores the snapshot base if this session's progression is still the
  /// current base and this is the latest session.
  Future<void> _undoProgression(WorkoutExerciseRow we) async {
    final snapshot = snapshotOf(we);
    if (snapshot == null) return;
    final current = await _currentPlan(we.exerciseId);
    if (current == null) return;
    final isLatest = await _isLatestSession(we.exerciseId, we.workoutId);
    if (canRewriteBase(
      isLatestSessionForExercise: isLatest,
      currentBase: current.baseWeight,
      resultBaseWeight: we.resultBaseWeight,
    )) {
      await _setBase(we.exerciseId, snapshot.baseWeight);
    }
  }

  /// Whether [workoutId] is the latest finished workout containing
  /// [exerciseId] (by start time, then id).
  Future<bool> _isLatestSession(String exerciseId, String workoutId) async {
    final w = _db.workouts;
    final we = _db.workoutExercises;
    final q = _db.select(w).join([innerJoin(we, we.workoutId.equalsExp(w.id))])
      ..where(we.exerciseId.equals(exerciseId) & w.endedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(w.startedAt), OrderingTerm.desc(w.id)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.readTable(w).id == workoutId;
  }

  Future<WorkoutRow?> _latestFinishedWorkout() =>
      (_db.select(_db.workouts)
            ..where((w) => w.endedAt.isNotNull())
            ..orderBy([
              (w) => OrderingTerm.desc(w.startedAt),
              (w) => OrderingTerm.desc(w.id),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<void> _writeSnapshot(String weId, Plan plan, double result) =>
      (_db.update(_db.workoutExercises)..where((t) => t.id.equals(weId))).write(
        WorkoutExercisesCompanion(
          planBaseWeight: Value(plan.baseWeight),
          planTargetReps: Value(plan.targetReps),
          planTargetSets: Value(plan.targetSets),
          planIncrement: Value(plan.increment),
          resultBaseWeight: Value(roundWeight(result)),
          updatedAt: Value(_db.now()),
          dirty: const Value(true),
        ),
      );

  Future<void> _setBase(String exerciseId, double base) =>
      (_db.update(
        _db.exerciseState,
      )..where((p) => p.exerciseId.equals(exerciseId))).write(
        ExerciseStateCompanion(
          baseWeight: Value(roundWeight(base)),
          updatedAt: Value(_db.now()),
          dirty: const Value(true),
        ),
      );

  Future<void> _deleteWorkoutRows(String workoutId) async {
    await _queueDelete('workouts', workoutId);
    await (_db.delete(_db.workouts)..where((w) => w.id.equals(workoutId))).go();
  }

  Future<void> _queueDelete(String table, String id) => _db
      .into(_db.pendingDeletes)
      .insert(
        PendingDeletesCompanion.insert(tableNameValue: table, rowId: id),
        mode: InsertMode.insertOrIgnore,
      );

  Future<void> _touchWorkout(String workoutId) =>
      (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
        WorkoutsCompanion(
          updatedAt: Value(_db.now()),
          dirty: const Value(true),
        ),
      );

  Future<Plan?> _effectivePlan(WorkoutExerciseRow we) async {
    final snapshot = snapshotOf(we);
    if (snapshot != null) return snapshot;
    final current = await _currentPlan(we.exerciseId);
    return current == null ? null : planFromRow(current);
  }

  Future<WorkoutRow> _workout(String id) =>
      (_db.select(_db.workouts)..where((w) => w.id.equals(id))).getSingle();

  Future<WorkoutExerciseRow> _we(String id) => (_db.select(
    _db.workoutExercises,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<ExerciseRow> _exercise(String id) =>
      (_db.select(_db.exercises)..where((e) => e.id.equals(id))).getSingle();

  Future<PlanRow?> _currentPlan(String exerciseId) => (_db.select(
    _db.exerciseState,
  )..where((p) => p.exerciseId.equals(exerciseId))).getSingleOrNull();

  Future<List<WorkoutExerciseRow>> _wesOf(String workoutId) =>
      (_db.select(_db.workoutExercises)
            ..where((t) => t.workoutId.equals(workoutId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Future<List<SetRow>> _setsOf(String weId) =>
      (_db.select(_db.sets)
            ..where((s) => s.workoutExerciseId.equals(weId))
            ..orderBy([(s) => OrderingTerm.asc(s.setNo)]))
          .get();
}
