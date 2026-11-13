import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAlerts implements RestAlerts {
  final calls = <String>[];
  final scheduled = <({DateTime at, String name, bool sound, bool vibrate})>[];
  bool grant = true;

  @override
  Future<void> init({required void Function() onOpenWorkout}) async {}

  @override
  Future<AlertStatus> status() async => const AlertStatus(
    notifications: AlertPermission.granted,
    exactAlarms: true,
  );

  @override
  Future<bool> requestNotificationPermission() async {
    calls.add('request');
    return grant;
  }

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> playChime() async => calls.add('chime');

  @override
  Future<void> schedule({
    required DateTime at,
    required String exerciseName,
    required bool sound,
    required bool vibrate,
  }) async {
    calls.add('schedule');
    scheduled.add((at: at, name: exerciseName, sound: sound, vibrate: vibrate));
  }

  @override
  Future<void> cancel() async => calls.add('cancel');

  int count(String c) => calls.where((x) => x == c).length;
}

class _FakeHaptics implements Haptics {
  int warnings = 0;
  @override
  void success() {}
  @override
  void tick() {}
  @override
  void warning() => warnings++;
}

class _Env {
  new() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    settings = SettingsRepository(db);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        restAlertsProvider.overrideWithValue(alerts),
        hapticsProvider.overrideWithValue(haptics),
      ],
    );
    // Keep the controller and the prefs stream alive for the whole test.
    container
      ..listen(restTimerProvider, (_, _) {})
      ..listen(alertPrefsProvider, (_, _) {});
  }

  late final AppDatabase db;
  late final SettingsRepository settings;
  late final ProviderContainer container;
  final alerts = _FakeAlerts();
  final haptics = _FakeHaptics();

  RestTimerController get timer => container.read(restTimerProvider.notifier);

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late _Env env;
  setUp(() async {
    env = _Env();
    await _wait(20); // let _restore() run
  });
  tearDown(() => env.dispose());

  group('US1: foreground chime', () {
    test('chimes and vibrates once at 0 when both are on', () async {
      await env.timer.start(1, exerciseName: 'Deadlift');
      await _wait(1300);
      expect(env.alerts.count('chime'), 1);
      expect(env.haptics.warnings, 1);
      await _wait(300);
      expect(env.alerts.count('chime'), 1);
    });

    test('no chime when Sound is off; vibration follows Vibrate', () async {
      await env.settings.setAlertPrefs(const RestAlertPrefs(sound: false));
      await env.timer.start(1);
      await _wait(1300);
      expect(env.alerts.count('chime'), 0);
      expect(env.haptics.warnings, 1);
    });

    test('no vibration when Vibrate is off', () async {
      await env.settings.setAlertPrefs(const RestAlertPrefs(haptic: false));
      await env.timer.start(1);
      await _wait(1300);
      expect(env.haptics.warnings, 0);
      expect(env.alerts.count('chime'), 1);
    });

    test(
      'an early next set replaces the timer: no chime for the old one',
      () async {
        await env.timer.start(1);
        await _wait(500);
        await env.timer.start(60);
        await _wait(900);
        expect(env.alerts.count('chime'), 0);
      },
    );

    test('dismiss before 0 prevents the chime and cancels alerts', () async {
      await env.timer.start(1);
      await env.timer.dismiss();
      await _wait(1300);
      expect(env.alerts.count('chime'), 0);
      expect(env.alerts.count('cancel'), greaterThanOrEqualTo(1));
    });

    test('a restored, already-ended timer never chimes late', () async {
      await env.settings.writeActiveRest(
        ActiveRest(
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 5),
          ),
          targetSeconds: 60,
        ),
      );
      final fresh = _Env();
      // Same DB content is needed: reuse env.db via a new container.
      fresh.container.dispose();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(env.db),
          restAlertsProvider.overrideWithValue(fresh.alerts),
          hapticsProvider.overrideWithValue(fresh.haptics),
        ],
      )..listen(restTimerProvider, (_, _) {});
      await _wait(300);
      expect(container.read(restTimerProvider), isNotNull);
      await container.read(restTimerProvider.notifier).onBackground();
      await _wait(300);
      expect(fresh.alerts.count('chime'), 0);
      expect(fresh.alerts.count('schedule'), 0);
      container.dispose();
      await fresh.db.close();
    });
  });

  group('US2: background notification', () {
    test(
      'backgrounding schedules at the end with prefs and exercise',
      () async {
        await env.timer.start(60, exerciseName: 'Bench');
        final rest = env.container.read(restTimerProvider)!;
        await env.timer.onBackground();
        final s = env.alerts.scheduled.single;
        expect(s.at, rest.endsAt);
        expect(s.name, 'Bench');
        expect((s.sound, s.vibrate), (true, true));
      },
    );

    test('foreground cancels the scheduled notification', () async {
      await env.timer.start(60);
      await env.timer.onBackground();
      env.alerts.calls.clear();
      await env.timer.onForeground();
      expect(env.alerts.calls, ['cancel']);
    });

    test('no in-app chime while backgrounded (the OS alert is used)', () async {
      await env.timer.start(1);
      await env.timer.onBackground();
      await _wait(1300);
      expect(env.alerts.count('chime'), 0);
      env.alerts.calls.clear();
      await env.timer.onForeground();
      await _wait(200);
      expect(env.alerts.count('chime'), 0, reason: 'no late chime on return');
    });

    test('a new set while backgrounded reschedules (single alert)', () async {
      await env.timer.start(60);
      await env.timer.onBackground();
      await env.timer.start(90);
      expect(env.alerts.count('schedule'), 2);
      expect(
        env.alerts.scheduled.last.at,
        env.container.read(restTimerProvider)!.endsAt,
      );
    });

    test('dismiss cancels', () async {
      await env.timer.start(60);
      await env.timer.onBackground();
      env.alerts.calls.clear();
      await env.timer.dismiss();
      expect(env.alerts.calls, contains('cancel'));
    });

    test(
      'changing prefs while backgrounded reschedules with new prefs',
      () async {
        await env.timer.start(60);
        await _wait(50);
        await env.timer.onBackground();
        await env.settings.setAlertPrefs(const RestAlertPrefs(sound: false));
        await _wait(100);
        expect(env.alerts.scheduled.last.sound, isFalse);
        expect(env.alerts.scheduled.last.vibrate, isTrue);
      },
    );

    test('nothing is scheduled when no timer is running', () async {
      await env.timer.onBackground();
      expect(env.alerts.count('schedule'), 0);
    });

    test('starting in the foreground cancels any stale notification', () async {
      await env.timer.start(60);
      expect(env.alerts.calls.first, 'cancel');
    });
  });

  group('US3: permission', () {
    test('first timer asks once; later timers do not', () async {
      await env.timer.start(60);
      await env.timer.start(60);
      expect(env.alerts.count('request'), 1);
      expect(await env.settings.notificationPermissionAsked(), isTrue);
    });

    test('denied permission does not affect the in-app chime', () async {
      env.alerts.grant = false;
      await env.timer.start(1);
      await _wait(1300);
      expect(env.alerts.count('chime'), 1);
    });
  });
}
