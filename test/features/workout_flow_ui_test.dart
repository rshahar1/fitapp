import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/app.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _incline = '00000000-0000-4000-8000-000000000002';

class _NoHaptics implements Haptics {
  @override
  void success() {}
  @override
  void tick() {}
  @override
  void warning() {}
}

void main() {
  late AppDatabase db;
  late WorkoutRepository repo;
  var now = DateTime.utc(2026, 11, 12, 18);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    now = DateTime.utc(2026, 11, 12, 18);
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory()),
      clock: () => now,
    );
    repo = WorkoutRepository(db);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => now),
          hapticsProvider.overrideWithValue(_NoHaptics()),
          restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
        ],
        child: const FitApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pump();
    await tester.tap(f.first);
    await settle(tester);
  }

  Future<void> openLive(WidgetTester tester) async {
    await tap(tester, find.text('CONTINUE WORKOUT'));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Workout options'));
  }

  /// A finished workout (10 minutes long) that is then resumed.
  Future<String?> seedResumed() => tester0.runAsync(() async {
    final w = await repo.startWorkout();
    final we = await repo.addExercise(w.id, _incline);
    await repo.logSet(we.id, setNo: 1, weight: 20, reps: 10);
    now = now.add(const Duration(minutes: 10));
    await repo.finishWorkout(w.id);
    await repo.resumeWorkout(w.id);
    return w.id;
  });

  testWidgets('discard confirms, deletes and returns to Home', (tester) async {
    tester0 = tester;
    await tester.runAsync(repo.startWorkout);
    await pumpApp(tester);
    await openLive(tester);
    await openMenu(tester);
    await tap(tester, find.text('Discard workout'));
    expect(find.text('Discard workout?'), findsOneWidget);
    expect(
      find.text(
        'This workout and its logged sets will be deleted. This cannot be undone.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.text('Discard'));
    expect(find.text('Ready to train?'), findsNothing);
    expect(find.text('Workout in progress'), findsNothing);
    expect(await tester.runAsync(repo.activeWorkout), isNull);
    await unmount(tester);
  });

  testWidgets('cancelling discard keeps the workout', (tester) async {
    tester0 = tester;
    await tester.runAsync(repo.startWorkout);
    await pumpApp(tester);
    await openLive(tester);
    await openMenu(tester);
    await tap(tester, find.text('Discard workout'));
    await tap(tester, find.text('Cancel'));
    expect(find.text('Discard workout?'), findsNothing);
    expect(find.byTooltip('Workout options'), findsOneWidget);
    expect(await tester.runAsync(repo.activeWorkout), isNotNull);
    await unmount(tester);
  });

  testWidgets('resumed workout shows the stronger discard message', (
    tester,
  ) async {
    tester0 = tester;
    await seedResumed();
    await pumpApp(tester);
    await openLive(tester);
    await openMenu(tester);
    await tap(tester, find.text('Discard workout'));
    expect(find.textContaining('resumed from History'), findsOneWidget);
    await tap(tester, find.text('Cancel'));
    await unmount(tester);
  });

  testWidgets('finish summary Resume keeps the workout live', (tester) async {
    tester0 = tester;
    await tester.runAsync(() async {
      final w = await repo.startWorkout();
      final we = await repo.addExercise(w.id, _incline);
      await repo.logSet(we.id, setNo: 1, weight: 20, reps: 10);
      now = now.add(const Duration(minutes: 5));
    });
    await pumpApp(tester);
    await openLive(tester);
    await tap(tester, find.text('FINISH'));
    expect(find.text('Workout complete'), findsOneWidget);
    await tap(tester, find.text('RESUME WORKOUT'));
    expect(find.text('Workout complete'), findsNothing);
    expect(find.text('RESUME WORKOUT'), findsNothing);
    expect(await tester.runAsync(repo.activeWorkout), isNotNull);
    await unmount(tester);
  });

  testWidgets('Date row changes the day of a live workout', (tester) async {
    tester0 = tester;
    await tester.runAsync(repo.startWorkout);
    await pumpApp(tester);
    await openLive(tester);
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await tap(tester, find.text('Date'));
    await tester.tap(find.text('11'));
    await tester.pump();
    await tap(tester, find.text('OK'));
    expect(find.text('Yesterday'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('You tab has the Gym Exercise Library', (tester) async {
    tester0 = tester;
    await pumpApp(tester);
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    expect(find.text('Gym Exercise Library'), findsOneWidget);
    await tester.tap(find.text('Gym Exercise Library'));
    await tester.pumpAndSettle();
    expect(find.text('Gym Exercise Library'), findsWidgets);
    await unmount(tester);
  });
}

late WidgetTester tester0;
