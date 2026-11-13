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

  Future<void> setDefaultRestSeconds(int seconds) =>
      _put(_kDefaultRest, normalizeRest(seconds).toString());

  Stream<RestAlertPrefs> watchAlertPrefs() =>
      _watchAll().map(_prefs).distinct();

  Future<RestAlertPrefs> alertPrefs() async => _prefs(await _all());

  Future<void> setAlertPrefs(RestAlertPrefs prefs) => _db.transaction(() async {
    await _put(_kHaptic, prefs.haptic.toString());
    await _put(_kSound, prefs.sound.toString());
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
}
