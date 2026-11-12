import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/db/seed_library.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Harness h;
  setUp(() => h = Harness());
  tearDown(() => h.close());

  test('library is seeded with 16 exercises and fixed UUIDs', () async {
    final rows = await h.db.select(h.db.exercises).get();
    expect(rows, hasLength(16));
    final ids = rows.map((e) => e.id).toSet();
    expect(ids, contains('00000000-0000-4000-8000-000000000001'));
    expect(ids, contains('00000000-0000-4000-8000-000000000010'));
    final incline = rows.firstWhere((e) => e.id == inclineId);
    expect(incline.name, 'Incline Dumbbell Bench Press');
    expect(incline.isPerHand, isTrue);
    expect(incline.defaultIncrement, 2.5);
    expect(rows.every((e) => !e.isCustom && !e.dirty), isTrue);
  });

  test('seeding is idempotent and refreshes library fields', () async {
    await (h.db.update(h.db.exercises)..where((e) => e.id.equals(inclineId)))
        .write(const ExercisesCompanion(name: Value('Old name')));
    await h.db.seedLibrary();
    await h.db.seedLibrary();
    final rows = await h.db.select(h.db.exercises).get();
    expect(rows, hasLength(seedLibrary.length));
    expect(
      rows.firstWhere((e) => e.id == inclineId).name,
      'Incline Dumbbell Bench Press',
    );
  });

  test('seeding never touches custom exercises', () async {
    final custom = await h.exercises.createCustom(
      name: 'Hack Squat',
      perHand: false,
      increment: 5,
    );
    await h.db.seedLibrary();
    final again = await h.exercises.exercise(custom.id);
    expect(again!.name, 'Hack Squat');
    expect(again.isCustom, isTrue);
  });

  test('foreign keys are on', () async {
    final r = await h.db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(r.data.values.first, 1);
  });

  test(
    'reopening an existing database keeps data (migration is safe)',
    () async {
      // A file-less shared in-memory DB cannot be reopened, so use a temp file.
      final dir = await Directory.systemTemp.createTemp('fitapp_test');
      final file = File('${dir.path}/db.sqlite');
      var db = AppDatabase(DatabaseConnection(NativeDatabase(file)));
      await db
          .into(db.settings)
          .insert(SettingsCompanion.insert(key: 'k', value: 'v'));
      await db.close();
      db = AppDatabase(DatabaseConnection(NativeDatabase(file)));
      expect((await db.select(db.settings).get()).single.value, 'v');
      expect(await db.select(db.exercises).get(), hasLength(16));
      await db.close();
      await dir.delete(recursive: true);
    },
  );
}
