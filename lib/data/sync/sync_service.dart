/// Runs sync cycles: pull, then push (data-model.md §6). Never throws to
/// callers and never shows UI (FR-002).
library;

import 'dart:async';
import 'dart:developer' as developer;

import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/sync/device_binding.dart';
import 'package:fitapp/data/sync/pull_applier.dart';
import 'package:fitapp/data/sync/push_collector.dart';
import 'package:fitapp/data/sync/sync_remote.dart';
import 'package:fitapp/data/sync/sync_table.dart';
import 'package:fitapp/domain/sync_rules.dart';
import 'package:meta/meta.dart';

enum SyncOutcome {
  /// Everything pulled and pushed.
  ok,

  /// Done, but the server rejected some rows (they stay pending).
  partial,

  /// Transport or unexpected error; local pending state is unchanged.
  failed,

  /// Not signed in, or the phone is bound to another account.
  skipped,
}

enum SyncPhase { idle, syncing, restoring }

@immutable
class SyncStatus {
  const new({
    this.phase = SyncPhase.idle,
    this.restoredRows = 0,
    this.lastOutcome,
  });

  final SyncPhase phase;

  /// Rows applied so far by a running restore.
  final int restoredRows;
  final SyncOutcome? lastOutcome;
}

class SyncService {
  new({
    required AppDatabase db,
    required this._remote,
    required SettingsRepository settings,
    required this._binding,
    required this._currentUserId,
    this._pullPageSize = 1000,
    this._pushPageSize = PushCollector.pageSize,
  }) : _db = db,
       _pull = PullApplier(db, settings),
       _push = PushCollector(db, settings);

  final AppDatabase _db;
  final SyncRemote _remote;
  final DeviceBinding _binding;
  final String? Function() _currentUserId;
  final int _pullPageSize;
  final int _pushPageSize;
  final PullApplier _pull;
  final PushCollector _push;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();
  Future<SyncOutcome>? _running;
  bool _rerun = false;

  SyncStatus get status => _current;

  Stream<SyncStatus> watchStatus() => _status.stream;

  /// Runs a cycle, or joins the running one and schedules one more run so
  /// changes made meanwhile are pushed too (FR-014).
  Future<SyncOutcome> syncNow() {
    final running = _running;
    if (running != null) {
      _rerun = true;
      return running;
    }
    return _running = _loop(restore: false);
  }

  /// Pulls the whole account again (new or wiped phone, FR-022), then pushes.
  /// Resumable: progress is kept per page.
  Future<SyncOutcome> restore() async {
    // Claim the single-flight slot synchronously after the running cycle, so
    // no other cycle can start in between.
    for (var running = _running; running != null; running = _running) {
      await running;
    }
    final run = _running = _loop(restore: true);
    return await run;
  }

  Future<SyncOutcome> _loop({required bool restore}) async {
    try {
      if (restore) await _pull.resetCursors();
      var outcome = await _cycle(restore: restore);
      while (_rerun && outcome != SyncOutcome.failed) {
        _rerun = false;
        outcome = await _cycle(restore: false);
      }
      return outcome;
    } finally {
      _rerun = false;
      _running = null;
    }
  }

  Future<SyncOutcome> _cycle({required bool restore}) async {
    final userId = _currentUserId();
    if (userId == null || await _binding.boundUserId() != userId) {
      return _emit(const SyncStatus(lastOutcome: SyncOutcome.skipped));
    }
    var restored = 0;
    _emit(SyncStatus(phase: restore ? SyncPhase.restoring : SyncPhase.syncing));
    try {
      for (final table in pulledTables) {
        _pull.startTable(table);
        DateTime? since = pullSince(await _pull.cursor(table));
        String? afterKey;
        while (true) {
          final rows = await _remote.pullPage(
            table,
            since: since!,
            afterKey: afterKey,
            limit: _pullPageSize,
          );
          restored += await _pull.applyPage(table, rows);
          if (restore) {
            _emit(
              SyncStatus(phase: SyncPhase.restoring, restoredRows: restored),
            );
          }
          if (rows.length < _pullPageSize) break;
          final last = rows.last;
          since = parseUtc(last['server_updated_at']!);
          afterKey = _keyOf(table, last);
        }
      }

      var rejected = false;
      for (final page in await _push.collect(pageSize: _pushPageSize)) {
        final result = await _remote.push(page.batch);
        await _push.acknowledge(page, result);
        rejected |= result.rejected.isNotEmpty;
      }

      await _binding.setLastSuccessAt(_db.now());
      return _emit(
        SyncStatus(
          lastOutcome: rejected ? SyncOutcome.partial : SyncOutcome.ok,
        ),
      );
    } on Object catch (e, st) {
      developer.log(
        'sync failed',
        name: 'fitapp.sync',
        error: e,
        stackTrace: st,
      );
      return _emit(const SyncStatus(lastOutcome: SyncOutcome.failed));
    }
  }

  static String? _keyOf(String table, RemoteRow row) => table == settingsTable
      ? row['user_id'] as String?
      : row[syncTableByServer(table).key] as String?;

  SyncOutcome _emit(SyncStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
    return s.lastOutcome ?? SyncOutcome.ok;
  }

  Future<void> dispose() => _status.close();
}
