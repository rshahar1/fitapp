import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
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

  group('createCustom muscleGroup', () {
    test('stores the category; null means Custom', () async {
      final a = await h.exercises.createCustom(
        name: 'Cat A',
        perHand: false,
        increment: 2,
        muscleGroup: 'Arms',
      );
      expect(a.muscleGroup, 'Arms');
      final b = await h.exercises.createCustom(
        name: 'Cat B',
        perHand: false,
        increment: 2,
      );
      expect(b.muscleGroup, isNull);
    });

    test('rejects an invalid category', () async {
      await expectLater(
        h.exercises.createCustom(
          name: 'Cat C',
          perHand: false,
          increment: 2,
          muscleGroup: 'Nope',
        ),
        throwsArgumentError,
      );
    });
  });

  group('updateCustom', () {
    Future<ExerciseRow> make(String name) =>
        h.exercises.createCustom(name: name, perHand: false, increment: 2);

    test('updates fields and marks dirty', () async {
      final e = await make('Old Name');
      final u = await h.exercises.updateCustom(
        e.id,
        name: '  New Name ',
        muscleGroup: 'Back',
        perHand: true,
        increment: 1.25,
      );
      expect(u.name, 'New Name');
      expect(u.muscleGroup, 'Back');
      expect(u.isPerHand, isTrue);
      expect(u.defaultIncrement, 1.25);
      expect(u.dirty, isTrue);
      expect((await h.exercises.exercise(e.id))!.name, 'New Name');
    });

    test('validates input', () async {
      final e = await make('Valid One');
      Future<ExerciseRow> upd({
        String name = 'X',
        String? group,
        double inc = 1,
      }) => h.exercises.updateCustom(
        e.id,
        name: name,
        muscleGroup: group,
        perHand: false,
        increment: inc,
      );
      await expectLater(upd(name: ' '), throwsArgumentError);
      await expectLater(upd(inc: 0), throwsArgumentError);
      await expectLater(upd(group: 'Nope'), throwsArgumentError);
    });

    test('rejects a duplicate name of another exercise', () async {
      await make('Taken');
      final e = await make('Other');
      await expectLater(
        h.exercises.updateCustom(
          e.id,
          name: ' taken ',
          muscleGroup: null,
          perHand: false,
          increment: 2,
        ),
        throwsA(isA<DuplicateExerciseName>()),
      );
    });

    test('allows a case-only rename of itself', () async {
      final e = await make('Case Move');
      final u = await h.exercises.updateCustom(
        e.id,
        name: 'CASE MOVE',
        muscleGroup: null,
        perHand: false,
        increment: 2,
      );
      expect(u.name, 'CASE MOVE');
    });

    test('built-in and unknown ids throw StateError', () async {
      await expectLater(
        h.exercises.updateCustom(
          inclineId,
          name: 'Hacked',
          muscleGroup: null,
          perHand: false,
          increment: 2,
        ),
        throwsStateError,
      );
      await expectLater(
        h.exercises.updateCustom(
          'missing',
          name: 'Hacked',
          muscleGroup: null,
          perHand: false,
          increment: 2,
        ),
        throwsStateError,
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

  group('delete (feature 012)', () {
    late TemplateRepository templates;
    setUp(() => templates = TemplateRepository(h.db));

    Future<List<String>> listedIds() async => [
      for (final e in await h.exercises.watchExercises().first) e.id,
    ];

    test(
      'built-in: hidden from the library and stays deleted after seeding',
      () async {
        await h.exercises.delete(latId);
        expect(await listedIds(), isNot(contains(latId)));
        final row = (await h.exercises.exercise(latId))!;
        expect(row.deletedAt, isNotNull);
        expect(row.dirty, isTrue);
        await h.db.seedLibrary();
        expect(await listedIds(), isNot(contains(latId)));
      },
    );

    test('custom: hidden from the library and from search', () async {
      final e = await h.exercises.createCustom(
        name: 'Zottman Curl',
        perHand: true,
        increment: 2,
      );
      await h.exercises.delete(e.id);
      expect(await listedIds(), isNot(contains(e.id)));
      expect(await h.exercises.watchExercises(query: 'zott').first, isEmpty);
    });

    test('keeps history and plan, hides from trained exercises', () async {
      await h.plan();
      await h.session([(20, 10), (20, 10), (20, 10)]);
      await h.exercises.delete(inclineId);
      expect(await h.exercises.history(inclineId), hasLength(1));
      expect(await h.exercises.plan(inclineId), isNotNull);
      expect(await h.exercises.trainedExercises(), isEmpty);
    });

    test(
      'removes it from templates and deletes templates left empty',
      () async {
        final both = await templates.create(
          name: 'Both',
          exerciseIds: [inclineId, latId],
        );
        await templates.create(name: 'Only incline', exerciseIds: [inclineId]);
        final usage = await h.exercises.templatesUsing(inclineId);
        expect(
          {for (final u in usage) u.name: u.wouldBeEmpty},
          {'Both': false, 'Only incline': true},
        );
        await h.exercises.delete(inclineId);
        final left = await templates.list();
        expect(left.map((t) => t.id), [both]);
        expect(left.single.exercises.map((e) => e.id), [latId]);
      },
    );

    test('creating a deleted name restores the exercise', () async {
      final e = await h.exercises.createCustom(
        name: 'Zottman Curl',
        perHand: true,
        increment: 2,
      );
      await h.exercises.delete(e.id);
      final back = await h.exercises.createCustom(
        name: 'zottman curl',
        perHand: false,
        increment: 5,
      );
      expect(back.id, e.id);
      expect(back.deletedAt, isNull);
      expect(back.isPerHand, isFalse);
      expect(back.defaultIncrement, 5);
      expect(await listedIds(), contains(e.id));
    });

    test('creating a deleted built-in name restores it unchanged', () async {
      final lat = (await h.exercises.exercise(latId))!;
      await h.exercises.delete(latId);
      final back = await h.exercises.createCustom(
        name: lat.name.toUpperCase(),
        perHand: true,
        increment: 9,
      );
      expect(back.id, latId);
      expect(back.isCustom, isFalse);
      expect(back.isPerHand, lat.isPerHand);
      expect(back.defaultIncrement, lat.defaultIncrement);
      expect(back.deletedAt, isNull);
    });

    test('active names still clash; deleted custom cannot be edited', () async {
      final e = await h.exercises.createCustom(
        name: 'Zottman Curl',
        perHand: true,
        increment: 2,
      );
      await expectLater(
        h.exercises.createCustom(
          name: 'ZOTTMAN CURL',
          perHand: true,
          increment: 2,
        ),
        throwsA(isA<DuplicateExerciseName>()),
      );
      await h.exercises.delete(e.id);
      await expectLater(
        h.exercises.updateCustom(
          e.id,
          name: 'X',
          muscleGroup: null,
          perHand: true,
          increment: 2,
        ),
        throwsStateError,
      );
    });

    test('unknown id throws', () async {
      await expectLater(h.exercises.delete('nope'), throwsStateError);
    });
  });
}
