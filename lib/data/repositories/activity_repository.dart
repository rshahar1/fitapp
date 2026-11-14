import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:uuid/uuid.dart';

/// Sport activities other than gym workouts (feature 006).
class ActivityRepository {
  new(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Logs an activity. Throws [ArgumentError] when invalid (see
  /// [validateActivity]).
  Future<String> create({
    required String typeId,
    required DateTime startedAt,
    int? durationMinutes,
    int? distanceMeters,
    String? notes,
  }) async {
    final now = _db.now();
    final v = validateActivity(
      typeId: typeId,
      startedAt: startedAt,
      now: now,
      durationMinutes: durationMinutes,
      distanceMeters: distanceMeters,
      notes: notes,
    );
    final id = _uuid.v4();
    await _db
        .into(_db.activities)
        .insert(
          ActivitiesCompanion.insert(
            id: id,
            typeId: v.typeId,
            startedAt: v.startedAt.toUtc(),
            durationMinutes: Value(v.durationMinutes),
            distanceMeters: Value(v.distanceMeters),
            notes: Value(v.notes),
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Replaces every field of an activity. An entry whose stored type is no
  /// longer in the registry may keep that type.
  Future<void> update(
    String id, {
    required String typeId,
    required DateTime startedAt,
    int? durationMinutes,
    int? distanceMeters,
    String? notes,
  }) => _db.transaction(() async {
    final existing = await activity(id);
    if (existing == null) throw StateError('Activity not found');
    final now = _db.now();
    final v = validateActivity(
      typeId: typeId,
      startedAt: startedAt,
      now: now,
      durationMinutes: durationMinutes,
      distanceMeters: distanceMeters,
      notes: notes,
      allowUnknownType: typeId == existing.typeId,
    );
    await (_db.update(_db.activities)..where((a) => a.id.equals(id))).write(
      ActivitiesCompanion(
        typeId: Value(v.typeId),
        startedAt: Value(v.startedAt.toUtc()),
        durationMinutes: Value(v.durationMinutes),
        distanceMeters: Value(v.distanceMeters),
        notes: Value(v.notes),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
  });

  /// Deletes an activity and queues the deletion for sync.
  Future<void> delete(String id) => _db.transaction(() async {
    await _db
        .into(_db.pendingDeletes)
        .insert(
          PendingDeletesCompanion.insert(
            tableNameValue: 'activities',
            rowId: id,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await (_db.delete(_db.activities)..where((a) => a.id.equals(id))).go();
  });

  Future<ActivityRow?> activity(String id) => (_db.select(
    _db.activities,
  )..where((a) => a.id.equals(id))).getSingleOrNull();

  SimpleSelectStatement<$ActivitiesTable, ActivityRow> _newestFirst() =>
      _db.select(_db.activities)..orderBy([
        (a) => OrderingTerm.desc(a.startedAt),
        (a) => OrderingTerm.desc(a.id),
      ]);

  /// All activities, newest first.
  Future<List<ActivityRow>> list() => _newestFirst().get();

  Stream<List<ActivityRow>> watchActivities() => _newestFirst().watch();
}
