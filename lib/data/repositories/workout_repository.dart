import 'dart:async';

import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/live_session_store.dart';
import 'package:fitapp/data/repositories/plan_store.dart';
import 'package:fitapp/data/watch.dart';
import 'package:fitapp/domain/progression.dart';
import 'package:fitapp/domain/stats.dart';
import 'package:fitapp/domain/training_breakdown.dart';
import 'package:fitapp/domain/workout_dates.dart';
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

  Future<bool> _trackingActive() async =>
      (await _db.select(_db.trackingSessions).get()).isNotEmpty;

  Future<WorkoutRow> startWorkout() => _db.transaction(() async {
    if (await activeWorkout() != null) {
      throw StateError('A workout is already in progress');
    }
    if (await _trackingActive()) {
      throw StateError('A tracking session is in progress');
    }
    final now = _db.now();
    final row = WorkoutsCompanion.insert(
      id: _uuid.v4(),
      startedAt: now,
      updatedAt: now,
    );
    final created = await _db.into(_db.workouts).insertReturning(row);
    await _db.writeLiveSession(
      LiveSession(workoutId: created.id, liveSince: now),
    );
    return created;
  });

  /// The live-session record (feature 007): elapsed time of a resumed
  /// workout and the day chosen for the live workout.
  Stream<LiveSession?> watchLiveSession() => _db.watchLiveSession();

  /// Sets the day the live workout is stored on when it is finished; the
  /// local day of its start (normally today) clears the choice. Throws
  /// [ArgumentError] for a future day, [StateError] for a finished workout.
  Future<void> setLiveWorkoutDay(String workoutId, DateTime day) =>
      _db.transaction(() async {
        final workout = await _workout(workoutId);
        if (workout.endedAt != null) {
          throw StateError('Use setWorkoutDay for a finished workout');
        }
        checkWorkoutDay(day, _db.now());
        final current = await _db.readLiveSession();
        final session = current != null && current.workoutId == workoutId
            ? current
            // Workout started before feature 007: live since its start.
            : LiveSession(workoutId: workoutId, liveSince: workout.startedAt);
        final today = shiftToDay(workout.startedAt, day) == workout.startedAt;
        await _db.writeLiveSession(session.withDay(today ? null : day));
      });

  /// Moves a finished workout to the local day [day], keeping its time of
  /// day and duration (never ending in the future). Base weights are not
  /// rewritten. Throws [ArgumentError] for a future day, [StateError] for a
  /// live workout.
  Future<void> setWorkoutDay(String workoutId, DateTime day) =>
      _db.transaction(() async {
        final workout = await _workout(workoutId);
        final ended = workout.endedAt;
        if (ended == null) {
          throw StateError('Use setLiveWorkoutDay for a live workout');
        }
        final now = _db.now();
        checkWorkoutDay(day, now);
        final (start, end) = _clampToNow(
          shiftToDay(workout.startedAt, day),
          ended.difference(workout.startedAt),
          now,
        );
        await (_db.update(
          _db.workouts,
        )..where((w) => w.id.equals(workoutId))).write(
          WorkoutsCompanion(
            startedAt: Value(start),
            endedAt: Value(end),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
      });

  /// (start, start + duration), moved earlier so the end is not after [now].
  static (DateTime, DateTime) _clampToNow(
    DateTime start,
    Duration duration,
    DateTime now,
  ) {
    final end = start.add(duration);
    return end.isAfter(now) ? (now.subtract(duration), now) : (start, end);
  }

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
          await _db.clearLiveSession(workoutId);
          return const FinishResult(outcomes: [], discarded: true);
        }
        // Mark it finished (on the chosen day, with its live duration) first:
        // the newest-session check below needs its final start time.
        final now = _db.now();
        final live = await _db.readLiveSession();
        var startedAt = workout.startedAt;
        var endedAt = now;
        if (live != null && live.workoutId == workoutId) {
          final day = live.day;
          final (s, e) = _clampToNow(
            day == null ? startedAt : shiftToDay(startedAt, day),
            live.elapsed(now),
            now,
          );
          startedAt = s;
          endedAt = e;
        }
        await (_db.update(
          _db.workouts,
        )..where((w) => w.id.equals(workoutId))).write(
          WorkoutsCompanion(
            startedAt: Value(startedAt),
            endedAt: Value(endedAt),
            updatedAt: Value(now),
            dirty: const Value(true),
          ),
        );
        await _db.clearLiveSession(workoutId);
        final outcomes = <FinishOutcome>[];
        for (final we in wes) {
          final sets = setsByWe[we.id]!;
          if (sets.isEmpty) continue;
          final source = await _sourceOf(we);
          final current = await _planOf(source);
          final plan = snapshotOf(we) ?? current?.toPlan();
          if (plan == null) continue;
          final result = evaluate(plan, sets.map(loggedFromRow));
          await _writeSnapshot(we.id, plan, result.nextBaseWeight);
          var toBase = current?.baseWeight ?? plan.baseWeight;
          // Only the newest session of a plan moves its base (a backdated or
          // resumed older session never does).
          if (current != null &&
              result.progressed &&
              roundWeight(current.baseWeight) == plan.baseWeight &&
              await _isLatestSession(source, workoutId)) {
            await _setBase(source, result.nextBaseWeight);
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
        return FinishResult(outcomes: outcomes, discarded: false);
      });

  /// Discards an in-progress workout.
  Future<void> discardWorkout(String workoutId) => _db.transaction(() async {
    final workout = await _workout(workoutId);
    if (workout.endedAt != null) {
      throw StateError('Only an active workout can be discarded');
    }
    await _deleteWorkoutRows(workoutId);
    await _db.clearLiveSession(workoutId);
  });

  /// Any finished workout can be resumed while no workout is in progress
  /// (feature 007; before, only the most recent one).
  Future<bool> canResume(String workoutId) async {
    if (await activeWorkout() != null) return false;
    if (await _trackingActive()) return false;
    final workout = await (_db.select(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).getSingleOrNull();
    return workout?.endedAt != null;
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
    final workout = await _workout(workoutId);
    final now = _db.now();
    await (_db.update(
      _db.workouts,
    )..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(
        endedAt: const Value(null),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    // Keep the earlier duration; the time between finish and resume does
    // not count.
    await _db.writeLiveSession(
      LiveSession(
        workoutId: workoutId,
        liveSince: now,
        priorSeconds: workout.endedAt!.difference(workout.startedAt).inSeconds,
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
    await _db.clearLiveSession(workoutId);
  });

  /// Creates or replaces the plan this session uses: the exercise's own plan
  /// for an ad-hoc session, the template exercise's plan for a template
  /// session (feature 005). Throws [StateError] for an orphaned session.
  Future<void> savePlan(String workoutExerciseId, StoredPlan plan) =>
      _db.transaction(() async {
        final source = await _sourceOf(await _we(workoutExerciseId));
        switch (source.kind) {
          case PlanSourceKind.exercise:
            await _db.writeExercisePlan(source.exerciseId, plan);
          case PlanSourceKind.template:
            await _db.writeTemplatePlan(source.templateExerciseId!, plan);
          case PlanSourceKind.orphan:
            throw StateError('This template exercise no longer exists');
        }
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
      final source = await _sourceOf(we);
      final plan = await _planOf(source);
      final prev = await previousSession(we.exerciseId, before: workout);
      details.add(
        WorkoutExerciseDetail(
          row: we,
          exercise: exercise,
          currentPlan: plan,
          sets: await _setsOf(we.id),
          previous: prev,
          restSeconds: plan?.restSeconds,
          planSource: source.kind,
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

  Stream<List<HistoryEntry>> watchHistoryEntries() =>
      watchQuery(_db, historyEntries);

  /// Finished workouts and logged activities together, newest first
  /// (feature 006).
  Future<List<HistoryEntry>> historyEntries() async {
    final entries = <HistoryEntry>[
      for (final w in await history()) WorkoutHistoryEntry(w),
      for (final a in await _db.select(_db.activities).get())
        ActivityHistoryEntry(a),
    ];
    return entries..sort((a, b) {
      final byTime = b.startedAt.compareTo(a.startedAt);
      return byTime != 0 ? byTime : b.id.compareTo(a.id);
    });
  }

  Stream<HomeStats> watchHomeStats(DateTime Function() now) =>
      watchQuery(_db, () => homeStats(now()));

  Future<HomeStats> homeStats(DateTime now) async {
    // Gym workouts and activities all count, per type (feature 025). Weeks
    // run Sunday to Saturday on local calendar days.
    final local = now.toLocal();
    final sessions = [
      for (final d in await _finishedStartDates())
        TrainingSession(gymTypeId, d),
      for (final a in await _db.select(_db.activities).get())
        TrainingSession(a.typeId, a.startedAt.toLocal()),
    ];
    return HomeStats(
      thisWeek: sessions.where((s) => isSameWeek(s.startedAt, local)).length,
      thisMonth: sessions.where((s) => isSameMonth(s.startedAt, local)).length,
      allTime: sessions.length,
      byType: trainingBreakdown(sessions, now: local),
      recent: (await historyEntries()).take(3).toList(),
    );
  }

  Stream<Map<DateTime, int>> watchWorkoutsPerWeek(DateTime Function() now) =>
      watchQuery(
        _db,
        () async => workoutsPerWeek([
          ...await _finishedStartDates(),
          ...await _activityDates(),
        ], now: now()),
      );

  Future<List<DateTime>> _finishedStartDates() async {
    final rows = await (_db.select(
      _db.workouts,
    )..where((w) => w.endedAt.isNotNull())).get();
    return [for (final r in rows) r.startedAt.toLocal()];
  }

  Future<List<DateTime>> _activityDates() async => [
    for (final a in await _db.select(_db.activities).get())
      a.startedAt.toLocal(),
  ];

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _recalculate(String workoutExerciseId) async {
    final we = await _we(workoutExerciseId);
    final workout = await _workout(we.workoutId);
    if (workout.endedAt == null) return; // live workouts evaluate on finish
    final source = await _sourceOf(we);
    final current = await _planOf(source);
    final isLatest = await _isLatestSession(source, we.workoutId);
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
      plan = current.toPlan();
      oldResult = current.baseWeight;
    }
    final sets = await _setsOf(we.id);
    final result = evaluate(plan, sets.map(loggedFromRow));
    final rewrite =
        current != null &&
        canRewriteBase(
          isLatestSessionForPlan: isLatest,
          currentBase: current.baseWeight,
          resultBaseWeight: oldResult,
        );
    await _writeSnapshot(we.id, plan, result.nextBaseWeight);
    if (rewrite) await _setBase(source, result.nextBaseWeight);
  }

  /// Restores the snapshot base if this session's progression is still the
  /// current base and this is the latest session.
  Future<void> _undoProgression(WorkoutExerciseRow we) async {
    final snapshot = snapshotOf(we);
    if (snapshot == null) return;
    final source = await _sourceOf(we);
    final current = await _planOf(source);
    if (current == null) return;
    final isLatest = await _isLatestSession(source, we.workoutId);
    if (canRewriteBase(
      isLatestSessionForPlan: isLatest,
      currentBase: current.baseWeight,
      resultBaseWeight: we.resultBaseWeight,
    )) {
      await _setBase(source, snapshot.baseWeight);
    }
  }

  /// Resolves which plan [we] uses and progresses (feature 005).
  Future<_PlanSource> _sourceOf(WorkoutExerciseRow we) async {
    final teId = we.templateExerciseId;
    if (teId == null) return _PlanSource.exercise(we.exerciseId);
    final te = await _db.templateExercise(teId);
    return te == null
        ? _PlanSource.orphan(we.exerciseId, teId)
        : _PlanSource.template(we.exerciseId, teId);
  }

  Future<StoredPlan?> _planOf(_PlanSource source) async {
    switch (source.kind) {
      case PlanSourceKind.exercise:
        return await _db.exercisePlan(source.exerciseId);
      case PlanSourceKind.template:
        final te = await _db.templateExercise(source.templateExerciseId!);
        return te == null ? null : StoredPlan.ofTemplate(te);
      case PlanSourceKind.orphan:
        return null;
    }
  }

  /// Whether [workoutId] is the latest finished workout with a session of
  /// [source] (by start time, then id). Ad-hoc sessions of an exercise and
  /// sessions of each template exercise are separate histories.
  Future<bool> _isLatestSession(_PlanSource source, String workoutId) async {
    final w = _db.workouts;
    final we = _db.workoutExercises;
    final ofSource = source.kind == PlanSourceKind.exercise
        ? we.exerciseId.equals(source.exerciseId) &
              we.templateExerciseId.isNull()
        : we.templateExerciseId.equals(source.templateExerciseId!);
    final q = _db.select(w).join([innerJoin(we, we.workoutId.equalsExp(w.id))])
      ..where(ofSource & w.endedAt.isNotNull())
      ..orderBy([OrderingTerm.desc(w.startedAt), OrderingTerm.desc(w.id)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.readTable(w).id == workoutId;
  }

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

  Future<void> _setBase(_PlanSource source, double base) async {
    final b = Value(roundWeight(base));
    final ts = Value(_db.now());
    switch (source.kind) {
      case PlanSourceKind.exercise:
        await (_db.update(
          _db.exerciseState,
        )..where((p) => p.exerciseId.equals(source.exerciseId))).write(
          ExerciseStateCompanion(
            baseWeight: b,
            updatedAt: ts,
            dirty: const Value(true),
          ),
        );
      case PlanSourceKind.template:
        await (_db.update(
          _db.templateExercises,
        )..where((t) => t.id.equals(source.templateExerciseId!))).write(
          TemplateExercisesCompanion(
            baseWeight: b,
            updatedAt: ts,
            dirty: const Value(true),
          ),
        );
      case PlanSourceKind.orphan:
        break; // never rewrites any plan
    }
  }

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
    return (await _planOf(await _sourceOf(we)))?.toPlan();
  }

  Future<WorkoutRow> _workout(String id) =>
      (_db.select(_db.workouts)..where((w) => w.id.equals(id))).getSingle();

  Future<WorkoutExerciseRow> _we(String id) => (_db.select(
    _db.workoutExercises,
  )..where((t) => t.id.equals(id))).getSingle();

  Future<ExerciseRow> _exercise(String id) =>
      (_db.select(_db.exercises)..where((e) => e.id.equals(id))).getSingle();

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

/// The plan a workout exercise uses (feature 005).
class _PlanSource {
  const new exercise(this.exerciseId)
    : kind = PlanSourceKind.exercise,
      templateExerciseId = null;
  const new template(this.exerciseId, String this.templateExerciseId)
    : kind = PlanSourceKind.template;
  const new orphan(this.exerciseId, String this.templateExerciseId)
    : kind = PlanSourceKind.orphan;

  final PlanSourceKind kind;
  final String exerciseId;
  final String? templateExerciseId;
}
