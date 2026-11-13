import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Notification permission as reported by the system.
enum AlertPermission { granted, denied, notAsked }

@immutable
class AlertStatus {
  const new({required this.notifications, required this.exactAlarms});

  final AlertPermission notifications;

  /// Whether precise (exact) background alerts are allowed.
  final bool exactAlarms;
}

/// Platform boundary for rest-end alerts (specs/002-rest-alerts/contracts).
/// All methods must swallow and log platform errors; the in-app timer never
/// depends on them.
abstract interface class RestAlerts {
  /// Sets up channels and tap handling. [onOpenWorkout] runs when the user
  /// taps a rest notification (including a tap that launched the app).
  Future<void> init({required void Function() onOpenWorkout});

  Future<AlertStatus> status();

  /// Shows the system permission prompt where the OS requires one.
  Future<bool> requestNotificationPermission();

  Future<void> openNotificationSettings();

  Future<void> openExactAlarmSettings();

  /// Plays the short rest-end chime (respects silent mode, ducks music).
  Future<void> playChime();

  /// Schedules the single rest notification at [at] (UTC), replacing any
  /// pending one.
  Future<void> schedule({
    required DateTime at,
    required String exerciseName,
    required bool sound,
    required bool vibrate,
  });

  /// Removes the pending and any shown rest notification.
  Future<void> cancel();
}

/// Does nothing. Default for tests and platforms without support.
class NoopRestAlerts implements RestAlerts {
  const new();

  @override
  Future<void> init({required void Function() onOpenWorkout}) async {}

  @override
  Future<AlertStatus> status() async => const AlertStatus(
    notifications: AlertPermission.granted,
    exactAlarms: true,
  );

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> playChime() async {}

  @override
  Future<void> schedule({
    required DateTime at,
    required String exerciseName,
    required bool sound,
    required bool vibrate,
  }) async {}

  @override
  Future<void> cancel() async {}
}

/// Overridden in main() with the platform implementation.
final restAlertsProvider = Provider<RestAlerts>(
  (ref) => const NoopRestAlerts(),
);
