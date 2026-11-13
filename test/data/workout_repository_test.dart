import 'package:fitapp/domain/progression.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  group('live workout', () {
    test('only one workout can be active', () async {
      await h.workouts.startWorkout();
      expect(h.workouts.startWorkout, throwsStateError);
    });

    test('re-logging a set overwrites it (no duplicates)', () async {
      await h.plan();
      final (_, we) = await h.session([(20, 10)], finish: false);
      await h.workouts.logSet(we, setNo: 1, weight: 22.5, reps: 8);
      final rows = await h.db.select(h.db.sets).get();
      expect(rows, hasLength(1));
      expect(rows.single.weight, 22.5);
      expect(rows.single.reps, 8);
    });

    test('overload flag follows the plan', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (22.5, 6), (10, 5)], finish: false);
      final rows = await h.db.select(h.db.sets).get();
      expect(
        {for (final r in rows) r.setNo: r.isOverload},
        {1: false, 2: false, 3: true, 4: false},
      );
    });

    test('weights are rounded on write', () async {
      await h.plan();
      await h.session([(0.1 + 0.2 + 22.2, 10)], finish: false);
      expect((await h.db.select(h.db.sets).getSingle()).weight, 22.5);
    });

    test('clear set returns it to not logged and queues a delete', () async {
      await h.plan();
      final (_, we) = await h.session([(20, 10)], finish: false);
      await h.workouts.clearSet(we, 1);
      expect(await h.db.select(h.db.sets).get(), isEmpty);
      final pending = await h.db.select(h.db.pendingDeletes).get();
      expect(pending.single.tableNameValue, 'sets');
    });

    test('finishing with no sets discards the workout', () async {
      final w = await h.workouts.startWorkout();
      await h.workouts.addExercise(w.id, inclineId);
      final r = await h.workouts.finishWorkout(w.id);
      expect(r.discarded, isTrue);
      expect(await h.db.select(h.db.workouts).get(), isEmpty);
    });

    test('discardWorkout removes an active workout', () async {
      final w = await h.workouts.startWorkout();
      await h.workouts.discardWorkout(w.id);
      expect(await h.workouts.activeWorkout(), isNull);
    });

    test('exercises are appended in order', () async {
      final w = await h.workouts.startWorkout();
      final a = await h.workouts.addExercise(w.id, inclineId);
      final b = await h.workouts.addExercise(w.id, latId);
      expect([a.position, b.position], [0, 1]);
    });
  });

  group('progression on finish (PRD §11)', () {
    test('1: progressed, next prescription 22.5, 22.5, 25', () async {
      await h.plan();
      final (w, _) = await h.session([(20, 10), (20, 10), (22.5, 6)]);
      expect(await h.base(), 22.5);
      final detail = (await h.workouts.workoutDetail(w))!;
      final we = detail.exercises.single.row;
      expect(we.planBaseWeight, 20);
      expect(we.resultBaseWeight, 22.5);
      final next = prescribe(detail.exercises.single.currentPlan!.toPlan());
      expect(next.map((s) => s.weight), [22.5, 22.5, 25]);
    });

    test('finish result reports the change', () async {
      await h.plan();
      final (_, _) = await h.session([
        (20, 10),
        (20, 10),
        (22.5, 6),
      ], finish: false);
      final active = (await h.workouts.activeWorkout())!;
      final r = await h.workouts.finishWorkout(active.id);
      expect(r.discarded, isFalse);
      final o = r.outcomes.single;
      expect(o.exerciseName, 'Incline Dumbbell Bench Press');
      expect((o.fromBase, o.toBase, o.progressed), (20.0, 22.5, true));
    });

    test('2: missed reps keeps 22.5', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (22.5, 6)]);
      await h.session([(22.5, 10), (22.5, 8), (25, 4)]);
      expect(await h.base(), 22.5);
    });

    test('full flow: plan -> progression -> missed -> history', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (22.5, 6)]);
      await h.session([(22.5, 10), (22.5, 8), (25, 4)]);
      await h.session([(22.5, 10), (22.5, 10), (25, 5)]);
      expect(await h.base(), 25);
      final history = await h.exercises.history(inclineId);
      expect(history, hasLength(3));
      expect(history.first.sets.last.weight, 25);
    });

    test('exercises without a plan never progress or snapshot', () async {
      final (w, _) = await h.session([(50, 10), (50, 10), (55, 10)]);
      expect(await h.exercises.plan(inclineId), isNull);
      final we = (await h.workouts.workoutDetail(w))!.exercises.single.row;
      expect(we.planBaseWeight, isNull);
      expect(we.resultBaseWeight, isNull);
    });

    test('a manually edited base is not overwritten on finish', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (22.5, 6)], finish: false);
      await h.plan(base: 30);
      final active = (await h.workouts.activeWorkout())!;
      await h.workouts.finishWorkout(active.id);
      expect(await h.base(), 30);
    });
  });

  group('previous session and history list', () {
    test('previousSession returns the last finished session', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (22.5, 6)]);
      final (w2, _) = await h.session([(22.5, 10)], finish: false);
      final detail = (await h.workouts.workoutDetail(w2))!;
      final prev = detail.exercises.single.previous!;
      expect(prev.map((s) => s.weight), [20, 20, 22.5]);
      expect(detail.exercises.single.previousSetNo(3)!.reps, 6);
    });

    test('first session has no previous', () async {
      await h.plan();
      final (w, _) = await h.session([(20, 10)], finish: false);
      final detail = (await h.workouts.workoutDetail(w))!;
      expect(detail.exercises.single.previous, isNull);
    });

    test('history list: volume (per hand x2), names, set count', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (22.5, 6)]);
      advance(h);
      final items = await h.workouts.history();
      expect(items.single.volume, 1070);
      expect(items.single.exerciseNames, ['Incline Dumbbell Bench Press']);
      expect(items.single.setCount, 3);
      expect(items.single.duration, const Duration(minutes: 12));
    });
  });
}

void advance(Harness h) => h.advance();
