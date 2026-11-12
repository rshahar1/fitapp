import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  group('savePlan', () {
    Future<void> save({
      double base = 20,
      int reps = 10,
      int sets = 3,
      double inc = 2.5,
      int? rest,
    }) => h.exercises.savePlan(
      inclineId,
      baseWeight: base,
      targetReps: reps,
      targetSets: sets,
      increment: inc,
      restSeconds: rest,
    );

    test('validation', () async {
      await expectLater(save(sets: 1), throwsArgumentError);
      await expectLater(save(reps: 0), throwsArgumentError);
      await expectLater(save(inc: 0), throwsArgumentError);
      await expectLater(save(inc: -1), throwsArgumentError);
      await expectLater(save(base: -1), throwsArgumentError);
      await expectLater(save(rest: 9), throwsArgumentError);
      await expectLater(save(rest: 601), throwsArgumentError);
      expect(await h.exercises.plan(inclineId), isNull);
    });

    test('upserts and stores null rest as default', () async {
      await save(base: 20, rest: 90);
      expect((await h.exercises.plan(inclineId))!.restSeconds, 90);
      await save(base: 30, sets: 4);
      final p = (await h.exercises.plan(inclineId))!;
      expect(p.baseWeight, 30);
      expect(p.targetSets, 4);
      expect(p.restSeconds, isNull);
      expect(await h.db.select(h.db.exerciseState).get(), hasLength(1));
    });
  });

  group('createCustom', () {
    test('trims the name', () async {
      final e = await h.exercises.createCustom(
        name: '  Zottman Curl ',
        perHand: true,
        increment: 2,
      );
      expect(e.name, 'Zottman Curl');
      expect(e.isCustom, isTrue);
    });

    test('rejects empty name and bad increment', () async {
      await expectLater(
        h.exercises.createCustom(name: '   ', perHand: false, increment: 2),
        throwsArgumentError,
      );
      await expectLater(
        h.exercises.createCustom(name: 'X', perHand: false, increment: 0),
        throwsArgumentError,
      );
    });

    test('rejects duplicates case-insensitively, incl. library', () async {
      await expectLater(
        h.exercises.createCustom(
          name: 'barbell bench press',
          perHand: false,
          increment: 2.5,
        ),
        throwsA(isA<DuplicateExerciseName>()),
      );
      await h.exercises.createCustom(
        name: 'My Move',
        perHand: false,
        increment: 1,
      );
      await expectLater(
        h.exercises.createCustom(
          name: ' MY move ',
          perHand: false,
          increment: 1,
        ),
        throwsA(isA<DuplicateExerciseName>()),
      );
    });
  });

  test('watchExercises filters by query', () async {
    final list = await h.exercises.watchExercises(query: 'row').first;
    expect(list.map((e) => e.name).toList(), [
      'Dumbbell Row',
      'Seated Cable Row',
    ]);
  });

  test(
    'trainedExercises lists finished only, newest first, with plan',
    () async {
      await h.plan();
      await h.plan(exerciseId: latId);
      await h.session([(20, 10)], finish: false); // unfinished: excluded
      await h.workouts.discardWorkout((await h.workouts.activeWorkout())!.id);
      await h.session([(20, 10)]);
      await h.session([(30, 10)], exerciseId: latId);
      final list = await h.exercises.trainedExercises();
      expect(list.map((t) => t.exercise.id).toList(), [latId, inclineId]);
      expect(list.first.plan!.baseWeight, 20);
      expect(list.last.plan, isNotNull);
    },
  );

  test('trainedExercises excludes exercises only in active workouts', () async {
    await h.session([(20, 10)], finish: false);
    expect(await h.exercises.trainedExercises(), isEmpty);
  });

  test('history is newest first and respects limit', () async {
    await h.plan();
    for (var i = 0; i < 25; i++) {
      await h.session([(20 + i.toDouble(), 10)]);
    }
    final all = await h.exercises.history(inclineId);
    expect(all, hasLength(25));
    final top = await h.exercises.history(inclineId, limit: 20);
    expect(top, hasLength(20));
    expect(top.first.sets.first.weight, 44);
    expect(top.last.sets.first.weight, 25);
    for (var i = 1; i < top.length; i++) {
      expect(top[i - 1].date.isAfter(top[i].date), isTrue);
    }
  });
}
