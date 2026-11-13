import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/activity_repository.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  Future<void> pumpCalendar(WidgetTester tester) async {
    await tester.runAsync(seed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
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

  testWidgets('shows month, icons, +N and the selected day sessions', (
    tester,
  ) async {
    await pumpCalendar(tester);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsWidgets);
    // 5 Nov: cycling first (08:00), then gym => bike icon and +1.
    await tester.ensureVisible(cell('Thursday 5 November'));
    expect(
      find.descendant(
        of: cell('Thursday 5 November'),
        matching: find.byIcon(Icons.directions_bike),
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
            find.widgetWithIcon(IconButton, Icons.chevron_right),
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

  testWidgets('week mode shows 7 days and moves by week', (tester) async {
    await pumpCalendar(tester);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^\w+day \d+ \w+, ')),
      findsNWidgets(7),
    );
    await tester.tap(find.byTooltip('Previous week'));
    await tester.pumpAndSettle();
    expect(find.text('2 – 8 Nov 2026'), findsOneWidget);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('9 – 15 Nov 2026'), findsOneWidget);
  });

  testWidgets('does not overflow at 360x690', (tester) async {
    tester.view.physicalSize = const Size(360, 690);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCalendar(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
