/// Which account this phone's data belongs to, and what signing in should do
/// (data-model.md §5, FR-006).
library;

import 'package:drift/drift.dart';
import 'package:fitapp/data/db/app_database.dart';

/// What to do after a successful sign-in.
enum SignInDecision {
  /// Bound to this account already: just sync.
  resume,

  /// Nothing here and nothing in the cloud: bind.
  nothingToDo,

  /// Fresh phone, account has a backup: bind and restore.
  restore,

  /// History here, empty account: bind and back up everything.
  firstBackup,

  /// History on both sides: ask the user to merge.
  askMerge,

  /// This phone belongs to another account: ask before replacing.
  askReplace,
}

class DeviceBinding {
  new(this._db);

  final AppDatabase _db;

  static const _kUserId = 'sync.user_id';
  static const _kUserEmail = 'sync.user_email';
  static const _kLastSuccess = 'sync.last_success_at';

  /// Settings keys removed when the phone's data is wiped.
  static const _wipedSettings = [
    'default_rest_seconds',
    'rest_alert_haptic',
    'rest_alert_sound',
    'active_rest_started_at',
    'active_rest_target_seconds',
    'active_rest_exercise',
  ];

  Future<String?> boundUserId() => _get(_kUserId);

  /// Email of the bound account, for messages (may be null).
  Future<String?> boundEmail() => _get(_kUserEmail);

  Future<void> bind(String userId, {String? email}) async {
    await _put(_kUserId, userId);
    if (email == null) {
      await _remove(_kUserEmail);
    } else {
      await _put(_kUserEmail, email);
    }
  }

  Future<void> unbind() async {
    await _remove(_kUserId);
    await _remove(_kUserEmail);
  }

  Stream<String?> watchBoundEmail() => _db
      .customSelect(
        'SELECT value FROM settings WHERE key = ?',
        variables: [const Variable<String>(_kUserEmail)],
        readsFrom: {_db.settings},
      )
      .watchSingleOrNull()
      .map((r) => r?.read<String>('value'));

  Future<DateTime?> lastSuccessAt() async {
    final v = await _get(_kLastSuccess);
    return v == null ? null : DateTime.parse(v).toUtc();
  }

  Future<void> setLastSuccessAt(DateTime at) =>
      _put(_kLastSuccess, at.toUtc().toIso8601String());

  Stream<DateTime?> watchLastSuccessAt() => _db
      .customSelect(
        'SELECT value FROM settings WHERE key = ?',
        variables: [const Variable<String>(_kLastSuccess)],
        readsFrom: {_db.settings},
      )
      .watchSingleOrNull()
      .map((r) => r == null ? null : DateTime.parse(r.read<String>('value')));

  /// Any user data worth keeping on this phone.
  Future<bool> hasLocalHistory() async {
    final row = await _db.customSelect('''
      SELECT EXISTS (SELECT 1 FROM workouts)
          OR EXISTS (SELECT 1 FROM activities)
          OR EXISTS (SELECT 1 FROM templates)
          OR EXISTS (SELECT 1 FROM exercise_state)
          OR EXISTS (SELECT 1 FROM exercises WHERE is_custom = 1 OR dirty = 1)
        AS has
    ''').getSingle();
    return row.data['has'] == 1;
  }

  Future<SignInDecision> decide(
    String userId, {
    required Future<bool> Function() cloudHasData,
  }) async {
    final bound = await boundUserId();
    if (bound == userId) return SignInDecision.resume;
    if (bound != null) return SignInDecision.askReplace;
    final local = await hasLocalHistory();
    final cloud = await cloudHasData();
    return switch ((local, cloud)) {
      (false, false) => SignInDecision.nothingToDo,
      (false, true) => SignInDecision.restore,
      (true, false) => SignInDecision.firstBackup,
      (true, true) => SignInDecision.askMerge,
    };
  }

  /// Erases all user data from the phone and unbinds it; the built-in
  /// library stays (US5, data-model.md §5).
  Future<void> wipeUserData() async {
    await _db.transaction(() async {
      for (final sql in const [
        'DELETE FROM sets',
        'DELETE FROM workout_exercises',
        'DELETE FROM workouts',
        'DELETE FROM template_exercises',
        'DELETE FROM templates',
        'DELETE FROM activities',
        'DELETE FROM exercise_state',
        'DELETE FROM track_points',
        'DELETE FROM tracking_sessions',
        'DELETE FROM pending_deletes',
        'DELETE FROM sync_state',
        'DELETE FROM exercises WHERE is_custom = 1',
        'UPDATE exercises SET deleted_at = NULL, dirty = 0 WHERE is_custom = 0',
        "DELETE FROM settings WHERE key LIKE 'sync.%'",
      ]) {
        await _db.customStatement(sql);
      }
      for (final k in _wipedSettings) {
        await _remove(k);
      }
    });
    _db.notifyUpdates({
      for (final t in _db.allTables) TableUpdate(t.actualTableName),
    });
  }

  Future<String?> _get(String key) async =>
      (await _db
              .customSelect(
                'SELECT value FROM settings WHERE key = ?',
                variables: [Variable<String>(key)],
              )
              .getSingleOrNull())
          ?.read<String>('value');

  Future<void> _put(String key, String value) async {
    await _db.customStatement(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
    _db.notifyUpdates({const TableUpdate('settings')});
  }

  Future<void> _remove(String key) async {
    await _db.customStatement('DELETE FROM settings WHERE key = ?', [key]);
    _db.notifyUpdates({const TableUpdate('settings')});
  }
}
