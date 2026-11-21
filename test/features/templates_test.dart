import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/template_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/start/start_hub_sheet.dart';
import 'package:fitapp/features/workout/workout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

class _GoHome extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => showStartHub(context),
        child: const Text('Open Go'),
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late WorkoutRepository workouts;
  late TemplateRepository templates;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
    workouts = WorkoutRepository(db);
    templates = TemplateRepository(db);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  }

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/workout',
          builder: (_, _) => const Scaffold(body: Text('live workout')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          hapticsProvider.overrideWithValue(_NoHaptics()),
          restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
        ],
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await settle(tester);
  }

  /// A page with a button that opens the Go sheet.
  const home = _GoHome();

  testWidgets('Go sheet START creates a live workout with the exercises', (
    tester,
  ) async {
    await tester.runAsync(
      () => templates.create(name: 'Push', exerciseIds: [_incline]),
    );
    await pumpApp(tester, home);
    await tester.tap(find.text('Open Go'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Start Push template'));
    await settle(tester);
    expect(find.text('live workout'), findsOneWidget);
    final detail = await tester.runAsync(() async {
      final active = await workouts.watchActiveWorkout().first;
      return await workouts.watchWorkout(active!.id).first;
    });
    expect([for (final e in detail!.exercises) e.row.exerciseId], [_incline]);
    await unmount(tester);
  });

  testWidgets('Go sheet START while active shows the in-progress snackbar', (
    tester,
  ) async {
    final activeId = await tester.runAsync(() async {
      await templates.create(name: 'Push', exerciseIds: [_incline]);
      return (await workouts.startWorkout()).id;
    });
    await pumpApp(tester, home);
    await tester.tap(find.text('Open Go'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Start Push template'));
    await settle(tester);
    expect(find.text('Workout in progress. Finish it first.'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    final active = await tester.runAsync(() => workouts.activeWorkout());
    expect(active?.id, activeId);
    await unmount(tester);
  });

  testWidgets('Save as template from a finished workout', (tester) async {
    final id = await tester.runAsync(() async {
      final w = await workouts.startWorkout();
      final we = await workouts.addExercise(w.id, _incline);
      await workouts.logSet(we.id, setNo: 1, weight: 20, reps: 10);
      await workouts.finishWorkout(w.id);
      return w.id;
    });
    await pumpApp(tester, WorkoutScreen(workoutId: id));
    await tester.tap(find.byTooltip('Workout options'));
    await settle(tester);
    await tester.tap(find.text('Save as template'));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'My routine',
    );
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(find.text('Template saved'), findsOneWidget);
    final list = await tester.runAsync(templates.list);
    expect([for (final t in list!) t.name], ['My routine']);
    expect(list.single.exercises.single.id, _incline);
    await unmount(tester);
  });
}
