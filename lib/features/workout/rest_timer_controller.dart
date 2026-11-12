import 'dart:async';

import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the rest-end sound. Replaceable in tests.
final restSoundProvider = Provider<void Function()>(
  (ref) =>
      () => unawaited(SystemSound.play(SystemSoundType.alert)),
);

/// The running rest timer (null when none). Time is always derived from the
/// stored start timestamp, never from a ticking counter, so it stays correct
/// when the app is backgrounded or killed (PRD §5.3).
class RestTimerController extends Notifier<ActiveRest?> {
  Timer? _alarm;

  @override
  ActiveRest? build() {
    ref.onDispose(() => _alarm?.cancel());
    unawaited(_restore());
    return null;
  }

  DateTime _now() => ref.read(clockProvider)().toUtc();

  SettingsRepository get _settings => ref.read(settingsRepositoryProvider);

  Future<void> _restore() async {
    final saved = await _settings.readActiveRest();
    if (saved == null || state != null) return;
    state = saved;
    // Already overtime: no late alert after a restart.
    if (remaining(saved) > Duration.zero) _schedule(saved);
  }

  /// Time left; negative means overtime.
  Duration remaining([ActiveRest? rest]) {
    final r = rest ?? state;
    if (r == null) return Duration.zero;
    return Duration(seconds: r.targetSeconds) - _now().difference(r.startedAt);
  }

  /// Starts (or restarts) the countdown.
  Future<void> start(int targetSeconds) async {
    final rest = ActiveRest(startedAt: _now(), targetSeconds: targetSeconds);
    state = rest;
    _schedule(rest);
    await _settings.writeActiveRest(rest);
  }

  /// Starts with the exercise's own rest time or the global default.
  Future<void> startFor({int? exerciseRestSeconds}) async {
    final seconds = exerciseRestSeconds ?? await _settings.defaultRest();
    await start(seconds);
  }

  Future<void> dismiss() async {
    _alarm?.cancel();
    state = null;
    await _settings.writeActiveRest(null);
  }

  void _schedule(ActiveRest rest) {
    _alarm?.cancel();
    final left = remaining(rest);
    _alarm = Timer(left.isNegative ? Duration.zero : left, () async {
      if (state != rest) return;
      final prefs = await _settings.alertPrefs();
      if (prefs.haptic) ref.read(hapticsProvider).warning();
      if (prefs.sound) ref.read(restSoundProvider)();
    });
  }
}

final restTimerProvider = NotifierProvider<RestTimerController, ActiveRest?>(
  RestTimerController.new,
);
