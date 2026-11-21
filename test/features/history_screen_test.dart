import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/step_source.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/history/history_calendar.dart';
import 'package:fitapp/features/history/history_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fake_step_source.dart';

const _incline = '00000000-0000-4000-8000-000000000002';
const _lat = '00000000-0000-4000-8000-000000000009';

void main() {
  late AppDatabase db;
  var now = DateTime.utc(2026, 10, 10, 18);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory()),
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  Future<void> finished(String exerciseId, List<(double, int)> sets) async {
    final repo = WorkoutRepository(db);
    await ExerciseRepository(db).savePlan(
      exerciseId,
      baseWeight: 20,
      targetReps: 10,
      targetSets: 3,
      increment: 2.5,
    );
    final w = await repo.startWorkout();
    final we = await repo.addExercise(w.id, exerciseId);
    for (var i = 0; i < sets.length; i++) {
      await repo.logSet(
        we.id,
        setNo: i + 1,
        weight: sets[i].$1,
        reps: sets[i].$2,
      );
    }
    now = now.add(const Duration(minutes: 45));
    await repo.finishWorkout(w.id);
  }

  Future<void> pumpScreen(WidgetTester tester, {HistoryView? view}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          if (view != null) ...[
            stepSourceProvider.overrideWithValue(FakeStepSource()),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 10, 18)),
          ],
          if (view != null)
            historyViewProvider.overrideWith(() => _FixedView(view)),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const HistoryScreen()),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    if (view == null) {
      await tester.pumpAndSettle();
    } else {
      // The calendar keeps loading step data, so it never fully settles.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('groups workouts by month with date and template name', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await finished(_incline, [(20, 10), (20, 10), (22.5, 6)]);
      now = DateTime.utc(2026, 11, 3, 18);
      await finished(_lat, [(50, 10), (50, 10)]);
    });
    await pumpScreen(tester);

    expect(find.text('History'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('Workout'), findsNWidgets(2));
    expect(find.text('Incline Dumbbell Bench Press'), findsNothing);
    expect(find.text('Lat Pulldown'), findsNothing);
    expect(find.text('1,070 kg'), findsNothing);
    expect(find.text('3 sets · 45m'), findsNothing);
  });

  testWidgets('shows the empty state', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Nothing logged yet'), findsOneWidget);
    expect(
      find.text('Finished workouts and activities show up here.'),
      findsOneWidget,
    );
  });

  group('history view provider', () {
    testWidgets('calendar view shows the calendar', (tester) async {
      await tester.runAsync(() => finished(_incline, [(20, 10)]));
      await pumpScreen(tester, view: HistoryView.calendar);
      expect(find.byType(HistoryCalendar), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('defaults to the list view', (tester) async {
      await tester.runAsync(() => finished(_incline, [(20, 10)]));
      await pumpScreen(tester);
      expect(find.byType(HistoryCalendar), findsNothing);
    });
  });
}

class _FixedView extends HistoryViewNotifier {
  new(this.initial);

  final HistoryView initial;

  @override
  HistoryView build() => initial;
}
