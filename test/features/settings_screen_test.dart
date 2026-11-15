import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/features/settings/settings_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_step_source.dart';

class _FakeHaptics implements Haptics {
  @override
  void tick() {}
  @override
  void success() {}
  @override
  void warning() {}
}

class _FakeAlerts extends NoopRestAlerts {
  new(this.current);

  AlertStatus current;
  final calls = <String>[];

  @override
  Future<AlertStatus> status() async => current;

  @override
  Future<void> openNotificationSettings() async => calls.add('notifications');

  @override
  Future<void> openExactAlarmSettings() async => calls.add('exact');
}

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late FakeStepSource steps;
  var alerts = _FakeAlerts(
    const AlertStatus(
      notifications: AlertPermission.granted,
      exactAlarms: true,
    ),
  );

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    settings = SettingsRepository(db);
    steps = FakeStepSource();
    alerts = _FakeAlerts(
      const AlertStatus(
        notifications: AlertPermission.granted,
        exactAlarms: true,
      ),
    );
  });
  tearDown(() => db.close());

  /// Unmounts the tree and lets drift's stream-cleanup timers fire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pump(WidgetTester tester) async {
    // Tall enough for the Account & backup group above the rest settings.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_FakeHaptics()),
          restAlertsProvider.overrideWithValue(alerts),
          stepSourceProvider.overrideWithValue(steps),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('preset persists default rest', (tester) async {
    await pump(tester);
    await tester.tap(find.text('1:30'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(settings.defaultRest), 90);
    await unmount(tester);
  });

  testWidgets('stepper plus adds 5 seconds', (tester) async {
    await pump(tester);
    expect(find.text('1:00'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Increase Default rest time'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(settings.defaultRest), 65);
    expect(find.text('1:05'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('alert toggles persist', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Vibrate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound'));
    await tester.pumpAndSettle();
    final prefs = await tester.runAsync(settings.alertPrefs);
    expect(prefs, const RestAlertPrefs(haptic: false, sound: false));
    await unmount(tester);
  });

  testWidgets('alert rows are all switches reflecting status', (tester) async {
    await pump(tester);
    for (final t in ['Vibrate', 'Sound', 'Notifications', 'Precise timing']) {
      expect(find.widgetWithText(SwitchListTile, t), findsOneWidget, reason: t);
    }
    SwitchListTile row(String t) =>
        tester.widget(find.widgetWithText(SwitchListTile, t));
    expect(row('Notifications').value, isTrue);
    expect(row('Precise timing').value, isTrue);
    expect(find.textContaining('Needed for alerts'), findsNothing);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(alerts.calls, ['notifications']);
    await unmount(tester);
  });

  testWidgets('Off switches show hints and open the right settings', (
    tester,
  ) async {
    alerts.current = const AlertStatus(
      notifications: AlertPermission.denied,
      exactAlarms: false,
    );
    await pump(tester);
    SwitchListTile row(String t) =>
        tester.widget(find.widgetWithText(SwitchListTile, t));
    expect(row('Notifications').value, isFalse);
    expect(row('Precise timing').value, isFalse);
    expect(
      find.text('Needed for alerts while the app is in the background'),
      findsOneWidget,
    );
    expect(
      find.text('Alerts may be late while the phone is idle'),
      findsOneWidget,
    );
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Precise timing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Precise timing'));
    await tester.pumpAndSettle();
    expect(alerts.calls, ['notifications', 'exact']);
    await unmount(tester);
  });

  group('Activity', () {
    SwitchListTile row(WidgetTester tester) =>
        tester.widget(find.widgetWithText(SwitchListTile, 'Daily steps'));

    testWidgets('subtitle follows the access state', (tester) async {
      for (final (state, text) in [
        (StepAccess.granted, 'Connected to Health Connect'),
        (StepAccess.notGranted, 'Not connected — tap to connect'),
        (StepAccess.needsInstall, 'Health Connect needs to be installed'),
        (StepAccess.unavailable, 'Health Connect not available on this phone'),
      ]) {
        steps.state = state;
        await pump(tester);
        expect(row(tester).value, isTrue);
        expect(find.text(text), findsOneWidget, reason: '$state');
        await unmount(tester);
      }
    });

    testWidgets('switch persists and hides the subtitle when off', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Daily steps'));
      await tester.pumpAndSettle();
      expect(
        await tester.runAsync(() => settings.watchStepsEnabled().first),
        isFalse,
      );
      expect(find.text('Connected to Health Connect'), findsNothing);
      expect(steps.calls, isEmpty);
      await unmount(tester);
    });

    testWidgets('turning on while not connected requests access', (
      tester,
    ) async {
      await settings.setStepsEnabled(false);
      steps.state = StepAccess.notGranted;
      await pump(tester);
      await tester.tap(find.text('Daily steps'));
      await tester.pumpAndSettle();
      expect(steps.calls, ['request']);
      await unmount(tester);
    });

    testWidgets('turning on while Health Connect is missing installs it', (
      tester,
    ) async {
      await settings.setStepsEnabled(false);
      steps.state = StepAccess.needsInstall;
      await pump(tester);
      await tester.tap(find.text('Daily steps'));
      await tester.pumpAndSettle();
      expect(steps.calls, ['install']);
      await unmount(tester);
    });

    testWidgets('privacy row is present', (tester) async {
      await pump(tester);
      expect(find.text('How step data is used'), findsOneWidget);
      await unmount(tester);
    });
  });
}
