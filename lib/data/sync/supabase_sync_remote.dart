/// [SyncRemote] over Supabase (contracts/sync-backend.md).
library;

import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_table.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncRemote implements SyncRemote {
  new(this._client);

  final SupabaseClient _client;

  @override
  Future<PushResult> push(PushBatch batch) => _guard(() async {
    final res = await _client.rpc<Object?>(
      'sync_push',
      params: {'payload': batch.toJson()},
    );
    return PushResult.fromJson(Map<String, Object?>.from(res! as Map));
  });

  @override
  Future<List<RemoteRow>> pullPage(
    String table, {
    required DateTime since,
    String? afterKey,
    int limit = 1000,
  }) => _guard(() async {
    final key = table == settingsTable
        ? 'user_id'
        : syncTableByServer(table).key;
    final at = since.toUtc().toIso8601String();
    var q = _client.from(table).select();
    q = afterKey == null
        ? q.gt('server_updated_at', at)
        : q.or(
            'server_updated_at.gt.$at,'
            'and(server_updated_at.eq.$at,$key.gt.$afterKey)',
          );
    final rows = await q
        .order('server_updated_at', ascending: true)
        .order(key, ascending: true)
        .limit(limit);
    return [for (final r in rows) Map<String, Object?>.from(r)];
  });

  @override
  Future<bool> hasCloudData() => _guard(() async {
    for (final table in const ['workouts', 'activities', 'templates']) {
      final rows = await _client
          .from(table)
          .select('id')
          .isFilter('deleted_at', null)
          .limit(1);
      if (rows.isNotEmpty) return true;
    }
    return false;
  });

  /// Every failure of the backend call is a transport failure for sync:
  /// nothing was applied and the cycle retries later.
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on SyncTransportException {
      rethrow;
    } on Object catch (e) {
      throw SyncTransportException(e.toString(), e);
    }
  }
}
