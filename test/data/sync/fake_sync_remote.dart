import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_table.dart';

/// In-memory backend for one account, mirroring the server rules proven by
/// supabase/tests/*.sql: last-writer-wins, deletes win, tombstone cascade,
/// late children of tombstoned parents, per-row rejection, pull cursors.
class FakeSyncRemote implements SyncRemote {
  new({this.userId = 'user-a'});

  final String userId;

  /// Server table → key → row (with deleted_at, server_updated_at).
  final tables = <String, Map<String, Map<String, Object?>>>{
    for (final t in pulledTables) t: {},
  };

  /// Monotonic server clock (1 ms per write).
  DateTime _clock = DateTime.utc(2026, 11, 14);

  /// Throws a transport error on the next call when set.
  bool failNext = false;

  /// Runs before a push is applied (simulates edits while in flight).
  Future<void> Function()? beforePush;

  /// Rows (`table`, key) the server rejects as invalid.
  final rejectKeys = <(String, String)>{};

  int pushCalls = 0;

  static const _parents = {
    'template_exercises': ('templates', 'template_id'),
    'workout_exercises': ('workouts', 'workout_id'),
    'sets': ('workout_exercises', 'workout_exercise_id'),
  };

  DateTime _tick() => _clock = _clock.add(const Duration(milliseconds: 1));

  String _keyCol(String table) =>
      table == settingsTable ? 'user_id' : syncTableByServer(table).key;

  void _checkTransport() {
    if (failNext) {
      failNext = false;
      throw SyncTransportException('offline');
    }
  }

  /// Live (not tombstoned) rows of [table].
  List<Map<String, Object?>> live(String table) => [
    for (final r in tables[table]!.values)
      if (r['deleted_at'] == null) r,
  ];

  @override
  Future<PushResult> push(PushBatch batch) async {
    _checkTransport();
    pushCalls++;
    await beforePush?.call();
    var applied = 0;
    final rejected = <(String, String)>{};
    for (final (table, id) in batch.deletes) {
      final row = tables[table]![id];
      if (row != null && row['deleted_at'] == null) _tombstone(table, id);
      applied++;
    }
    for (final table in pulledTables) {
      for (final incoming in batch.upserts[table] ?? const <RemoteRow>[]) {
        final key = table == settingsTable
            ? userId
            : incoming[_keyCol(table)]! as String;
        if (rejectKeys.contains((table, key)) ||
            !_parentExists(table, incoming)) {
          rejected.add((table, table == settingsTable ? '' : key));
          continue;
        }
        _upsert(table, key, incoming);
        applied++;
      }
    }
    return PushResult(applied: applied, rejected: rejected);
  }

  bool _parentExists(String table, RemoteRow row) {
    final parent = _parents[table];
    if (parent == null) return true;
    return tables[parent.$1]!.containsKey(row[parent.$2]);
  }

  void _upsert(String table, String key, RemoteRow incoming) {
    final existing = tables[table]![key];
    final row = <String, Object?>{
      ...incoming,
      if (table == settingsTable) 'user_id': userId,
    };
    final at = parseUtc(incoming[updatedAtColumn]!);
    if (existing != null) {
      if (existing['deleted_at'] != null) return; // delete wins
      if (at.isBefore(parseUtc(existing[updatedAtColumn]!))) return;
      row['deleted_at'] = null;
    } else {
      final parent = _parents[table];
      final parentRow = parent == null
          ? null
          : tables[parent.$1]![row[parent.$2]];
      row['deleted_at'] = parentRow?['deleted_at'];
    }
    row['server_updated_at'] = _tick().toIso8601String();
    tables[table]![key] = row;
  }

  void _tombstone(String table, String id) {
    final now = _tick().toIso8601String();
    tables[table]![id]!
      ..['deleted_at'] = now
      ..[updatedAtColumn] = now
      ..['server_updated_at'] = now;
    for (final MapEntry(key: child, value: (parent, fk)) in _parents.entries) {
      if (parent != table) continue;
      for (final c in tables[child]!.values.toList()) {
        if (c[fk] == id && c['deleted_at'] == null) {
          _tombstone(child, c[_keyCol(child)]! as String);
        }
      }
    }
  }

  @override
  Future<List<RemoteRow>> pullPage(
    String table, {
    required DateTime since,
    String? afterKey,
    int limit = 1000,
  }) async {
    _checkTransport();
    final keyCol = _keyCol(table);
    final rows =
        tables[table]!.values.where((r) {
          final at = parseUtc(r['server_updated_at']!);
          if (at.isAfter(since)) {
            return afterKey == null ||
                !at.isAtSameMomentAs(since) ||
                (r[keyCol]! as String).compareTo(afterKey) > 0;
          }
          return afterKey != null &&
              at.isAtSameMomentAs(since) &&
              (r[keyCol]! as String).compareTo(afterKey) > 0;
        }).toList()..sort((a, b) {
          final c = parseUtc(a['server_updated_at']!)
              .compareTo(parseUtc(b['server_updated_at']!));
          return c != 0
              ? c
              : (a[keyCol]! as String).compareTo(b[keyCol]! as String);
        });
    return [for (final r in rows.take(limit)) Map<String, Object?>.from(r)];
  }

  @override
  Future<bool> hasCloudData() async {
    _checkTransport();
    return live('workouts').isNotEmpty ||
        live('activities').isNotEmpty ||
        live('templates').isNotEmpty;
  }
}
