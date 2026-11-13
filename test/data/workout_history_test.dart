import 'package:drift/drift.dart' show Value;
import 'package:fitapp/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _progressed = [(20.0, 10), (20.0, 10), (22.5, 6)];

void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.plan();
  });
  tearDown(() => h.close());

  group('resume (§11.4)', () {
    test('restores the base, re-finish re-applies with edits', () async {
      final (w, we) = await h.session(_progressed);
      expect(await h.base(), 22.5);
      expect(await h.workouts.canResume(w), isTrue);
      await h.workouts.resumeWorkout(w);
      expect(await h.base(), 20);
      expect((await h.workouts.activeWorkout())!.id, w);
      final row = (await h.workouts.workoutDetail(w))!.exercises.single.row;
      expect(row.resultBaseWeight, isNull);
      expect(row.planBaseWeight, 20); // snapshot plan kept
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 8);
      final r = await h.workouts.finishWorkout(w);
      expect(r.outcomes.single.progressed, isFalse);
      expect(await h.base(), 20);
    });

    test('blocked when another workout is active', () async {
      final (w, _) = await h.session(_progressed);
      await h.workouts.startWorkout();
      expect(await h.workouts.canResume(w), isFalse);
      expect(() => h.workouts.resumeWorkout(w), throwsStateError);
    });

    test('blocked when not the most recent finished workout', () async {
      final (w1, _) = await h.session(_progressed);
      await h.session([(22.5, 10)], exerciseId: latId);
      expect(await h.workouts.canResume(w1), isFalse);
    });
  });

  group('edit latest (§11.5)', () {
    test('set 2 -> 9 reps -> 20; back to 10 -> 22.5', () async {
      final (_, we) = await h.session(_progressed);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 9);
      expect(await h.base(), 20);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 10);
      expect(await h.base(), 22.5);
    });

    test('clearing a working set recalculates', () async {
      final (_, we) = await h.session(_progressed);
      await h.workouts.clearSet(we, 2);
      expect(await h.base(), 20);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 10);
      expect(await h.base(), 22.5);
    });

    test('clearing the overload set changes nothing (owner rule)', () async {
      final (_, we) = await h.session(_progressed);
      await h.workouts.clearSet(we, 3);
      expect(await h.base(), 22.5);
    });

    test('removing the exercise undoes its progression', () async {
      final (_, we) = await h.session(_progressed);
      await h.workouts.removeExercise(we);
      expect(await h.base(), 20);
    });
  });

  group('edit older (§11.6)', () {
    test('stored result changes, current base stays 25', () async {
      final (_, we1) = await h.session(_progressed);
      await h.session([(22.5, 10), (22.5, 10), (25, 5)]);
      expect(await h.base(), 25);
      await h.workouts.logSet(we1, setNo: 2, weight: 20, reps: 5);
      expect(await h.base(), 25);
      final row = await (h.db.select(
        h.db.workoutExercises,
      )..where((t) => t.id.equals(we1))).getSingle();
      expect(row.resultBaseWeight, 20);
    });
  });

  group('manual edit (§11.7)', () {
    test('resume + re-finish judged on snapshot; base stays 30', () async {
      final (w, _) = await h.session(_progressed);
      await h.plan(base: 30);
      await h.workouts.resumeWorkout(w);
      expect(await h.base(), 30);
      final r = await h.workouts.finishWorkout(w);
      final row = (await h.workouts.workoutDetail(w))!.exercises.single.row;
      expect(r.outcomes.single.progressed, isTrue);
      expect(row.resultBaseWeight, 22.5);
      expect(await h.base(), 30);
    });
  });

  group('delete (§11.8)', () {
    test('deleting the latest undoes its increase', () async {
      final (w, _) = await h.session(_progressed);
      await h.workouts.deleteWorkout(w);
      expect(await h.base(), 20);
      expect(await h.db.select(h.db.workouts).get(), isEmpty);
      expect(await h.db.select(h.db.workoutExercises).get(), isEmpty);
      expect(await h.db.select(h.db.sets).get(), isEmpty);
    });

    test('deleting an older one leaves the current base', () async {
      final (w1, _) = await h.session(_progressed);
      await h.session([(22.5, 10), (22.5, 10), (25, 5)]);
      await h.workouts.deleteWorkout(w1);
      expect(await h.base(), 25);
    });

    test('queues exactly one pending delete for the workout', () async {
      final (w, _) = await h.session(_progressed);
      await h.workouts.deleteWorkout(w);
      final pending = await h.db.select(h.db.pendingDeletes).get();
      expect(
        pending
            .where((p) => p.tableNameValue == 'workouts')
            .map((p) => p.rowId),
        [w],
      );
    });
  });

  group('legacy workouts without snapshots', () {
    Future<String> stripSnapshot(String weId) async {
      await (h.db.update(
        h.db.workoutExercises,
      )..where((t) => t.id.equals(weId))).write(
        const WorkoutExercisesCompanion(
          planBaseWeight: Value(null),
          planTargetReps: Value(null),
          planTargetSets: Value(null),
          planIncrement: Value(null),
          resultBaseWeight: Value(null),
        ),
      );
      return weId;
    }

    test('latest legacy session is evaluated with the current plan', () async {
      final (_, we) = await h.session(_progressed);
      await stripSnapshot(we);
      // Current plan is base 22.5 now; editing re-evaluates against it.
      await h.workouts.logSet(we, setNo: 1, weight: 22.5, reps: 10);
      final row = await (h.db.select(
        h.db.workoutExercises,
      )..where((t) => t.id.equals(we))).getSingle();
      expect(row.planBaseWeight, 22.5);
      expect(row.resultBaseWeight, 22.5); // set 2 at 20 < base -> missed
      expect(await h.base(), 22.5);
    });

    test('older legacy session is left alone', () async {
      final (_, we1) = await h.session(_progressed);
      await stripSnapshot(we1);
      await h.session([(22.5, 10), (22.5, 10), (25, 5)]);
      await h.workouts.logSet(we1, setNo: 2, weight: 20, reps: 1);
      final row = await (h.db.select(
        h.db.workoutExercises,
      )..where((t) => t.id.equals(we1))).getSingle();
      expect(row.planBaseWeight, isNull);
      expect(await h.base(), 25);
    });
  });
}
