// Feature 005: templates carry their own progression (spec US2, US3, US4).
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fitapp/data/models.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Cable Fly (+2.5, not per hand).
const _fly = '00000000-0000-4000-8000-000000000003';

const _hit = [(20.0, 10), (20.0, 10), (22.5, 4)];

void main() {
  late Harness h;
  late TemplateRepository templates;

  setUp(() {
    h = Harness();
    templates = TemplateRepository(h.db);
  });
  tearDown(() => h.close());

  Future<StoredPlan?> tplPlan(String templateId, [String ex = _fly]) async =>
      (await templates.template(templateId))!.plans[ex];

  Future<double> tplBase(String templateId, [String ex = _fly]) async =>
      (await tplPlan(templateId, ex))!.baseWeight;

  /// Starts [templateId], logs [sets] on its first exercise, finishes unless
  /// [finish] is false. Returns (workoutId, workoutExerciseId).
  Future<(String, String)> run(
    String templateId,
    List<(double, int)> sets, {
    bool finish = true,
  }) async {
    h.advance();
    final w = await templates.startWorkout(templateId);
    final we = (await h.workouts.workoutDetail(w))!.exercises.first.row.id;
    for (final (i, s) in sets.indexed) {
      h.advance(const Duration(minutes: 3));
      await h.workouts.logSet(we, setNo: i + 1, weight: s.$1, reps: s.$2);
    }
    if (finish) {
      h.advance(const Duration(minutes: 3));
      await h.workouts.finishWorkout(w);
    }
    return (w, we);
  }

  Future<String> chest() async {
    await h.plan(exerciseId: _fly);
    return templates.create(name: 'Chest', exerciseIds: [_fly]);
  }

  group('seeding (US3)', () {
    test('create copies the exercise plan, or none', () async {
      await h.plan(exerciseId: _fly, base: 30, reps: 8, sets: 4, inc: 5);
      final id = await templates.create(
        name: 'Chest',
        exerciseIds: [_fly, inclineId],
      );
      expect(
        await tplPlan(id),
        const StoredPlan(
          baseWeight: 30,
          targetReps: 8,
          targetSets: 4,
          increment: 5,
        ),
      );
      expect(await tplPlan(id, inclineId), isNull);
    });

    test('explicit plans win and are validated', () async {
      const p = StoredPlan(
        baseWeight: 25.1,
        targetReps: 8,
        targetSets: 4,
        increment: 2.5,
        restSeconds: 90,
      );
      final id = await templates.create(
        name: 'Chest',
        exerciseIds: [_fly],
        plans: {_fly: p},
      );
      expect((await tplPlan(id))!.baseWeight, 25);
      expect((await tplPlan(id))!.restSeconds, 90);
      expect(
        () => templates.create(
          name: 'Bad',
          exerciseIds: [_fly],
          plans: {
            _fly: const StoredPlan(
              baseWeight: 20,
              targetReps: 10,
              targetSets: 1,
              increment: 2.5,
            ),
          },
        ),
        throwsArgumentError,
      );
    });

    test('update edits kept plans only when given; new rows seed', () async {
      final id = await chest();
      await h.plan(base: 40);
      await templates.update(
        id,
        name: 'Chest',
        exerciseIds: [_fly, inclineId],
        plans: {
          _fly: const StoredPlan(
            baseWeight: 22.5,
            targetReps: 12,
            targetSets: 3,
            increment: 2.5,
          ),
        },
      );
      expect((await tplPlan(id))!.targetReps, 12);
      expect(await tplBase(id, inclineId), 40);
      await templates.update(id, name: 'Chest', exerciseIds: [_fly, inclineId]);
      expect((await tplPlan(id))!.targetReps, 12); // untouched
    });

    test('re-adding a removed exercise seeds a fresh plan', () async {
      final id = await chest();
      await run(id, _hit);
      expect(await tplBase(id), 22.5);
      await templates.update(id, name: 'Chest', exerciseIds: [inclineId]);
      await templates.update(id, name: 'Chest', exerciseIds: [_fly]);
      expect(await tplBase(id), 20);
    });

    test('save from workout uses the plan each session uses', () async {
      final id = await chest();
      await run(id, _hit); // Chest fly now 22.5, own plan 20
      await h.plan();
      final (w, _) = await run(id, const [], finish: false);
      await h.workouts.addExercise(w, inclineId);
      final copy = await templates.saveFromWorkout(w, name: 'Copy');
      expect(await tplBase(copy), 22.5);
      expect(await tplBase(copy, inclineId), 20);
    });
  });

  group('progression lives in the template (US2)', () {
    test('owner example: working sets hit -> template 22.5', () async {
      final id = await chest();
      final r = await h.workouts.finishWorkout(
        (await run(id, _hit, finish: false)).$1,
      );
      expect(r.outcomes.single.fromBase, 20);
      expect(r.outcomes.single.toBase, 22.5);
      expect(await tplBase(id), 22.5);
      expect(await h.base(_fly), 20); // exercise plan untouched
      final (w2, _) = await run(id, const [], finish: false);
      final d = (await h.workouts.workoutDetail(w2))!.exercises.single;
      expect(d.planSource, PlanSourceKind.template);
      expect(d.effectivePlan!.baseWeight, 22.5);
    });

    test('two templates with the same exercise are independent', () async {
      final a = await chest();
      final b = await templates.create(name: 'Upper', exerciseIds: [_fly]);
      await run(a, _hit);
      expect(await tplBase(a), 22.5);
      expect(await tplBase(b), 20);
    });

    test('ad-hoc workouts use and progress only the exercise plan', () async {
      final id = await chest();
      await h.session(_hit, exerciseId: _fly);
      expect(await h.base(_fly), 22.5);
      expect(await tplBase(id), 20);
    });

    test(
      'an exercise added ad hoc to a template workout uses its own plan',
      () async {
        final id = await chest();
        await h.plan();
        final (w, _) = await run(id, const [], finish: false);
        final we = await h.workouts.addExercise(w, inclineId);
        for (final (i, s) in _hit.indexed) {
          await h.workouts.logSet(
            we.id,
            setNo: i + 1,
            weight: s.$1,
            reps: s.$2,
          );
        }
        await h.workouts.finishWorkout(w);
        expect(await h.base(), 22.5);
        final d = (await h.workouts.workoutDetail(w))!.exercises;
        expect(d.last.planSource, PlanSourceKind.exercise);
      },
    );

    test('missed reps keep the template plan', () async {
      final id = await chest();
      await run(id, [(20, 10), (20, 9), (22.5, 10)]);
      expect(await tplBase(id), 20);
    });

    test(
      'template exercise without a plan: setup saves to the template',
      () async {
        final id = await templates.create(name: 'Chest', exerciseIds: [_fly]);
        final (w, we) = await run(id, const [], finish: false);
        final d = (await h.workouts.workoutDetail(w))!.exercises.single;
        expect(d.currentPlan, isNull);
        await h.workouts.savePlan(
          we,
          const StoredPlan(
            baseWeight: 15,
            targetReps: 10,
            targetSets: 3,
            increment: 2.5,
            restSeconds: 120,
          ),
        );
        expect(await tplBase(id), 15);
        expect(await h.exercises.plan(_fly), isNull);
        final again = (await h.workouts.workoutDetail(w))!.exercises.single;
        expect(again.restSeconds, 120);
      },
    );

    test('Edit plan on an ad-hoc session edits the exercise plan', () async {
      await h.plan();
      final (_, we) = await h.session(const [], finish: false);
      await h.workouts.savePlan(
        we,
        const StoredPlan(
          baseWeight: 30,
          targetReps: 10,
          targetSets: 3,
          increment: 2.5,
        ),
      );
      expect(await h.base(), 30);
    });
  });

  group('history safety per plan (US4, PRD §11 on a template)', () {
    test('§11.4 resume undoes; re-finish with a miss stays', () async {
      final id = await chest();
      final (w, we) = await run(id, _hit);
      await h.workouts.resumeWorkout(w);
      expect(await tplBase(id), 20);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 8);
      await h.workouts.finishWorkout(w);
      expect(await tplBase(id), 20);
    });

    test('§11.5 edit latest: 9 reps -> 20, back to 10 -> 22.5', () async {
      final id = await chest();
      final (_, we) = await run(id, _hit);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 9);
      expect(await tplBase(id), 20);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 10);
      expect(await tplBase(id), 22.5);
    });

    test('§11.6 editing an older session keeps the current base', () async {
      final id = await chest();
      final (_, we1) = await run(id, _hit);
      await run(id, [(22.5, 10), (22.5, 10)]);
      expect(await tplBase(id), 25);
      await h.workouts.logSet(we1, setNo: 2, weight: 20, reps: 5);
      expect(await tplBase(id), 25);
    });

    test('§11.7 a hand-edited plan survives resume and re-finish', () async {
      final id = await chest();
      final (w, we) = await run(id, _hit);
      await h.workouts.savePlan(
        we,
        const StoredPlan(
          baseWeight: 30,
          targetReps: 10,
          targetSets: 3,
          increment: 2.5,
        ),
      );
      await h.workouts.resumeWorkout(w);
      final r = await h.workouts.finishWorkout(w);
      expect(r.outcomes.single.reason.code, 'progressed');
      expect(await tplBase(id), 30);
    });

    test('§11.8 delete latest undoes; delete older leaves it', () async {
      final id = await chest();
      final (w1, _) = await run(id, _hit);
      final (w2, _) = await run(id, [(22.5, 10), (22.5, 10)]);
      await h.workouts.deleteWorkout(w1);
      expect(await tplBase(id), 25);
      await h.workouts.deleteWorkout(w2);
      expect(await tplBase(id), 22.5);
    });

    test('latest-session check is per plan, not per exercise', () async {
      final id = await chest();
      final (_, we) = await run(id, _hit);
      // A later ad-hoc session of the same exercise does not make the
      // template session "older".
      await h.session(const [(20, 10)], exerciseId: _fly);
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 9);
      expect(await tplBase(id), 20);
      expect(await h.base(_fly), 20);
    });

    test(
      'template edits never touch the exercise plan, and vice versa',
      () async {
        final id = await chest();
        final (tw, _) = await run(id, _hit);
        final (aw, _) = await h.session(_hit, exerciseId: _fly);
        expect((await tplBase(id), await h.base(_fly)), (22.5, 22.5));
        await h.workouts.deleteWorkout(aw);
        expect((await tplBase(id), await h.base(_fly)), (22.5, 20.0));
        await h.workouts.deleteWorkout(tw);
        expect((await tplBase(id), await h.base(_fly)), (20.0, 20.0));
      },
    );
  });

  group('deleted templates', () {
    test('finished sessions become orphans and never change plans', () async {
      final id = await chest();
      final (w, we) = await run(id, _hit);
      await templates.delete(id);
      final d = (await h.workouts.workoutDetail(w))!.exercises.single;
      expect(d.planSource, PlanSourceKind.orphan);
      expect(d.currentPlan, isNull);
      expect(d.effectivePlan!.baseWeight, 20); // snapshot still drives it
      await h.workouts.logSet(we, setNo: 2, weight: 20, reps: 5);
      await h.workouts.deleteWorkout(w);
      expect(await h.base(_fly), 20);
      expect(
        () => h.workouts.savePlan(
          we,
          const StoredPlan(
            baseWeight: 1,
            targetReps: 1,
            targetSets: 2,
            increment: 1,
          ),
        ),
        throwsA(anything),
      );
    });

    test('a live workout falls back to the exercise plan', () async {
      final id = await chest();
      await run(id, _hit);
      final (w, we) = await run(id, const [], finish: false);
      await templates.update(id, name: 'Chest', exerciseIds: [inclineId]);
      final d = (await h.workouts.workoutDetail(w))!.exercises.single;
      expect(d.planSource, PlanSourceKind.exercise);
      expect(d.effectivePlan!.baseWeight, 20);
      for (final (i, s) in _hit.indexed) {
        await h.workouts.logSet(we, setNo: i + 1, weight: s.$1, reps: s.$2);
      }
      await h.workouts.finishWorkout(w);
      expect(await h.base(_fly), 22.5);
    });

    test('a resumed workout keeps its link and snapshot', () async {
      final id = await chest();
      final (w, _) = await run(id, _hit);
      await h.workouts.resumeWorkout(w);
      await templates.delete(id);
      final row = await (h.db.select(
        h.db.workoutExercises,
      )..where((t) => t.workoutId.equals(w))).getSingle();
      expect(row.templateExerciseId, isNotNull);
      await h.workouts.finishWorkout(w);
      expect(await h.base(_fly), 20);
    });
  });
}
