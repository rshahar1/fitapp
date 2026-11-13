import 'dart:async';
import 'dart:developer' as developer;

import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The running rest timer (null when none). Time is always derived from the
/// stored start timestamp, never from a ticking counter, so it stays correct
/// when the app is backgrounded or killed (PRD §5.3).
///
/// Alert rules (specs/002-rest-alerts/contracts/rest-alerts.md):
/// - foreground: an in-app alarm vibrates / chimes once at 0;
/// - background: the end time is handed to the OS as a single notification,
///   scheduled on [onBackground] and cancelled on [onForeground];
/// - any new timer, dismiss or finish cancels the previous alert.
class RestTimerController extends Notifier<ActiveRest?> {
  Timer? _alarm;

  /// Whether the current timer already alerted (or must not alert anymore).
  bool _alerted = false;
  bool _inBackground = false;

  @override
  ActiveRest? build() {
    ref
      ..onDispose(() => _alarm?.cancel())
      ..listen(alertPrefsProvider, (previous, next) {
        // New Sound/Vibrate settings apply to an alert not fired yet.
        if (previous?.value != null && next.value != previous!.value) {
          if (_inBackground) unawaited(_scheduleOs());
        }
      });
    unawaited(_restore());
    return null;
  }

  DateTime _now() => ref.read(clockProvider)().toUtc();

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  RestAlerts get _alerts => ref.read(restAlertsProvider);

  Future<void> _restore() async {
    final saved = await _settings.readActiveRest();
    if (saved == null || state != null) return;
    state = saved;
    if (remaining(saved) > Duration.zero) {
      _alerted = false;
      _arm(saved);
    } else {
      // Already overtime after a restart: never alert late.
      _alerted = true;
    }
  }

  /// Time left; negative means overtime.
  Duration remaining([ActiveRest? rest]) {
    final r = rest ?? state;
    if (r == null) return Duration.zero;
    return r.endsAt.difference(_now());
  }

  /// Starts (or restarts) the countdown.
  Future<void> start(int targetSeconds, {String? exerciseName}) async {
    final rest = ActiveRest(
      startedAt: _now(),
      targetSeconds: targetSeconds,
      exerciseName: exerciseName,
    );
    state = rest;
    _alerted = false;
    _arm(rest);
    await _settings.writeActiveRest(rest);
    if (_inBackground) {
      await _scheduleOs();
    } else {
      // A previous timer's pending notification must never fire.
      await _safe(_alerts.cancel);
    }
    await _askPermissionOnce();
  }

  /// Starts with the exercise's own rest time or the global default.
  Future<void> startFor({
    int? exerciseRestSeconds,
    String? exerciseName,
  }) async {
    final seconds = exerciseRestSeconds ?? await _settings.defaultRest();
    await start(seconds, exerciseName: exerciseName);
  }

  /// Stops the timer (pill tapped, workout finished or discarded).
  Future<void> dismiss() async {
    _alarm?.cancel();
    _alerted = false;
    state = null;
    await _safe(_alerts.cancel);
    await _settings.writeActiveRest(null);
  }

  /// The app went to the background: hand the end time to the OS.
  Future<void> onBackground() async {
    _inBackground = true;
    await _scheduleOs();
  }

  /// The app is visible again: the in-app alarm takes over.
  Future<void> onForeground() async {
    _inBackground = false;
    await _safe(_alerts.cancel);
    if (state != null && remaining() <= Duration.zero) _alerted = true;
  }

  void _arm(ActiveRest rest) {
    _alarm?.cancel();
    final left = remaining(rest);
    _alarm = Timer(left.isNegative ? Duration.zero : left, () async {
      if (state != rest || _alerted) return;
      _alerted = true;
      // In the background the OS notification is the alert.
      if (_inBackground) return;
      final prefs = await _settings.alertPrefs();
      if (prefs.haptic) ref.read(hapticsProvider).warning();
      if (prefs.sound) await _safe(_alerts.playChime);
    });
  }

  Future<void> _scheduleOs() async {
    final rest = state;
    if (rest == null || _alerted || remaining(rest) <= Duration.zero) return;
    final prefs = await _settings.alertPrefs();
    await _safe(
      () => _alerts.schedule(
        at: rest.endsAt,
        exerciseName: rest.exerciseName ?? 'Workout',
        sound: prefs.sound,
        vibrate: prefs.haptic,
      ),
    );
  }

  Future<void> _askPermissionOnce() async {
    if (await _settings.notificationPermissionAsked()) return;
    await _settings.markNotificationPermissionAsked();
    await _safe(_alerts.requestNotificationPermission);
  }

  Future<void> _safe(Future<Object?> Function() call) async {
    try {
      await call();
    } on Object catch (e, st) {
      developer.log(
        'Rest alert failed',
        error: e,
        stackTrace: st,
        name: 'fitapp',
      );
    }
  }
}

final restTimerProvider = NotifierProvider<RestTimerController, ActiveRest?>(
  RestTimerController.new,
);
