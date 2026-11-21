import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_icons.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_step_source.dart';

const _incline = '00000000-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;
  var now = DateTime.utc(2026, 11, 3, 10);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    now = DateTime.utc(2026, 11, 3, 10);
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  Future<void> gym(DateTime at) async {
    now = at;
    final repo = WorkoutRepository(db);
    await ExerciseRepository(db).savePlan(
      _incline,
      baseWeight: 20,
      targetReps: 10,
      targetSets: 3,
      increment: 2.5,
    );
    final w = await repo.startWorkout();
    final we = await repo.addExercise(w.id, _incline);
    await repo.logSet(we.id, setNo: 1, weight: 20, reps: 10);
    now = at.add(const Duration(minutes: 45));
    await repo.finishWorkout(w.id);
  }

  Future<void> seed() => Future<void>.sync(() async {
    await gym(DateTime.utc(2026, 11, 3, 10));
    await gym(DateTime.utc(2026, 11, 5, 12));
    now = DateTime.utc(2026, 11, 5, 14);
    await ActivityRepository(db).create(
      typeId: 'cycling',
      startedAt: DateTime.utc(2026, 11, 5, 8),
      durationMinutes: 60,
    );
  });

  /// Unmounts the tree and lets drift's stream-cleanup timers fire.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> pumpCalendar(
    WidgetTester tester, {
    FakeStepSource? steps,
  }) async {
    await tester.runAsync(seed);
    addTearDown(() => unmount(tester));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (steps != null) stepSourceProvider.overrideWithValue(steps),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 13, 12)),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HistoryScreen()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
  }

  Finder cell(String startsWith) =>
      find.bySemanticsLabel(RegExp('^$startsWith'));

  testWidgets('shows the month view with no Week selector', (tester) async {
    await pumpCalendar(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Week'), findsNothing);
    expect(find.text('Month'), findsNothing);
    expect(find.byTooltip('Previous month'), findsOneWidget);
    expect(find.byTooltip('Previous week'), findsNothing);
  });

  testWidgets('weekday header starts on Sunday', (tester) async {
    await pumpCalendar(tester);
    final sun = tester.getTopLeft(find.text('Sun').first).dx;
    final mon = tester.getTopLeft(find.text('Mon').first).dx;
    final sat = tester.getTopLeft(find.text('Sat').first).dx;
    expect(sun, lessThan(mon));
    expect(mon, lessThan(sat));
    expect(sun, lessThan(sat));
  });

  testWidgets('shows month, icons, +N and the selected day sessions', (
    tester,
  ) async {
    await pumpCalendar(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.byIcon(AppIcons.gym), findsWidgets);
    // 5 Nov: cycling first (08:00), then gym => bike icon and +1.
    await tester.ensureVisible(cell('Thursday 5 November'));
    expect(
      find.descendant(
        of: cell('Thursday 5 November'),
        matching: find.byIcon(AppIcons.cycling),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: cell('Thursday 5 November'),
        matching: find.text('+1'),
      ),
      findsOneWidget,
    );
    expect(find.text('No training'), findsOneWidget);
    await tester.tap(cell('Thursday 5 November'));
    await tester.pumpAndSettle();
    expect(find.text('No training'), findsNothing);
    expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
    expect(find.textContaining('Cycling'), findsOneWidget);
  });

  testWidgets('navigates months, Today and the picker', (tester) async {
    await pumpCalendar(tester);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, AppIcons.chevronRight),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.text('November 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Previous year'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(find.text('March 2025'), findsOneWidget);
    expect(find.text('March 2026'), findsNothing);
  });

  testWidgets('does not overflow at 360x690', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCalendar(tester);
    expect(tester.takeException(), isNull);
    expect(tester.takeException(), isNull);
  });

  group('selected-day steps', () {
    // Fixed "now": 13 Nov 2026 12:00 UTC (see pumpCalendar).
    final today = DateTime.utc(2026, 11, 13, 12).toLocal();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    Future<void> selectDay(WidgetTester tester, String label) async {
      await tester.ensureVisible(cell(label));
      await tester.tap(cell(label));
      await tester.pumpAndSettle();
    }

    Finder headerSteps() => find.textContaining(RegExp(r'\d steps?$'));

    testWidgets('today shows its total with no icon in the header', (
      tester,
    ) async {
      final src = FakeStepSource()..byStart[todayMidnight] = 8432;
      await pumpCalendar(tester, steps: src);
      expect(find.text('8,432 steps'), findsOneWidget);
      expect(src.intervals.last.$1, todayMidnight);
      final text = tester.widget<Text>(find.text('8,432 steps'));
      expect(text.style?.fontFeatures, isNotEmpty);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('8,432 steps'),
            matching: find.byType(Row),
          ),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Steps on .*: 8,432 steps$')),
        findsOneWidget,
      );
    });

    testWidgets('shows km after the steps in the day header', (tester) async {
      final src = FakeStepSource()
        ..byStart[todayMidnight] = 8432
        ..meters = 6213;
      await pumpCalendar(tester, steps: src);
      expect(find.text('8,432 steps · 6.21 km'), findsOneWidget);
    });

    testWidgets('a day with workouts shows steps above the sessions', (
      tester,
    ) async {
      final src = FakeStepSource()..byStart[DateTime(2026, 11, 5)] = 1000;
      await pumpCalendar(tester, steps: src);
      await selectDay(tester, 'Thursday 5 November');
      expect(find.text('1,000 steps'), findsOneWidget);
      expect(find.text('Incline Dumbbell Bench Press'), findsOneWidget);
    });

    testWidgets('a no-training day still shows steps', (tester) async {
      final src = FakeStepSource()..byStart[DateTime(2026, 11, 4)] = 77;
      await pumpCalendar(tester, steps: src);
      await selectDay(tester, 'Wednesday 4 November');
      expect(find.text('No training'), findsOneWidget);
      expect(find.text('77 steps'), findsOneWidget);
    });

    testWidgets('zero and one read "0 steps" and "1 step"', (tester) async {
      final src = FakeStepSource()
        ..steps = 0
        ..byStart[DateTime(2026, 11, 4)] = 1;
      await pumpCalendar(tester, steps: src);
      expect(find.text('0 steps'), findsOneWidget);
      await selectDay(tester, 'Wednesday 4 November');
      expect(find.text('1 step'), findsOneWidget);
      expect(find.text('0 steps'), findsNothing);
    });

    testWidgets('switching days shows only the selected day', (tester) async {
      final src = FakeStepSource()
        ..byStart[DateTime(2026, 11, 4)] = 400
        ..byStart[DateTime(2026, 11, 5)] = 500;
      await pumpCalendar(tester, steps: src);
      await selectDay(tester, 'Wednesday 4 November');
      expect(find.text('400 steps'), findsOneWidget);
      await selectDay(tester, 'Thursday 5 November');
      expect(find.text('500 steps'), findsOneWidget);
      expect(find.text('400 steps'), findsNothing);
    });

    testWidgets('hidden when steps are turned off', (tester) async {
      final src = FakeStepSource();
      await tester.runAsync(
        () => SettingsRepository(db).setStepsEnabled(false),
      );
      await pumpCalendar(tester, steps: src);
      expect(headerSteps(), findsNothing);
      expect(src.intervals, isEmpty);
    });

    testWidgets('hidden when access is not granted', (tester) async {
      final src = FakeStepSource(state: StepAccess.notGranted);
      await pumpCalendar(tester, steps: src);
      expect(headerSteps(), findsNothing);
      expect(src.intervals, isEmpty);
    });

    testWidgets('hidden on a read failure', (tester) async {
      final src = FakeStepSource(steps: null);
      await pumpCalendar(tester, steps: src);
      expect(headerSteps(), findsNothing);
    });

    testWidgets('hidden for a future day without a read', (tester) async {
      final src = FakeStepSource();
      await pumpCalendar(tester, steps: src);
      await selectDay(tester, 'Sunday 15 November');
      expect(headerSteps(), findsNothing);
      expect(
        src.intervals.every((i) => i.$1 != DateTime(2026, 11, 15)),
        isTrue,
      );
    });

    testWidgets('hidden for a day older than 30 days without a read', (
      tester,
    ) async {
      final src = FakeStepSource();
      await pumpCalendar(tester, steps: src);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }
      await selectDay(tester, 'Wednesday 16 September');
      expect(headerSteps(), findsNothing);
      expect(src.intervals.every((i) => i.$1 != DateTime(2026, 9, 16)), isTrue);
    });
  });
}
