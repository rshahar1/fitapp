// dart format width=80
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 keeps workouts, sets and settings', () async {
    const ts = '2026-11-12T18:00:00.000Z';
    const incline = '00000000-0000-4000-8000-000000000002';
    const exercise = v1.ExercisesData(
      updatedAt: ts,
      dirty: 0,
      id: incline,
      name: 'Incline Dumbbell Bench Press',
      muscleGroup: 'Chest',
      isPerHand: 1,
      defaultIncrement: 2.5,
      isCustom: 0,
    );
    const workout = v1.WorkoutsData(
      updatedAt: ts,
      dirty: 1,
      id: 'w1',
      startedAt: ts,
      endedAt: '2026-11-12T19:00:00.000Z',
    );
    const we = v1.WorkoutExercisesData(
      updatedAt: ts,
      dirty: 1,
      id: 'we1',
      workoutId: 'w1',
      exerciseId: incline,
      position: 0,
      planBaseWeight: 20,
      planTargetReps: 10,
      planTargetSets: 3,
      planIncrement: 2.5,
      resultBaseWeight: 22.5,
    );
    const set = v1.SetsData(
      updatedAt: ts,
      dirty: 1,
      id: 's1',
      workoutExerciseId: 'we1',
      setNo: 1,
      weight: 20,
      reps: 10,
      isOverload: 0,
      completedAt: ts,
    );
    const setting = v1.SettingsData(key: 'default_rest_seconds', value: '90');

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.exercises, [exercise])
          ..insertAll(oldDb.workouts, [workout])
          ..insertAll(oldDb.workoutExercises, [we])
          ..insertAll(oldDb.sets, [set])
          ..insertAll(oldDb.settings, [setting]);
      },
      validateItems: (newDb) async {
        final workouts = await newDb.select(newDb.workouts).get();
        expect(workouts.single.id, 'w1');
        expect(workouts.single.endedAt, '2026-11-12T19:00:00.000Z');
        final wes = await newDb.select(newDb.workoutExercises).get();
        expect(wes.single.resultBaseWeight, 22.5);
        final sets = await newDb.select(newDb.sets).get();
        expect((sets.single.weight, sets.single.reps), (20.0, 10));
        final settings = await newDb.select(newDb.settings).get();
        expect(settings.single.value, '90');
        expect(await newDb.select(newDb.templates).get(), isEmpty);
        expect(await newDb.select(newDb.templateExercises).get(), isEmpty);
      },
    );
  });

  test('migration from v2 to v3 seeds template plans and keeps data', () async {
    const ts = '2026-11-13T18:00:00.000Z';
    const incline = '00000000-0000-4000-8000-000000000002';
    const fly = '00000000-0000-4000-8000-000000000003';
    v2.ExercisesData ex(String id, String name) => v2.ExercisesData(
      updatedAt: ts,
      dirty: 0,
      id: id,
      name: name,
      muscleGroup: 'Chest',
      isPerHand: 0,
      defaultIncrement: 2.5,
      isCustom: 0,
    );
    const plan = v2.ExerciseStateData(
      updatedAt: ts,
      dirty: 1,
      exerciseId: incline,
      baseWeight: 20,
      targetReps: 10,
      targetSets: 3,
      increment: 2.5,
      restSeconds: 90,
    );
    const template = v2.TemplatesData(
      updatedAt: ts,
      dirty: 1,
      id: 't1',
      name: 'Chest',
      createdAt: ts,
    );
    v2.TemplateExercisesData te(String id, String exerciseId, int pos) =>
        v2.TemplateExercisesData(
          updatedAt: ts,
          dirty: 0,
          id: id,
          templateId: 't1',
          exerciseId: exerciseId,
          position: pos,
        );
    const workout = v2.WorkoutsData(
      updatedAt: ts,
      dirty: 1,
      id: 'w1',
      startedAt: ts,
      endedAt: '2026-11-13T19:00:00.000Z',
    );
    const we = v2.WorkoutExercisesData(
      updatedAt: ts,
      dirty: 1,
      id: 'we1',
      workoutId: 'w1',
      exerciseId: incline,
      position: 0,
      planBaseWeight: 20,
      planTargetReps: 10,
      planTargetSets: 3,
      planIncrement: 2.5,
      resultBaseWeight: 22.5,
    );
    const set = v2.SetsData(
      updatedAt: ts,
      dirty: 1,
      id: 's1',
      workoutExerciseId: 'we1',
      setNo: 1,
      weight: 20,
      reps: 10,
      isOverload: 0,
      completedAt: ts,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.exercises, [
            ex(incline, 'Incline Dumbbell Bench Press'),
            ex(fly, 'Cable Fly'),
          ])
          ..insertAll(oldDb.exerciseState, [plan])
          ..insertAll(oldDb.templates, [template])
          ..insertAll(oldDb.templateExercises, [
            te('te1', incline, 0),
            te('te2', fly, 1),
          ])
          ..insertAll(oldDb.workouts, [workout])
          ..insertAll(oldDb.workoutExercises, [we])
          ..insertAll(oldDb.sets, [set]);
      },
      validateItems: (newDb) async {
        final tes = {
          for (final r in await newDb.select(newDb.templateExercises).get())
            r.id: r,
        };
        final seeded = tes['te1']!;
        expect(
          (
            seeded.baseWeight,
            seeded.targetReps,
            seeded.targetSets,
            seeded.increment,
            seeded.restSeconds,
          ),
          (20.0, 10, 3, 2.5, 90),
        );
        expect(seeded.dirty, 1);
        final noPlan = tes['te2']!;
        expect(noPlan.baseWeight, isNull);
        expect(noPlan.targetReps, isNull);
        final wes = await newDb.select(newDb.workoutExercises).get();
        expect(wes.single.resultBaseWeight, 22.5);
        expect(wes.single.templateExerciseId, isNull);
        final sets = await newDb.select(newDb.sets).get();
        expect((sets.single.weight, sets.single.reps), (20.0, 10));
        final plans = await newDb.select(newDb.exerciseState).get();
        expect(plans.single.baseWeight, 20);
        expect(
          (await newDb.select(newDb.templates).get()).single.name,
          'Chest',
        );
      },
    );
  });

  test('migration from v3 to v4 adds activities and keeps data', () async {
    const ts = '2026-11-13T18:00:00.000Z';
    const fly = '00000000-0000-4000-8000-000000000003';
    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch
          ..insertAll(oldDb.exercises, [
            const v3.ExercisesData(
              updatedAt: ts,
              dirty: 0,
              id: fly,
              name: 'Cable Fly',
              muscleGroup: 'Chest',
              isPerHand: 0,
              defaultIncrement: 2.5,
              isCustom: 0,
            ),
          ])
          ..insertAll(oldDb.templates, [
            const v3.TemplatesData(
              updatedAt: ts,
              dirty: 1,
              id: 't1',
              name: 'Chest',
              createdAt: ts,
            ),
          ])
          ..insertAll(oldDb.templateExercises, [
            const v3.TemplateExercisesData(
              updatedAt: ts,
              dirty: 1,
              id: 'te1',
              templateId: 't1',
              exerciseId: fly,
              position: 0,
              baseWeight: 22.5,
              targetReps: 10,
              targetSets: 3,
              increment: 2.5,
            ),
          ])
          ..insertAll(oldDb.workouts, [
            const v3.WorkoutsData(
              updatedAt: ts,
              dirty: 1,
              id: 'w1',
              startedAt: ts,
              endedAt: ts,
            ),
          ])
          ..insertAll(oldDb.workoutExercises, [
            const v3.WorkoutExercisesData(
              updatedAt: ts,
              dirty: 1,
              id: 'we1',
              workoutId: 'w1',
              exerciseId: fly,
              position: 0,
              templateExerciseId: 'te1',
            ),
          ]);
      },
      validateItems: (newDb) async {
        final te = await newDb.select(newDb.templateExercises).getSingle();
        expect(te.baseWeight, 22.5);
        final we = await newDb.select(newDb.workoutExercises).getSingle();
        expect(we.templateExerciseId, 'te1');
        expect(await newDb.select(newDb.workouts).get(), hasLength(1));
        expect(await newDb.select(newDb.activities).get(), isEmpty);
      },
    );
  });

  test('migration from v4 to v5 keeps activities with null distance', () async {
    const ts = '2026-11-14T18:00:00.000Z';
    await verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 5,
      createOld: v4.DatabaseAtV4.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.activities, [
          const v4.ActivitiesData(
            updatedAt: ts,
            dirty: 1,
            id: 'a1',
            typeId: 'running',
            startedAt: ts,
            durationMinutes: 30,
            notes: 'easy',
          ),
        ]);
      },
      validateItems: (newDb) async {
        final a = await newDb.select(newDb.activities).getSingle();
        expect(a.typeId, 'running');
        expect(a.durationMinutes, 30);
        expect(a.notes, 'easy');
        expect(a.distanceMeters, isNull);
      },
    );
  });

  test(
    'migration from v5 to v6 marks activities manual, adds tracking tables',
    () async {
      const ts = '2026-11-14T18:00:00.000Z';
      await verifier.testWithDataIntegrity(
        oldVersion: 5,
        newVersion: 6,
        createOld: v5.DatabaseAtV5.new,
        createNew: v6.DatabaseAtV6.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.activities, [
            const v5.ActivitiesData(
              updatedAt: ts,
              dirty: 1,
              id: 'a1',
              typeId: 'running',
              startedAt: ts,
              durationMinutes: 30,
              distanceMeters: 5000,
              notes: 'easy',
            ),
          ]);
        },
        validateItems: (newDb) async {
          final a = await newDb.select(newDb.activities).getSingle();
          expect(a.typeId, 'running');
          expect(a.durationMinutes, 30);
          expect(a.distanceMeters, 5000);
          expect(a.notes, 'easy');
          expect(a.source, 'manual');
          expect(a.movingSeconds, isNull);
          expect(a.elevationGainMeters, isNull);
          expect(a.route, isNull);
          expect(a.splits, isNull);
          expect(await newDb.select(newDb.trackingSessions).get(), isEmpty);
          expect(await newDb.select(newDb.trackPoints).get(), isEmpty);
        },
      );
    },
  );
}
