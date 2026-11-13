import 'package:fitapp/data/repositories/live_session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Meets the 3x10 @ 20 plan with 6 reps on the overload set → 22.5.
const _progressed = [(20.0, 10), (20.0, 10), (22.5, 6)];

DateTime _localDay(DateTime utc) {
  final l = utc.toLocal();
  return DateTime(l.year, l.month, l.day);
}

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  group('live session record', () {
    test('start writes it, finish clears it', () async {
      final w = await h.workouts.startWorkout();
      final s = await h.db.readLiveSession();
      expect(s!.workoutId, w.id);
      expect(s.liveSince, h.now);
      expect(s.priorSeconds, 0);
      expect(s.day, isNull);
      final we = await h.workouts.addExercise(w.id, inclineId);
      await h.workouts.logSet(we.id, setNo: 1, weight: 10, reps: 10);
      h.advance(const Duration(minutes: 40));
      await h.workouts.finishWorkout(w.id);
      expect(await h.db.readLiveSession(), isNull);
      final row = (await h.workouts.workoutDetail(w.id))!.workout;
      expect(
        row.endedAt!.difference(row.startedAt),
        const Duration(minutes: 40),
      );
    });

    test('discard clears it', () async {
      final w = await h.workouts.startWorkout();
      await h.workouts.discardWorkout(w.id);
      expect(await h.db.readLiveSession(), isNull);
      expect(await h.workouts.activeWorkout(), isNull);
    });

    test('a live workout without a record finishes at now', () async {
      final w = await h.workouts.startWorkout();
      await h.db.clearLiveSession();
      final we = await h.workouts.addExercise(w.id, inclineId);
      await h.workouts.logSet(we.id, setNo: 1, weight: 10, reps: 10);
      h.advance(const Duration(minutes: 30));
      await h.workouts.finishWorkout(w.id);
      final row = (await h.workouts.workoutDetail(w.id))!.workout;
      expect(row.endedAt, h.now);
    });
  });

  group('resume', () {
    test('keeps the earlier duration and the date', () async {
      await h.plan();
      final (w, we) = await h.session(_progressed);
      final before = (await h.workouts.workoutDetail(w))!.workout;
      final earlier = before.endedAt!.difference(before.startedAt);
      h.advance(const Duration(days: 2));
      await h.workouts.resumeWorkout(w);
      final s = await h.db.readLiveSession();
      expect(s!.workoutId, w);
      expect(s.priorSeconds, earlier.inSeconds);
      expect(s.isResumed, isTrue);
      h.advance(const Duration(minutes: 10));
      await h.workouts.logSet(we, setNo: 4, weight: 20, reps: 10);
      await h.workouts.finishWorkout(w);
      final after = (await h.workouts.workoutDetail(w))!.workout;
      expect(after.startedAt, before.startedAt);
      expect(
        after.endedAt!.difference(after.startedAt),
        earlier + const Duration(minutes: 10),
      );
    });

    test('an older workout never moves a newer base', () async {
      await h.plan();
      final (w1, _) = await h.session(_progressed);
      await h.session([(22.5, 10), (22.5, 10), (25, 6)]);
      expect(await h.base(), 25);
      expect(await h.workouts.canResume(w1), isTrue);
      await h.workouts.resumeWorkout(w1);
      expect(await h.base(), 25);
      await h.workouts.finishWorkout(w1);
      expect(await h.base(), 25);
    });
  });

  group('workout day', () {
    test('a backdated live workout is stored on that day', () async {
      await h.plan();
      final w = await h.workouts.startWorkout();
      final yesterday = _localDay(h.now).subtract(const Duration(days: 1));
      await h.workouts.setLiveWorkoutDay(w.id, yesterday);
      expect((await h.db.readLiveSession())!.day, yesterday);
      final we = await h.workouts.addExercise(w.id, inclineId);
      for (final (i, s) in _progressed.indexed) {
        await h.workouts.logSet(we.id, setNo: i + 1, weight: s.$1, reps: s.$2);
      }
      h.advance(const Duration(minutes: 45));
      await h.workouts.finishWorkout(w.id);
      final row = (await h.workouts.workoutDetail(w.id))!.workout;
      expect(_localDay(row.startedAt), yesterday);
      expect(
        row.endedAt!.difference(row.startedAt),
        const Duration(minutes: 45),
      );
      // It is the newest session for the plan, so it progresses.
      expect(await h.base(), 22.5);
    });

    test(
      'a backdated session older than the newest never moves the base',
      () async {
        await h.plan();
        await h.session(_progressed);
        expect(await h.base(), 22.5);
        h.advance();
        final w = await h.workouts.startWorkout();
        await h.workouts.setLiveWorkoutDay(
          w.id,
          _localDay(h.now).subtract(const Duration(days: 10)),
        );
        final we = await h.workouts.addExercise(w.id, inclineId);
        for (final (i, s) in [(22.5, 10), (22.5, 10), (25.0, 6)].indexed) {
          await h.workouts.logSet(
            we.id,
            setNo: i + 1,
            weight: s.$1,
            reps: s.$2,
          );
        }
        final r = await h.workouts.finishWorkout(w.id);
        expect(await h.base(), 22.5);
        expect(r.outcomes.single.toBase, r.outcomes.single.fromBase);
      },
    );

    test('picking today clears an earlier pick', () async {
      final w = await h.workouts.startWorkout();
      await h.workouts.setLiveWorkoutDay(
        w.id,
        _localDay(h.now).subtract(const Duration(days: 3)),
      );
      await h.workouts.setLiveWorkoutDay(w.id, _localDay(h.now));
      expect((await h.db.readLiveSession())!.day, isNull);
    });

    test('future days are rejected', () async {
      final w = await h.workouts.startWorkout();
      expect(
        () => h.workouts.setLiveWorkoutDay(
          w.id,
          _localDay(h.now).add(const Duration(days: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('a legacy live workout without a record can be backdated', () async {
      final w = await h.workouts.startWorkout();
      await h.db.clearLiveSession();
      final day = _localDay(h.now).subtract(const Duration(days: 2));
      await h.workouts.setLiveWorkoutDay(w.id, day);
      final s = await h.db.readLiveSession();
      expect(s!.workoutId, w.id);
      expect(s.day, day);
    });

    test('moving a finished workout keeps duration and base', () async {
      await h.plan();
      final (w, _) = await h.session(_progressed);
      final before = (await h.workouts.workoutDetail(w))!.workout;
      final target = _localDay(before.startedAt)
          .subtract(const Duration(days: 5));
      await h.workouts.setWorkoutDay(w, target);
      final after = (await h.workouts.workoutDetail(w))!.workout;
      expect(_localDay(after.startedAt), target);
      expect(
        after.endedAt!.difference(after.startedAt),
        before.endedAt!.difference(before.startedAt),
      );
      expect(after.dirty, isTrue);
      expect(await h.base(), 22.5);
    });

    test(
      'moving a finished workout to today never ends in the future',
      () async {
        await h.plan();
        final (w, _) = await h.session(_progressed);
        final before = (await h.workouts.workoutDetail(w))!.workout;
        final duration = before.endedAt!.difference(before.startedAt);
        // Now is earlier in the day than the workout's time of day.
        h.now = before.startedAt.add(const Duration(days: 3, hours: -2));
        await h.workouts.setWorkoutDay(w, _localDay(h.now));
        final after = (await h.workouts.workoutDetail(w))!.workout;
        expect(after.endedAt!.isAfter(h.now), isFalse);
        expect(after.endedAt!.difference(after.startedAt), duration);
      },
    );

    test(
      'live workouts use setLiveWorkoutDay, finished ones setWorkoutDay',
      () async {
        final w = await h.workouts.startWorkout();
        expect(
          () => h.workouts.setWorkoutDay(w.id, _localDay(h.now)),
          throwsStateError,
        );
      },
    );
  });
}
