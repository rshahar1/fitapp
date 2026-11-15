/// Reads what must be pushed and records what the server accepted
/// (data-model.md §6 step 3).
library;

import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_table.dart';

/// A row sent in a page, remembered so it is only marked clean if it did not
/// change while the push was in flight.
class _SentRow {
  new(this.table, this.key, this.storedUpdatedAt);

  final SyncTable table;
  final String key;

  /// `updated_at` exactly as stored locally when read.
  final Object? storedUpdatedAt;
}

/// One page to push plus what to acknowledge afterwards.
class PushPage {
  new(this.batch, this._rows, this._deletes, this._settingsStamp);

  final PushBatch batch;
  final List<_SentRow> _rows;

  /// `(localTable, serverTable, id)`.
  final List<(String, String, String)> _deletes;

  /// Local stamp of the settings sent in this page, if any.
  final DateTime? _settingsStamp;
}

class PushCollector {
  new(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  static const pageSize = 500;

  /// Everything pending, split into pages: deletes first (children first),
  /// then dirty rows in FK order, then settings.
  Future<List<PushPage>> collect({int pageSize = pageSize}) async {
    final pages = <PushPage>[];
    var deletes = <(String, String)>[];
    var deleteKeys = <(String, String, String)>[];
    var upserts = <String, List<RemoteRow>>{};
    var rows = <_SentRow>[];
    DateTime? settingsStamp;
    var size = 0;

    void flush() {
      if (size == 0) return;
      pages.add(
        PushPage(
          PushBatch(deletes: deletes, upserts: upserts),
          rows,
          deleteKeys,
          settingsStamp,
        ),
      );
      deletes = [];
      deleteKeys = [];
      upserts = {};
      rows = [];
      settingsStamp = null;
      size = 0;
    }

    // Deletes, children first (reverse FK order).
    final queued = await _db
        .customSelect('SELECT table_name, row_id FROM pending_deletes')
        .get();
    for (final table in syncTables.reversed.where((t) => t.deletable)) {
      for (final q in queued) {
        if (q.read<String>('table_name') != table.local) continue;
        final id = q.read<String>('row_id');
        deletes.add((table.server, id));
        deleteKeys.add((table.local, table.server, id));
        if (++size >= pageSize) flush();
      }
    }

    // Dirty rows, parents first.
    for (final table in syncTables) {
      final dirty = await _db
          .customSelect(
            'SELECT * FROM ${table.local} WHERE dirty = 1${table.where}',
          )
          .get();
      for (final r in dirty) {
        final data = r.data;
        final json = <String, Object?>{
          for (final c in table.columns) c.server: c.toJson(data[c.local]),
          updatedAtColumn: parseUtc(data['updated_at'] as Object)
              .toIso8601String(),
        };
        (upserts[table.server] ??= []).add(json);
        rows.add(
          _SentRow(table, data[table.localKey]! as String, data['updated_at']),
        );
        if (++size >= pageSize) flush();
      }
    }

    // Whitelisted settings.
    if (await _settings.syncedSettingsDirty()) {
      final stamp = await _settings.syncedSettingsUpdatedAt();
      if (stamp != null) {
        upserts[settingsTable] = [
          {
            'data': await _settings.syncedSettings(),
            updatedAtColumn: stamp.toIso8601String(),
          },
        ];
        settingsStamp = stamp;
        size++;
      }
    }
    flush();
    return pages;
  }

  /// Marks every row of [page] the server did not reject as pushed: removes
  /// sent deletes from the queue and clears `dirty` on rows unchanged since
  /// they were read (FR-018).
  Future<void> acknowledge(PushPage page, PushResult result) async {
    await _db.transaction(() async {
      for (final (local, server, id) in page._deletes) {
        if (result.rejected.contains((server, id))) continue;
        await _db.customStatement(
          'DELETE FROM pending_deletes WHERE table_name = ? AND row_id = ?',
          [local, id],
        );
      }
      for (final row in page._rows) {
        if (result.rejected.contains((row.table.server, row.key))) continue;
        await _db.customUpdate(
          'UPDATE ${row.table.local} SET dirty = 0 '
          'WHERE ${row.table.localKey} = ? AND updated_at = ?${row.table.where}',
          variables: [
            Variable<String>(row.key),
            _rawVariable(row.storedUpdatedAt),
          ],
          updates: {},
        );
      }
    });
    final stamp = page._settingsStamp;
    if (stamp != null && !result.rejected.any((r) => r.$1 == settingsTable)) {
      await _settings.markSyncedSettingsClean(stamp);
    }
  }

  static Variable<Object> _rawVariable(Object? v) => switch (v) {
    final String s => Variable<String>(s),
    final int i => Variable<int>(i),
    _ => throw StateError('unexpected updated_at value $v'),
  };
}
