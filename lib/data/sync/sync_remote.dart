/// The backend as the sync engine sees it (contracts/sync-backend.md).
library;

import 'package:meta/meta.dart';

/// A row as JSON with server column names.
typedef RemoteRow = Map<String, Object?>;

/// One `sync_push` call: deletes (children first) and upserts per server table.
@immutable
class PushBatch {
  const new({this.deletes = const [], this.upserts = const {}});

  /// `(serverTable, id)` pairs.
  final List<(String, String)> deletes;

  /// Server table → rows (without user_id, deleted_at, server_updated_at).
  final Map<String, List<RemoteRow>> upserts;

  int get size =>
      deletes.length + upserts.values.fold(0, (n, rows) => n + rows.length);

  bool get isEmpty => size == 0;

  Map<String, Object?> toJson() => {
    'deletes': [
      for (final (table, id) in deletes) {'table': table, 'id': id},
    ],
    'upserts': upserts,
  };
}

/// Server answer to a push.
@immutable
class PushResult {
  const new({required this.applied, this.rejected = const {}});

  factory fromJson(Map<String, Object?> json) => PushResult(
    applied: (json['applied']! as num).toInt(),
    rejected: {
      for (final r
          in (json['rejected'] as List? ?? const [])
              .cast<Map<String, Object?>>())
        (r['table']! as String, (r['id'] as String?) ?? ''),
    },
  );

  final int applied;

  /// `(serverTable, key)` of rows the server refused; they stay pending.
  final Set<(String, String)> rejected;
}

/// Transport failure (network, auth, server error): nothing was applied.
class SyncTransportException implements Exception {
  new(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncTransportException: $message';
}

/// Backend operations used by sync. Implementations throw
/// [SyncTransportException] on transport failures.
abstract interface class SyncRemote {
  Future<PushResult> push(PushBatch batch);

  /// Rows of [table] changed after `(since, afterKey)` in
  /// `(server_updated_at, key)` order, at most [limit]. Tombstones included.
  Future<List<RemoteRow>> pullPage(
    String table, {
    required DateTime since,
    String? afterKey,
    int limit = 1000,
  });

  /// Whether the signed-in account already holds any live workouts,
  /// activities or templates.
  Future<bool> hasCloudData();
}
