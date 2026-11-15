/// Applies pulled server rows to the local database (data-model.md §6).
library;

import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_table.dart';
import 'package:fitapp/domain/sync_rules.dart';

class PullApplier {
  new(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  static const maxNameLength = 40;

  /// Per table, the server time of the first row skipped in this pull. The
  /// cursor is held just before it so the row is retried on the next sync
  /// (e.g. a parent not yet here, or a built-in exercise this app version
  /// does not ship yet) instead of being lost.
  final _holds = <String, DateTime>{};

  /// Call before pulling the pages of [serverTable] in a cycle.
  void startTable(String serverTable) => _holds.remove(serverTable);

  /// Stored pull cursor of a server table.
  Future<DateTime?> cursor(String serverTable) async {
    final row = await _db
        .customSelect(
          'SELECT cursor FROM sync_state WHERE table_name = ?',
          variables: [Variable<String>(serverTable)],
        )
        .getSingleOrNull();
    final Object? v = row?.data['cursor'];
    return v == null ? null : parseUtc(v);
  }

  /// Forgets all cursors so the next pull reads everything (restore).
  Future<void> resetCursors() => _db.customStatement('DELETE FROM sync_state');

  /// Applies one page of [serverTable] in one transaction and advances its
  /// cursor. Returns how many rows changed local data.
  Future<int> applyPage(String serverTable, List<RemoteRow> rows) async {
    if (rows.isEmpty) return 0;
    var changed = 0;
    final touched = <String>{};
    if (serverTable == settingsTable) {
      for (final r in rows) {
        if (r['deleted_at'] != null) continue;
        await _settings.applySyncedSettings(
          Map<String, Object?>.from(r['data']! as Map),
          parseUtc(r[updatedAtColumn]!),
        );
        changed++;
      }
      await _advance(serverTable, rows);
      return changed;
    }
    final table = syncTableByServer(serverTable);
    await _db.transaction(() async {
      for (final r in rows) {
        try {
          if (await _applyRow(table, r, touched)) changed++;
        } on Object catch (e) {
          // E.g. a child whose parent is missing here: skip it for now and
          // hold the cursor so it is retried.
          _holds.putIfAbsent(
            serverTable,
            () => parseUtc(r['server_updated_at']!),
          );
          developer.log(
            'sync: skipped ${table.server} ${r[table.key]}: $e',
            name: 'fitapp.sync',
          );
        }
      }
      await _advance(serverTable, rows);
    });
    if (touched.isNotEmpty) {
      _db.notifyUpdates({for (final t in touched) TableUpdate(t)});
    }
    return changed;
  }

  Future<void> _advance(String serverTable, List<RemoteRow> rows) async {
    var max = await cursor(serverTable);
    for (final r in rows) {
      final at = parseUtc(r['server_updated_at']!);
      if (max == null || at.isAfter(max)) max = at;
    }
    final hold = _holds[serverTable];
    if (hold != null) max = hold.subtract(const Duration(microseconds: 1));
    await _db.customStatement(
      'INSERT INTO sync_state (table_name, cursor) VALUES (?, ?) '
      'ON CONFLICT(table_name) DO UPDATE SET cursor = excluded.cursor',
      [serverTable, max!.toIso8601String()],
    );
  }

  Future<bool> _applyRow(
    SyncTable table,
    RemoteRow r,
    Set<String> touched,
  ) async {
    final key = r[table.key]! as String;
    final incomingAt = parseUtc(r[updatedAtColumn]!);
    final local = await _db
        .customSelect(
          'SELECT dirty, updated_at FROM ${table.local} '
          'WHERE ${table.localKey} = ?${table.where}',
          variables: [Variable<String>(key)],
        )
        .getSingleOrNull();
    final pendingDelete =
        table.deletable &&
        await _exists(
          'SELECT 1 FROM pending_deletes WHERE table_name = ? AND row_id = ?',
          [table.local, key],
        );

    var action = resolveIncoming(
      incomingDeleted: r['deleted_at'] != null,
      incomingUpdatedAt: incomingAt,
      local: local == null
          ? null
          : LocalRowState(
              dirty: local.data['dirty'] == 1,
              updatedAt: parseUtc(local.data['updated_at'] as Object),
            ),
      locallyPendingDelete: pendingDelete,
    );
    // Exercises are never removed by sync (history references them), and
    // built-ins only exist when the app ships them.
    if (action == IncomingAction.deleteLocal && !table.deletable) {
      action = IncomingAction.ignore;
    }
    if (action == IncomingAction.insert && !table.insertable) {
      action = IncomingAction.ignore;
    }

    switch (action) {
      case IncomingAction.ignore:
      case IncomingAction.keepLocal:
        return false;
      case IncomingAction.deleteLocal:
        await _db.customStatement(
          'DELETE FROM ${table.local} WHERE ${table.localKey} = ?',
          [key],
        );
        await _db.customStatement(
          'DELETE FROM pending_deletes WHERE table_name = ? AND row_id = ?',
          [table.local, key],
        );
        touched.add(table.local);
        return true;
      case IncomingAction.insert:
      case IncomingAction.overwrite:
        break;
    }

    final values = <String, Object?>{
      for (final c in table.columns) c.local: c.toLocal(r[c.server]),
      'updated_at': incomingAt.toIso8601String(),
      'dirty': 0,
    };

    if (table.slot != null &&
        !await _resolveSlot(table, key, values, incomingAt, touched)) {
      return false;
    }
    if (table.uniqueName) await _resolveName(table, key, values, touched);

    if (action == IncomingAction.insert) {
      final all = {...table.localInsertDefaults, ...values};
      await _db.customStatement(
        'INSERT INTO ${table.local} (${all.keys.join(', ')}) '
        'VALUES (${List.filled(all.length, '?').join(', ')})',
        all.values.toList(),
      );
    } else {
      final cols = values.keys.where((c) => c != table.localKey).toList();
      await _db.customStatement(
        'UPDATE ${table.local} SET ${cols.map((c) => '$c = ?').join(', ')} '
        'WHERE ${table.localKey} = ?${table.where}',
        [for (final c in cols) values[c], key],
      );
    }
    touched.add(table.local);
    return true;
  }

  /// Two rows in one unique slot: keeps the winner (research R7). Returns
  /// false when the incoming row loses and must not be applied.
  Future<bool> _resolveSlot(
    SyncTable table,
    String key,
    Map<String, Object?> values,
    DateTime incomingAt,
    Set<String> touched,
  ) async {
    final cols = table.slot!.columns;
    final other = await _db
        .customSelect(
          'SELECT ${table.localKey} AS k, updated_at FROM ${table.local} '
          'WHERE ${cols.map((c) => '$c = ?').join(' AND ')} '
          'AND ${table.localKey} != ?',
          variables: [
            for (final c in cols) Variable(values[c]),
            Variable<String>(key),
          ],
        )
        .getSingleOrNull();
    if (other == null) return true;
    final otherKey = other.data['k']! as String;
    final keepIncoming = incomingWinsCollision(
      incomingUpdatedAt: incomingAt,
      incomingId: key,
      localUpdatedAt: parseUtc(other.data['updated_at'] as Object),
      localId: otherKey,
    );
    if (!keepIncoming) return false;
    await _db.customStatement(
      'DELETE FROM ${table.local} WHERE ${table.localKey} = ?',
      [otherKey],
    );
    await _db.customStatement(
      'INSERT OR IGNORE INTO pending_deletes (table_name, row_id) '
      'VALUES (?, ?)',
      [table.local, otherKey],
    );
    touched.add(table.local);
    return true;
  }

  /// Name taken by another local row (merge of two devices, FR-023): renames
  /// the local row, or the incoming one when the local row is a built-in.
  Future<void> _resolveName(
    SyncTable table,
    String key,
    Map<String, Object?> values,
    Set<String> touched,
  ) async {
    final name = values['name']! as String;
    final clash = await _db
        .customSelect(
          'SELECT * FROM ${table.local} '
          'WHERE lower(name) = lower(?) AND id != ?',
          variables: [Variable<String>(name), Variable<String>(key)],
        )
        .getSingleOrNull();
    if (clash == null) return;
    final taken = {
      for (final r
          in await _db.customSelect('SELECT name FROM ${table.local}').get())
        (r.data['name']! as String).toLowerCase(),
    };
    final renamed = suffixName(name, taken);
    final now = _db.now().toIso8601String();
    final clashIsBuiltIn = clash.data['is_custom'] == 0;
    if (clashIsBuiltIn) {
      values['name'] = renamed;
      values['dirty'] = 1;
      values['updated_at'] = now;
    } else {
      await _db.customStatement(
        'UPDATE ${table.local} SET name = ?, dirty = 1, updated_at = ? '
        'WHERE id = ?',
        [renamed, now, clash.data['id']],
      );
      touched.add(table.local);
    }
  }

  Future<bool> _exists(String sql, List<Object> args) async =>
      (await _db
          .customSelect(sql, variables: [for (final a in args) Variable(a)])
          .getSingleOrNull()) !=
      null;
}
