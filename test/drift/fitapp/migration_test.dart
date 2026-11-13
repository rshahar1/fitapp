// dart format width=80
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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
}
