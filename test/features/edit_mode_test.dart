import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
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

class _Env {
  new() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(
      DatabaseConnection(NativeDatabase.memory()),
      clock: () => now,
    );
    workouts = WorkoutRepository(db);
    exercises = ExerciseRepository(db);
  }

  DateTime now = DateTime.utc(2026, 11, 2, 18);
  late final AppDatabase db;
  late final WorkoutRepository workouts;
  late final ExerciseRepository exercises;

  Future<String> finished(List<(double, int)> sets) async {
    now = now.add(const Duration(days: 1));
    final w = await workouts.startWorkout();
    final we = await workouts.addExercise(w.id, _incline);
    for (var i = 0; i < sets.length; i++) {
      await workouts.logSet(
        we.id,
        setNo: i + 1,
        weight: sets[i].$1,
        reps: sets[i].$2,
      );
    }
    now = now.add(const Duration(minutes: 40));
    await workouts.finishWorkout(w.id);
    return w.id;
  }

  Future<double> base() async => (await exercises.plan(_incline))!.baseWeight;

  Widget app(String workoutId) {
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/workout/$workoutId'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/workout',
          builder: (_, _) => const Scaffold(body: Text('live workout')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, s) =>
                  WorkoutScreen(workoutId: s.pathParameters['id']),
            ),
          ],
        ),
        GoRoute(
          path: '/history',
          builder: (_, _) => const Scaffold(body: Text('history')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        hapticsProvider.overrideWithValue(_NoHaptics()),
        restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
      ],
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    );
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _open(WidgetTester tester, _Env env, String id) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(env.app(id));
  await _settle(tester);
  await tester.tap(find.text('open'));
  await _settle(tester);
}

Future<void> _dispose(WidgetTester tester, _Env env) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 10));
  await tester.runAsync(env.db.close);
}

Future<void> _editSet2Reps(
  WidgetTester tester, {
  required bool increase,
}) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Set 2, logged')));
  await _settle(tester);
  await tester.tap(
    find.bySemanticsLabel(increase ? 'Increase Reps' : 'Decrease Reps'),
  );
  await tester.pump();
  await tester.tap(find.text('UPDATE'));
  await _settle(tester);
}

void main() {
  Future<_Env> seeded(WidgetTester tester) async {
    final env = _Env();
    await tester.runAsync(
      () => env.exercises.savePlan(
        _incline,
        baseWeight: 20,
        targetReps: 10,
        targetSets: 3,
        increment: 2.5,
      ),
    );
    return env;
  }

  testWidgets('edit latest: 9 reps -> base 20, back to 10 -> 22.5 (§11.5)', (
    tester,
  ) async {
    final env = await seeded(tester);
    final id = (await tester.runAsync(
      () => env.finished([(20, 10), (20, 10), (22.5, 6)]),
    ))!;
    await _open(tester, env, id);
    expect(find.text('Changes save automatically'), findsOneWidget);

    await _editSet2Reps(tester, increase: false);
    expect(await tester.runAsync(env.base), 20);
    expect(find.text('9 / 10'), findsOneWidget);

    await _editSet2Reps(tester, increase: true);
    expect(await tester.runAsync(env.base), 22.5);
    await _dispose(tester, env);
  });

  testWidgets('Resume shows only for the most recent finished workout', (
    tester,
  ) async {
    final env = await seeded(tester);
    final first = (await tester.runAsync(
      () => env.finished([(20, 10), (20, 10), (22.5, 6)]),
    ))!;
    await tester.runAsync(
      () => env.finished([(22.5, 10), (22.5, 10), (25, 5)]),
    );
    await _open(tester, env, first);
    expect(find.text('RESUME'), findsNothing);
    expect(find.text('DELETE'), findsOneWidget);
    await _dispose(tester, env);
  });

  testWidgets('Resume undoes progression and returns to live (§11.4)', (
    tester,
  ) async {
    final env = await seeded(tester);
    final id = (await tester.runAsync(
      () => env.finished([(20, 10), (20, 10), (22.5, 6)]),
    ))!;
    await _open(tester, env, id);
    await tester.tap(find.text('RESUME'));
    await _settle(tester);
    expect(await tester.runAsync(env.base), 20);
    expect(find.text('live workout'), findsOneWidget);
    await _dispose(tester, env);
  });

  testWidgets('Delete asks for confirmation and undoes progression (§11.8)', (
    tester,
  ) async {
    final env = await seeded(tester);
    final id = (await tester.runAsync(
      () => env.finished([(20, 10), (20, 10), (22.5, 6)]),
    ))!;
    await _open(tester, env, id);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);
    expect(find.text('Delete workout?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(await tester.runAsync(env.base), 22.5);

    await tester.tap(find.text('DELETE'));
    await _settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await _settle(tester);
    expect(await tester.runAsync(env.base), 20);
    expect(find.text('open'), findsOneWidget); // popped back
    await _dispose(tester, env);
  });
}
