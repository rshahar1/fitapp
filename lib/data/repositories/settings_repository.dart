import 'package:fitapp/data/db/app_database.dart';
import 'package:meta/meta.dart';

/// Rest-timer alert preferences.
@immutable
class RestAlertPrefs {
  const new({this.haptic = true, this.sound = true});

  final bool haptic;
  final bool sound;

  RestAlertPrefs copyWith({bool? haptic, bool? sound}) =>
      RestAlertPrefs(haptic: haptic ?? this.haptic, sound: sound ?? this.sound);

  @override
  bool operator ==(Object other) =>
      other is RestAlertPrefs && other.haptic == haptic && other.sound == sound;

  @override
  int get hashCode => Object.hash(haptic, sound);
}

/// A running rest timer, persisted so it survives process death.
@immutable
class ActiveRest {
  const new({
    required this.startedAt,
    required this.targetSeconds,
    this.exerciseName,
  });

  final DateTime startedAt;
  final int targetSeconds;

  /// Shown in the rest notification; null for timers saved before 002.
  final String? exerciseName;

  DateTime get endsAt => startedAt.add(Duration(seconds: targetSeconds));

  @override
  bool operator ==(Object other) =>
      other is ActiveRest &&
      other.startedAt == startedAt &&
      other.targetSeconds == targetSeconds &&
      other.exerciseName == exerciseName;

  @override
  int get hashCode => Object.hash(startedAt, targetSeconds, exerciseName);
}

/// Local key/value settings (PRD §5.7).
class SettingsRepository {
  new(this._db);

  final AppDatabase _db;

  static const defaultRestSeconds = 60;
  static const minRestSeconds = 10;
  static const maxRestSeconds = 600;
  static const restStepSeconds = 5;

  static const _kDefaultRest = 'default_rest_seconds';
  static const _kHaptic = 'rest_alert_haptic';
  static const _kSound = 'rest_alert_sound';
  static const _kRestStart = 'active_rest_started_at';
  static const _kRestTarget = 'active_rest_target_seconds';
  static const _kRestExercise = 'active_rest_exercise';
  static const _kPermissionAsked = 'notif_permission_asked';
  static const _kStepsEnabled = 'steps_enabled';
  static const _kStepsIntroShown = 'steps_intro_shown';
  static const _kSyncUpdatedAt = 'sync.settings_updated_at';
  static const _kSyncDirty = 'sync.settings_dirty';

  /// Clamps to 10 s..10 min and snaps to 5 s steps.
  static int normalizeRest(int seconds) {
    final snapped = (seconds / restStepSeconds).round() * restStepSeconds;
    return snapped.clamp(minRestSeconds, maxRestSeconds);
  }

  Stream<Map<String, String>> _watchAll() => _db
      .select(_db.settings)
      .watch()
      .map((rows) => {for (final r in rows) r.key: r.value});

  Future<Map<String, String>> _all() async => {
    for (final r in await _db.select(_db.settings).get()) r.key: r.value,
  };

  Future<void> _put(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> _remove(String key) =>
      (_db.delete(_db.settings)..where((s) => s.key.equals(key))).go();

  static int _rest(Map<String, String> m) =>
      int.tryParse(m[_kDefaultRest] ?? '') ?? defaultRestSeconds;

  static RestAlertPrefs _prefs(Map<String, String> m) => RestAlertPrefs(
    haptic: m[_kHaptic] != 'false',
    sound: m[_kSound] != 'false',
  );

  Stream<int> watchDefaultRestSeconds() => _watchAll().map(_rest).distinct();

  Future<int> defaultRest() async => _rest(await _all());

  Future<void> setDefaultRestSeconds(int seconds) => _db.transaction(() async {
    await _put(_kDefaultRest, normalizeRest(seconds).toString());
    await _stamp();
  });

  Stream<RestAlertPrefs> watchAlertPrefs() =>
      _watchAll().map(_prefs).distinct();

  Future<RestAlertPrefs> alertPrefs() async => _prefs(await _all());

  Future<void> setAlertPrefs(RestAlertPrefs prefs) => _db.transaction(() async {
    await _put(_kHaptic, prefs.haptic.toString());
    await _put(_kSound, prefs.sound.toString());
    await _stamp();
  });

  Future<ActiveRest?> readActiveRest() async {
    final m = await _all();
    final start = DateTime.tryParse(m[_kRestStart] ?? '');
    final target = int.tryParse(m[_kRestTarget] ?? '');
    if (start == null || target == null) return null;
    return ActiveRest(
      startedAt: start.toUtc(),
      targetSeconds: target,
      exerciseName: m[_kRestExercise],
    );
  }

  Future<void> writeActiveRest(ActiveRest? rest) => _db.transaction(() async {
    if (rest == null) {
      await _remove(_kRestStart);
      await _remove(_kRestTarget);
      await _remove(_kRestExercise);
    } else {
      await _put(_kRestStart, rest.startedAt.toUtc().toIso8601String());
      await _put(_kRestTarget, rest.targetSeconds.toString());
      final name = rest.exerciseName;
      if (name == null) {
        await _remove(_kRestExercise);
      } else {
        await _put(_kRestExercise, name);
      }
    }
  });

  /// Whether the automatic notification-permission prompt was already shown.
  Future<bool> notificationPermissionAsked() async =>
      (await _all())[_kPermissionAsked] == 'true';

  Future<void> markNotificationPermissionAsked() =>
      _put(_kPermissionAsked, 'true');

  /// Reads a free-form local flag (not synced); null when unset.
  Future<String?> readFlag(String key) async => (await _all())[key];

  /// Stores a free-form local flag (not synced).
  Future<void> writeFlag(String key, String value) => _put(key, value);

  // ---- Daily steps (feature 014): device-local, never synced -------------

  static bool _stepsEnabled(Map<String, String> m) =>
      m[_kStepsEnabled] != 'false';

  Stream<bool> watchStepsEnabled() => _watchAll().map(_stepsEnabled).distinct();

  Future<void> setStepsEnabled(bool enabled) =>
      _put(_kStepsEnabled, enabled.toString());

  Future<bool> stepsIntroShown() async =>
      (await _all())[_kStepsIntroShown] == 'true';

  Future<void> markStepsIntroShown() => _put(_kStepsIntroShown, 'true');

  // ---- Cloud sync (feature 013): whitelisted settings --------------------

  /// Marks the synced settings as locally changed (call inside the write's
  /// transaction).
  Future<void> _stamp() async {
    await _put(_kSyncUpdatedAt, _db.now().toIso8601String());
    await _put(_kSyncDirty, '1');
  }

  /// The whitelisted settings that exist, typed.
  Future<Map<String, Object?>> syncedSettings() async {
    final m = await _all();
    final rest = int.tryParse(m[_kDefaultRest] ?? '');
    return {
      _kDefaultRest: ?rest,
      if (m[_kHaptic] != null) _kHaptic: m[_kHaptic] != 'false',
      if (m[_kSound] != null) _kSound: m[_kSound] != 'false',
    };
  }

  Future<DateTime?> syncedSettingsUpdatedAt() async {
    final v = (await _all())[_kSyncUpdatedAt];
    return v == null ? null : DateTime.tryParse(v)?.toUtc();
  }

  Future<bool> syncedSettingsDirty() async =>
      (await _all())[_kSyncDirty] == '1';

  /// Clears the dirty flag unless the settings changed again after
  /// [updatedAtSent] was read.
  Future<void> markSyncedSettingsClean(DateTime updatedAtSent) =>
      _db.transaction(() async {
        final current = await syncedSettingsUpdatedAt();
        if (current == updatedAtSent.toUtc()) await _put(_kSyncDirty, '0');
      });

  /// Applies settings pulled from the cloud without marking them dirty.
  /// Ignored when local edits are pending and newer than [updatedAt].
  Future<void> applySyncedSettings(
    Map<String, Object?> data,
    DateTime updatedAt,
  ) => _db.transaction(() async {
    final localAt = await syncedSettingsUpdatedAt();
    if (await syncedSettingsDirty() &&
        localAt != null &&
        localAt.isAfter(updatedAt.toUtc())) {
      return;
    }
    final rest = data[_kDefaultRest];
    if (rest is int) await _put(_kDefaultRest, normalizeRest(rest).toString());
    final haptic = data[_kHaptic];
    if (haptic is bool) await _put(_kHaptic, haptic.toString());
    final sound = data[_kSound];
    if (sound is bool) await _put(_kSound, sound.toString());
    await _put(_kSyncUpdatedAt, updatedAt.toUtc().toIso8601String());
  });
}
