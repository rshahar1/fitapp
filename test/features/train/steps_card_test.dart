import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:fitapp/features/train/steps_card.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_step_source.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  late FakeStepSource source;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    settings = SettingsRepository(db);
    source = FakeStepSource();
  });
  tearDown(() => db.close());

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          stepSourceProvider.overrideWithValue(source),
          clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 12)),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: StepsCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> introSeen() => settings.markStepsIntroShown();

  testWidgets('shows today km next to the steps', (tester) async {
    source
      ..steps = 12345
      ..meters = 6213;
    await pump(tester);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.text('6.21 km'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
    await unmount(tester);
  });

  testWidgets('without distance permission offers Show km', (tester) async {
    source.distanceGranted = false;
    await pump(tester);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.textContaining(' km'), findsNothing);
    expect(find.byType(AppButton), findsOneWidget);
    source.meters = 2500;
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();
    expect(find.text('2.50 km'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('granted shows the formatted count', (tester) async {
    source.steps = 12345;
    await pump(tester);
    expect(find.text('Steps today'), findsOneWidget);
    expect(find.text('12,345'), findsOneWidget);
    expect(find.textContaining('Google Fit'), findsNothing);
    await unmount(tester);
  });

  testWidgets('zero steps shows the sharing hint', (tester) async {
    source.steps = 0;
    await pump(tester);
    expect(find.text('0'), findsOneWidget);
    expect(
      find.text('Turn on Health Connect sharing in Google Fit'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('unreadable count shows a dash', (tester) async {
    source.steps = null;
    await pump(tester);
    expect(find.text('—'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('unavailable is hidden', (tester) async {
    source.state = StepAccess.unavailable;
    await pump(tester);
    expect(find.text('Steps today'), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.text('CONNECT'), findsNothing);
    await unmount(tester);
  });

  testWidgets('disabled is hidden', (tester) async {
    await settings.setStepsEnabled(false);
    await pump(tester);
    expect(find.text('Steps today'), findsNothing);
    await unmount(tester);
  });

  testWidgets('needsInstall offers Health Connect', (tester) async {
    source.state = StepAccess.needsInstall;
    await pump(tester);
    await tester.tap(find.text('GET HEALTH CONNECT'));
    await tester.pumpAndSettle();
    expect(source.calls, ['install']);
    await unmount(tester);
  });

  testWidgets('notGranted card connects', (tester) async {
    await tester.runAsync(introSeen);
    source.state = StepAccess.notGranted;
    await pump(tester);
    expect(find.text('See your daily steps from Google Fit'), findsOneWidget);
    await tester.tap(find.text('CONNECT'));
    await tester.pumpAndSettle();
    expect(source.calls, ['request']);
    await unmount(tester);
  });

  testWidgets('intro sheet: Not now marks shown and is not shown again', (
    tester,
  ) async {
    source.state = StepAccess.notGranted;
    await pump(tester);
    expect(find.text('Show your daily steps and distance?'), findsOneWidget);
    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(find.text('Show your daily steps and distance?'), findsNothing);
    expect(source.calls, isEmpty);
    expect(await tester.runAsync(settings.stepsIntroShown), isTrue);

    await unmount(tester);
    await pump(tester);
    expect(find.text('Show your daily steps and distance?'), findsNothing);
    await unmount(tester);
  });

  testWidgets('intro sheet: Connect requests access', (tester) async {
    source.state = StepAccess.notGranted;
    await pump(tester);
    await tester.tap(find.text('CONNECT').last);
    await tester.pumpAndSettle();
    expect(source.calls, ['request']);
    expect(await tester.runAsync(settings.stepsIntroShown), isTrue);
    await unmount(tester);
  });

  testWidgets('no intro when access is granted', (tester) async {
    await pump(tester);
    expect(find.text('Show your daily steps and distance?'), findsNothing);
    await unmount(tester);
  });

  group('opens History calendar', () {
    Future<ProviderContainer> pumpShell(WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/train',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => Scaffold(body: shell),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(path: '/train', builder: (_, _) => const StepsCard()),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/history',
                    builder: (_, _) => const Text('history-branch'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            stepSourceProvider.overrideWithValue(source),
            clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 12)),
          ],
          child: MaterialApp.router(
            theme: buildAppTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(StepsCard)));
    }

    testWidgets('tapping the granted card shows the calendar on History', (
      tester,
    ) async {
      final container = await pumpShell(tester);
      expect(container.read(historyViewProvider), HistoryView.list);
      await tester.tap(find.text('Steps today'));
      await tester.pumpAndSettle();
      expect(container.read(historyViewProvider), HistoryView.calendar);
      expect(find.text('history-branch'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('prompt cards are not tappable', (tester) async {
      await tester.runAsync(introSeen);
      source.state = StepAccess.notGranted;
      final container = await pumpShell(tester);
      await tester.tap(find.text('See your daily steps from Google Fit'));
      await tester.pumpAndSettle();
      expect(container.read(historyViewProvider), HistoryView.list);
      expect(find.text('history-branch'), findsNothing);
      await unmount(tester);
    });
  });
}
