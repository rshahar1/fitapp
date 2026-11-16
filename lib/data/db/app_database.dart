import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:fitapp/data/db/app_database.steps.dart';
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
    Activities,
    TrackingSessions,
    TrackPoints,
    SyncState,
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
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      // Step by step against the versioned schemas; never drop user data.
      await stepByStep(
        from1To2: (m, schema) async {
          await m.createTable(schema.templates);
          await m.createTable(schema.templateExercises);
        },
        from2To3: (m, schema) async {
          // Feature 005: per-template plans + session link.
          final te = schema.templateExercises;
          for (final c in <GeneratedColumn<Object>>[
            te.baseWeight,
            te.targetReps,
            te.targetSets,
            te.increment,
            te.restSeconds,
          ]) {
            await m.addColumn(te, c);
          }
          await m.addColumn(
            schema.workoutExercises,
            schema.workoutExercises.templateExerciseId,
          );
          await _seedTemplatePlans();
        },
        from3To4: (m, schema) async {
          // Feature 006: sport activities.
          await m.createTable(schema.activities);
        },
        from4To5: (m, schema) async {
          // Feature 009: manual distance for running / cycling.
          await m.addColumn(
            schema.activities,
            schema.activities.distanceMeters,
          );
        },
        from5To6: (m, schema) async {
          // Feature 010: live GPS tracking.
          await m.createTable(schema.trackingSessions);
          await m.createTable(schema.trackPoints);
          final a = schema.activities;
          for (final c in <GeneratedColumn<Object>>[
            a.source,
            a.movingSeconds,
            a.elevationGainMeters,
            a.route,
            a.splits,
          ]) {
            await m.addColumn(a, c);
          }
        },
        from6To7: (m, schema) async {
          // Feature 012: soft-deleted exercises.
          await m.addColumn(schema.exercises, schema.exercises.deletedAt);
        },
        from7To8: (m, schema) async {
          // Feature 013: cloud sync pull cursors.
          await m.createTable(schema.syncState);
        },
        from8To9: (m, schema) async {
          // Feature 017: snowboarding metrics of tracked activities.
          final a = schema.activities;
          for (final c in [
            a.verticalDropMeters,
            a.runCount,
            a.maxSpeedMps,
            a.liftSeconds,
            a.restSeconds,
            a.segments,
          ]) {
            await m.addColumn(a, c);
          }
        },
      )(m, from, to);
      await _createIndexes(version: to);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await seedLibrary();
    },
  );

  /// Copies each exercise's current plan into template exercises that have
  /// no plan yet (migration to v3).
  Future<void> _seedTemplatePlans() async {
    const sub =
        'FROM exercise_state es '
        'WHERE es.exercise_id = template_exercises.exercise_id';
    await customStatement(
      'UPDATE template_exercises SET '
      'base_weight = (SELECT base_weight $sub), '
      'target_reps = (SELECT target_reps $sub), '
      'target_sets = (SELECT target_sets $sub), '
      'increment = (SELECT increment $sub), '
      'rest_seconds = (SELECT rest_seconds $sub), '
      'dirty = 1 '
      'WHERE base_weight IS NULL AND EXISTS (SELECT 1 $sub)',
    );
  }

  /// Creates the indexes that exist at schema [version] (default: latest).
  Future<void> _createIndexes({int? version}) async {
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
    if ((version ?? schemaVersion) < 3) return;
    await customStatement(
      'CREATE INDEX IF NOT EXISTS workout_exercises_template_exercise '
      'ON workout_exercises (template_exercise_id)',
    );
    if ((version ?? schemaVersion) < 4) return;
    await customStatement(
      'CREATE INDEX IF NOT EXISTS activities_started_at '
      'ON activities (started_at)',
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
