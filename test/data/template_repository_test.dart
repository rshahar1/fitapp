import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/repositories/tracking_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _bench = '00000000-0000-4000-8000-000000000001';
const _ohp = '00000000-0000-4000-8000-00000000000c';
const _triceps = '00000000-0000-4000-8000-000000000010';

void main() {
  late Harness h;
  late TemplateRepository templates;
  setUp(() {
    h = Harness();
    templates = TemplateRepository(h.db);
  });
  tearDown(() => h.close());

  group('create', () {
    test('trims the name, keeps order, drops duplicates', () async {
      final id = await templates.create(
        name: '  Push  ',
        exerciseIds: [_bench, inclineId, _bench, _ohp],
      );
      final t = (await templates.template(id))!;
      expect(t.name, 'Push');
      expect(t.exercises.map((e) => e.id), [_bench, inclineId, _ohp]);
      expect(t.lastUsedAt, isNull);
    });

    test('validates name and exercises', () async {
      expect(
        () => templates.create(name: '   ', exerciseIds: [_bench]),
        throwsArgumentError,
      );
      expect(
        () => templates.create(name: 'x' * 41, exerciseIds: [_bench]),
        throwsArgumentError,
      );
      expect(
        () => templates.create(name: 'Empty', exerciseIds: []),
        throwsArgumentError,
      );
    });

    test('names are unique ignoring case', () async {
      await templates.create(name: 'Push', exerciseIds: [_bench]);
      expect(
        () => templates.create(name: 'push', exerciseIds: [_ohp]),
        throwsA(isA<DuplicateTemplateName>()),
      );
    });
  });

  group('update and delete', () {
    test('rename, reorder, add and remove in one save', () async {
      final id = await templates.create(
        name: 'Push',
        exerciseIds: [_bench, inclineId, _ohp],
      );
      await templates.update(
        id,
        name: 'Push A',
        exerciseIds: [_triceps, _ohp, _bench],
      );
      final t = (await templates.template(id))!;
      expect(t.name, 'Push A');
      expect(t.exercises.map((e) => e.id), [_triceps, _ohp, _bench]);
      final pending = await h.db.select(h.db.pendingDeletes).get();
      expect(
        pending.where((p) => p.tableNameValue == 'template_exercises'),
        hasLength(1),
      );
    });

    test('renaming to its own name in another case is allowed', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      await templates.update(id, name: 'PUSH', exerciseIds: [_bench]);
      expect((await templates.template(id))!.name, 'PUSH');
    });

    test('renaming to another template name is refused', () async {
      await templates.create(name: 'Push', exerciseIds: [_bench]);
      final id = await templates.create(name: 'Pull', exerciseIds: [latId]);
      expect(
        () => templates.update(id, name: 'push', exerciseIds: [latId]),
        throwsA(isA<DuplicateTemplateName>()),
      );
    });

    test('delete cascades and leaves workouts alone', () async {
      await h.plan();
      final (w, _) = await h.session([(20, 10), (20, 10), (22.5, 6)]);
      final id = await templates.saveFromWorkout(w, name: 'From workout');
      await templates.delete(id);
      expect(await templates.template(id), isNull);
      expect(await h.db.select(h.db.templateExercises).get(), isEmpty);
      expect(await h.workouts.workoutDetail(w), isNotNull);
      final pending = await h.db.select(h.db.pendingDeletes).get();
      expect(
        pending.where((p) => p.tableNameValue == 'templates').single.rowId,
        id,
      );
    });
  });

  group('list ordering', () {
    test('most recently used first, then newest', () async {
      final a = await templates.create(name: 'A', exerciseIds: [_bench]);
      h.advance();
      await templates.create(name: 'B', exerciseIds: [_bench]);
      h.advance();
      await templates.create(name: 'C', exerciseIds: [_bench]);
      expect((await templates.list()).map((t) => t.name), ['C', 'B', 'A']);
      h.advance();
      final w = await templates.startWorkout(a);
      await h.workouts.discardWorkout(w);
      expect((await templates.list()).map((t) => t.name), ['A', 'C', 'B']);
    });
  });

  group('start a workout (US1)', () {
    test('creates a live workout with the exercises in order', () async {
      final id = await templates.create(
        name: 'Push',
        exerciseIds: [_ohp, _bench, inclineId],
      );
      final w = await templates.startWorkout(id);
      final active = (await h.workouts.activeWorkout())!;
      expect(active.id, w);
      final detail = (await h.workouts.workoutDetail(w))!;
      expect(detail.exercises.map((e) => e.exercise.id), [
        _ohp,
        _bench,
        inclineId,
      ]);
      expect((await templates.template(id))!.lastUsedAt, isNotNull);
    });

    test('refused while another workout is active', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      await h.workouts.startWorkout();
      expect(() => templates.startWorkout(id), throwsStateError);
    });

    test('refused while a tracking session is in progress', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      await TrackingRepository(h.db)
          .start(typeId: 'running', startedAt: DateTime.utc(2026, 11, 14, 7));
      await expectLater(templates.startWorkout(id), throwsStateError);
      expect(await h.workouts.activeWorkout(), isNull);
    });

    test('progresses the template plan, not the exercise plan', () async {
      await h.plan();
      final id = await templates.create(
        name: 'Chest',
        exerciseIds: [inclineId],
      );
      final w = await templates.startWorkout(id);
      final we = (await h.workouts.workoutDetail(w))!.exercises.single.row.id;
      for (final (i, s) in [(20.0, 10), (20.0, 10), (22.5, 6)].indexed) {
        await h.workouts.logSet(we, setNo: i + 1, weight: s.$1, reps: s.$2);
      }
      await h.workouts.finishWorkout(w);
      expect(await h.base(), 20);
      expect(
        (await templates.template(id))!.plans[inclineId]!.baseWeight,
        22.5,
      );
    });
  });

  group('notes carry over (023 US1)', () {
    /// Starts template [id], writes [notes] per exercise id, logs one set on
    /// each so finishing keeps the workout, finishes. Returns the workout id.
    Future<String> templateSession(
      String id,
      Map<String, String?> notes, {
      bool finish = true,
    }) async {
      h.advance();
      final w = await templates.startWorkout(id);
      for (final e in (await h.workouts.workoutDetail(w))!.exercises) {
        await h.workouts.logSet(e.row.id, setNo: 1, weight: 20, reps: 10);
        if (notes.containsKey(e.exercise.id)) {
          await h.workouts.setExerciseNotes(e.row.id, notes[e.exercise.id]);
        }
      }
      if (finish) await h.workouts.finishWorkout(w);
      return w;
    }

    Future<Map<String, String?>> notesOf(String workoutId) async => {
      for (final e in (await h.workouts.workoutDetail(workoutId))!.exercises)
        e.exercise.id: e.row.notes,
    };

    test('each exercise gets its latest earlier note', () async {
      final id = await templates.create(
        name: 'Push',
        exerciseIds: [_bench, _ohp],
      );
      await templateSession(id, {_bench: 'seat 4', _ohp: 'strict'});
      await templateSession(id, {_bench: 'seat 5'});
      final w = await templateSession(id, {}, finish: false);
      expect(await notesOf(w), {_bench: 'seat 5', _ohp: 'strict'});
    });

    test('a session with an empty note does not erase an older note', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      await templateSession(id, {_bench: 'seat 4'});
      await templateSession(id, {_bench: '   '});
      await templateSession(id, {});
      final w = await templateSession(id, {}, finish: false);
      expect(await notesOf(w), {_bench: 'seat 4'});
    });

    test('ad-hoc and other-template notes are not carried over', () async {
      final push = await templates.create(name: 'Push', exerciseIds: [_bench]);
      final other = await templates.create(
        name: 'Other',
        exerciseIds: [_bench],
      );
      final (_, adHoc) = await h.session([(20, 10)], exerciseId: _bench);
      await h.workouts.setExerciseNotes(adHoc, 'ad-hoc note');
      await templateSession(other, {_bench: 'other template'});
      final w = await templateSession(push, {}, finish: false);
      expect(await notesOf(w), {_bench: null});
    });

    test('kept across template edits', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      await templateSession(id, {_bench: 'seat 4'});
      await templates.update(id, name: 'Push day', exerciseIds: [_ohp, _bench]);
      final w = await templateSession(id, {}, finish: false);
      expect(await notesOf(w), {_ohp: null, _bench: 'seat 4'});
    });

    test('editing the carried note leaves the earlier one', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      final first = await templateSession(id, {_bench: 'seat 4'});
      final w = await templateSession(id, {_bench: 'seat 6'}, finish: false);
      expect(await notesOf(w), {_bench: 'seat 6'});
      expect(await notesOf(first), {_bench: 'seat 4'});
    });

    test('a discarded live workout is not a source', () async {
      final id = await templates.create(name: 'Push', exerciseIds: [_bench]);
      final live = await templateSession(id, {_bench: 'draft'}, finish: false);
      await h.workouts.discardWorkout(live);
      final w = await templateSession(id, {}, finish: false);
      expect(await notesOf(w), {_bench: null});
    });
  });

  group('save from workout (US3)', () {
    test('copies exercises in workout order, distinct', () async {
      final w = await h.workouts.startWorkout();
      await h.workouts.addExercise(w.id, _ohp);
      await h.workouts.addExercise(w.id, _bench);
      await h.workouts.addExercise(w.id, _ohp);
      final id = await templates.saveFromWorkout(w.id, name: 'Upper A');
      final t = (await templates.template(id))!;
      expect(t.exercises.map((e) => e.id), [_ohp, _bench]);
      expect(await h.workouts.activeWorkout(), isNotNull); // untouched
    });

    test('an empty workout cannot be saved', () async {
      final w = await h.workouts.startWorkout();
      expect(
        () => templates.saveFromWorkout(w.id, name: 'Nothing'),
        throwsArgumentError,
      );
    });
  });

  test(
    'queues pending delete when removing an exercise from templates',
    () async {
      final keep = await templates.create(
        name: 'Push',
        exerciseIds: [_bench, inclineId],
      );
      final solo = await templates.create(
        name: 'Solo',
        exerciseIds: [inclineId],
      );
      final rows = await h.db.select(h.db.templateExercises).get();
      final inclineRows = rows.where((r) => r.exerciseId == inclineId);
      await templates.removeExercise(inclineId);
      final pending = await h.db.select(h.db.pendingDeletes).get();
      expect(
        pending
            .where((p) => p.tableNameValue == 'template_exercises')
            .map((p) => p.rowId)
            .toSet(),
        inclineRows.map((r) => r.id).toSet(),
      );
      expect(
        pending.where((p) => p.tableNameValue == 'templates').single.rowId,
        solo,
      );
      expect(await templates.template(keep), isNotNull);
    },
  );
}
