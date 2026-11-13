import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fitapp/data/db/seed_library.dart' as seed;
import 'package:fitapp/data/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    ExerciseState,
    Workouts,
    WorkoutExercises,
    Sets,
    PendingDeletes,
    Settings,
    Templates,
    TemplateExercises,
  ],
)
class AppDatabase extends _$AppDatabase {
  new(super.e, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Opens the on-device database file.
  factory open() => AppDatabase(driftDatabase(name: 'fitapp'));

  final DateTime Function() _clock;

  /// Current time in UTC (injectable for tests).
  DateTime now() => _clock().toUtc();

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      // Step by step; never drop user data.
      if (from < 2) {
        await m.createTable(templates);
        await m.createTable(templateExercises);
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await seedLibrary();
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS exercises_name_ci '
      'ON exercises (lower(name))',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS workouts_ended_at ON workouts (ended_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS workout_exercises_exercise '
      'ON workout_exercises (exercise_id, workout_id)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS templates_name_ci '
      'ON templates (lower(name))',
    );
  }

  /// Idempotent upsert of the built-in library. Refreshes names, groups,
  /// per-hand flags and increments; never touches custom exercises.
  Future<void> seedLibrary() => transaction(() async {
    final ts = now();
    for (final e in seed.seedLibrary) {
      await into(exercises).insert(
        ExercisesCompanion.insert(
          id: e.id,
          name: e.name,
          muscleGroup: Value(e.muscleGroup),
          isPerHand: e.perHand,
          defaultIncrement: e.increment,
          isCustom: false,
          updatedAt: ts,
          dirty: const Value(false),
        ),
        onConflict: DoUpdate(
          (_) => ExercisesCompanion(
            name: Value(e.name),
            muscleGroup: Value(e.muscleGroup),
            isPerHand: Value(e.perHand),
            defaultIncrement: Value(e.increment),
            isCustom: const Value(false),
          ),
        ),
      );
    }
  });
}
