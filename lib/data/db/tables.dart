import 'package:drift/drift.dart';

/// Columns shared by every syncable table (Phase 2 sync, PRD §8).
mixin SyncColumns on Table {
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

@DataClassName('ExerciseRow')
class Exercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get muscleGroup => text().nullable()();
  BoolColumn get isPerHand => boolean()();
  RealColumn get defaultIncrement => real()();
  BoolColumn get isCustom => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The current plan per exercise.
@DataClassName('PlanRow')
class ExerciseState extends Table with SyncColumns {
  TextColumn get exerciseId => text().references(Exercises, #id)();
  RealColumn get baseWeight => real()();
  IntColumn get targetReps => integer()();
  IntColumn get targetSets => integer()();
  RealColumn get increment => real()();

  /// NULL means "use the default rest time from settings".
  IntColumn get restSeconds => integer().nullable()();

  @override
  String get tableName => 'exercise_state';

  @override
  Set<Column<Object>> get primaryKey => {exerciseId};
}

@DataClassName('WorkoutRow')
class Workouts extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();

  /// NULL while the workout is in progress.
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('WorkoutExerciseRow')
class WorkoutExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get workoutId =>
      text().references(Workouts, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().nullable()();

  // Snapshot of the plan this session was evaluated with (written on finish).
  RealColumn get planBaseWeight => real().nullable()();
  IntColumn get planTargetReps => integer().nullable()();
  IntColumn get planTargetSets => integer().nullable()();
  RealColumn get planIncrement => real().nullable()();
  RealColumn get resultBaseWeight => real().nullable()();

  /// The template exercise this session came from (feature 005). NULL for
  /// ad-hoc sessions (they use the exercise's own plan). Deliberately not a
  /// foreign key: after the template exercise is deleted the id dangles and
  /// the session never rewrites any plan.
  TextColumn get templateExerciseId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SetRow')
class Sets extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get workoutExerciseId =>
      text().references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setNo => integer()();
  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  BoolColumn get isOverload => boolean()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {workoutExerciseId, setNo},
  ];
}

/// Delete queue for future sync.
@DataClassName('PendingDeleteRow')
class PendingDeletes extends Table {
  TextColumn get tableNameValue => text().named('table_name')();
  TextColumn get rowId => text()();

  @override
  Set<Column<Object>> get primaryKey => {tableNameValue, rowId};
}

/// Local-only key/value settings.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// A user-created workout template (feature 003).
@DataClassName('TemplateRow')
class Templates extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// An exercise in a template, in order.
@DataClassName('TemplateExerciseRow')
class TemplateExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(Templates, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get position => integer()();

  // This template's own plan for the exercise (feature 005). All four core
  // values are set together, or all NULL ("no plan yet").
  RealColumn get baseWeight => real().nullable()();
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetSets => integer().nullable()();
  RealColumn get increment => real().nullable()();

  /// NULL means "use the default rest time from settings".
  IntColumn get restSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {templateId, exerciseId},
  ];
}

/// A logged sport activity other than a gym workout (feature 006). The type
/// is an id from the code registry in `lib/domain/activity_types.dart`.
@DataClassName('ActivityRow')
class Activities extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get typeId => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMinutes => integer().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
