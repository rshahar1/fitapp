/// Mapping between local drift tables and server tables for cloud sync
/// (feature 013, specs/013-cloud-sync/data-model.md §2).
///
/// Sync works on raw rows (`Map<String, Object?>` with server column names and
/// JSON-ready values) so one tested code path serves every table.
library;

import 'package:meta/meta.dart';

/// How a column's value is stored locally (drift, dates as text) and sent to
/// the server (JSON).
enum ColKind { text, integer, real, boolean, dateTime }

@immutable
class SyncColumn {
  const new(this.server, this.kind, {String? local}) : local = local ?? server;

  /// Column name on the server.
  final String server;

  /// Column name in the local table.
  final String local;

  final ColKind kind;

  /// Local SQLite value → JSON value.
  Object? toJson(Object? v) {
    if (v == null) return null;
    return switch (kind) {
      ColKind.boolean => v is bool ? v : v != 0,
      ColKind.dateTime => _iso(v),
      ColKind.real => (v as num).toDouble(),
      ColKind.integer => (v as num).toInt(),
      ColKind.text => v,
    };
  }

  /// JSON value → local SQLite value.
  Object? toLocal(Object? v) {
    if (v == null) return null;
    return switch (kind) {
      ColKind.boolean => (v == true || v == 1) ? 1 : 0,
      ColKind.dateTime => parseUtc(v).toIso8601String(),
      ColKind.real => (v as num).toDouble(),
      ColKind.integer => (v as num).toInt(),
      ColKind.text => v,
    };
  }

  static String _iso(Object v) => parseUtc(v).toIso8601String();
}

/// Parses a stored or received timestamp as UTC.
DateTime parseUtc(Object v) => switch (v) {
  final DateTime d => d.toUtc(),
  final String s => DateTime.parse(s).toUtc(),
  // drift may store dates as unix seconds when not in text mode.
  final int i => DateTime.fromMillisecondsSinceEpoch(i * 1000, isUtc: true),
  _ => throw ArgumentError.value(v, 'timestamp'),
};

/// A child-side unique slot that two devices can fill with different rows
/// (resolved on pull, research R7).
@immutable
class UniqueSlot {
  const new(this.columns);

  /// Local column names that together must be unique.
  final List<String> columns;
}

/// One synced server table and where its rows live locally.
@immutable
class SyncTable {
  const new({
    required this.server,
    required this.local,
    required this.columns,
    this.key = 'id',
    this.localKey = 'id',
    this.localFilter,
    this.localInsertDefaults = const {},
    this.deletable = true,
    this.insertable = true,
    this.uniqueName = false,
    this.slot,
  });

  /// Server table name.
  final String server;

  /// Local table name.
  final String local;

  /// Synced columns except `updated_at` (handled by the engine), including
  /// the key.
  final List<SyncColumn> columns;

  /// Key column on the server (besides the implicit `user_id`).
  final String key;

  /// Key column locally.
  final String localKey;

  /// SQL condition selecting this table's rows when the local table is shared
  /// (exercises: custom vs built-in).
  final String? localFilter;

  /// Extra local columns set on insert (e.g. `is_custom = 1`).
  final Map<String, Object?> localInsertDefaults;

  /// Whether local deletes of this table are pushed as tombstones.
  final bool deletable;

  /// Whether pulled rows may create local rows (false for built-in overrides:
  /// the built-in library ships with the app).
  final bool insertable;

  /// Names unique ignoring case locally (`name` column); clashes are renamed.
  final bool uniqueName;

  /// Unique slot to resolve on pull, if any.
  final UniqueSlot? slot;

  String get where => localFilter == null ? '' : ' AND ($localFilter)';
}

const _updatedAt = 'updated_at';

/// Server column carrying the client time of the last change.
const updatedAtColumn = _updatedAt;

/// Synced tables in FK order (parents first). Pull and push both follow it;
/// deletes are pushed in reverse.
const syncTables = <SyncTable>[
  SyncTable(
    server: 'custom_exercises',
    local: 'exercises',
    localFilter: 'is_custom = 1',
    localInsertDefaults: {'is_custom': 1},
    deletable: false,
    uniqueName: true,
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('name', ColKind.text),
      SyncColumn('muscle_group', ColKind.text),
      SyncColumn('is_per_hand', ColKind.boolean),
      SyncColumn('default_increment', ColKind.real),
      SyncColumn('archived_at', ColKind.dateTime, local: 'deleted_at'),
    ],
  ),
  SyncTable(
    server: 'exercise_overrides',
    local: 'exercises',
    key: 'exercise_id',
    localFilter: 'is_custom = 0',
    deletable: false,
    insertable: false,
    columns: [
      SyncColumn('exercise_id', ColKind.text, local: 'id'),
      SyncColumn('archived_at', ColKind.dateTime, local: 'deleted_at'),
    ],
  ),
  SyncTable(
    server: 'exercise_state',
    local: 'exercise_state',
    key: 'exercise_id',
    localKey: 'exercise_id',
    deletable: false,
    columns: [
      SyncColumn('exercise_id', ColKind.text),
      SyncColumn('base_weight', ColKind.real),
      SyncColumn('target_reps', ColKind.integer),
      SyncColumn('target_sets', ColKind.integer),
      SyncColumn('increment', ColKind.real),
      SyncColumn('rest_seconds', ColKind.integer),
    ],
  ),
  SyncTable(
    server: 'templates',
    local: 'templates',
    uniqueName: true,
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('name', ColKind.text),
      SyncColumn('created_at', ColKind.dateTime),
      SyncColumn('last_used_at', ColKind.dateTime),
    ],
  ),
  SyncTable(
    server: 'template_exercises',
    local: 'template_exercises',
    slot: UniqueSlot(['template_id', 'exercise_id']),
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('template_id', ColKind.text),
      SyncColumn('exercise_id', ColKind.text),
      SyncColumn('position', ColKind.integer),
      SyncColumn('base_weight', ColKind.real),
      SyncColumn('target_reps', ColKind.integer),
      SyncColumn('target_sets', ColKind.integer),
      SyncColumn('increment', ColKind.real),
      SyncColumn('rest_seconds', ColKind.integer),
    ],
  ),
  SyncTable(
    server: 'workouts',
    local: 'workouts',
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('name', ColKind.text),
      SyncColumn('started_at', ColKind.dateTime),
      SyncColumn('ended_at', ColKind.dateTime),
      SyncColumn('notes', ColKind.text),
    ],
  ),
  SyncTable(
    server: 'workout_exercises',
    local: 'workout_exercises',
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('workout_id', ColKind.text),
      SyncColumn('exercise_id', ColKind.text),
      SyncColumn('position', ColKind.integer),
      SyncColumn('notes', ColKind.text),
      SyncColumn('template_exercise_id', ColKind.text),
      SyncColumn('plan_base_weight', ColKind.real),
      SyncColumn('plan_target_reps', ColKind.integer),
      SyncColumn('plan_target_sets', ColKind.integer),
      SyncColumn('plan_increment', ColKind.real),
      SyncColumn('result_base_weight', ColKind.real),
    ],
  ),
  SyncTable(
    server: 'sets',
    local: 'sets',
    slot: UniqueSlot(['workout_exercise_id', 'set_no']),
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('workout_exercise_id', ColKind.text),
      SyncColumn('set_no', ColKind.integer),
      SyncColumn('weight', ColKind.real),
      SyncColumn('reps', ColKind.integer),
      SyncColumn('is_overload', ColKind.boolean),
      SyncColumn('completed_at', ColKind.dateTime),
    ],
  ),
  SyncTable(
    server: 'activities',
    local: 'activities',
    columns: [
      SyncColumn('id', ColKind.text),
      SyncColumn('type_id', ColKind.text),
      SyncColumn('started_at', ColKind.dateTime),
      SyncColumn('duration_minutes', ColKind.integer),
      SyncColumn('distance_meters', ColKind.integer),
      SyncColumn('notes', ColKind.text),
      SyncColumn('source', ColKind.text),
      SyncColumn('moving_seconds', ColKind.integer),
      SyncColumn('elevation_gain_meters', ColKind.integer),
      SyncColumn('route', ColKind.text),
      SyncColumn('splits', ColKind.text),
    ],
  ),
];

/// Server table holding the whitelisted settings (one row per user).
const settingsTable = 'user_settings';

/// Every server table pulled, in order.
List<String> get pulledTables => [
  for (final t in syncTables) t.server,
  settingsTable,
];

SyncTable syncTableByServer(String server) =>
    syncTables.firstWhere((t) => t.server == server);

/// The table a local `pending_deletes.table_name` maps to.
SyncTable? syncTableForDelete(String localTable) {
  for (final t in syncTables) {
    if (t.deletable && t.local == localTable) return t;
  }
  return null;
}
