import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/workout/workout_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _incline = '00000000-0000-4000-8000-000000000002';

class _FakeHaptics implements Haptics {
  final calls = <String>[];
  @override
  void success() => calls.add('success');
  @override
  void tick() => calls.add('tick');
  @override
  void warning() => calls.add('warning');
}

class _ChimeCounter extends NoopRestAlerts {
  int chimes = 0;

  @override
  Future<void> playChime() async => chimes++;
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
    settings = SettingsRepository(db);
  }

  DateTime now = DateTime.utc(2026, 11, 12, 18);
  late final AppDatabase db;
  late final WorkoutRepository workouts;
  late final ExerciseRepository exercises;
  late final SettingsRepository settings;
  final haptics = _FakeHaptics();
  final alerts = _ChimeCounter();
  int get sounds => alerts.chimes;

  late String workoutId;
  late String weId;

  Future<void> seed({int? restSeconds}) async {
    await exercises.savePlan(
      _incline,
      baseWeight: 20,
      targetReps: 10,
      targetSets: 3,
      increment: 2.5,
      restSeconds: restSeconds,
    );
    final w = await workouts.startWorkout();
    workoutId = w.id;
    weId = (await workouts.addExercise(w.id, _incline)).id;
  }

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      hapticsProvider.overrideWithValue(haptics),
      restAlertsProvider.overrideWithValue(alerts),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const WorkoutScreen()),
  );

  void advance(Duration d) => now = now.add(d);
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  await tester.pumpWidget(env.app());
  await _settle(tester);
}

/// Lets drift streams deliver after a write.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

Future<void> _dispose(WidgetTester tester, _Env env) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 10));
  await tester.runAsync(env.db.close);
}

Finder _rowText(String weId, int setNo, String text) => find.descendant(
  of: find.byKey(ValueKey('set-$weId-$setNo')),
  matching: find.text(text),
);

void main() {
  testWidgets('unlogged rows are chalk and show the prescription', (
    tester,
  ) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    expect(_rowText(env.weId, 1, '20'), findsOneWidget);
    expect(_rowText(env.weId, 3, '22.5'), findsOneWidget);
    final weight = tester.widget<Text>(_rowText(env.weId, 1, '20'));
    expect(weight.style!.color, AppColors.textPrimary);
    expect(
      find.bySemanticsLabel(
        RegExp(r'^Set 3, overload: 10 reps at 22\.5 kg\. Opens editor\.$'),
      ),
      findsOneWidget,
    );
    await _dispose(tester, env);
  });

  testWidgets('check box logs the set exactly as prescribed', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await tester.tap(find.bySemanticsLabel('Log set 3 as prescribed'));
    await _settle(tester);

    final sets = await tester.runAsync(() => env.db.select(env.db.sets).get());
    expect(sets!.single.setNo, 3);
    expect(sets.single.weight, 22.5);
    expect(sets.single.reps, 10);
    expect(sets.single.isOverload, isTrue);
    expect(env.haptics.calls, contains('success'));
    final weight = tester.widget<Text>(_rowText(env.weId, 3, '22.5'));
    expect(weight.style!.color, AppColors.textSecondary);
    await _dispose(tester, env);
  });

  testWidgets('missed reps on a working set show in red', (tester) async {
    final env = _Env();
    await tester.runAsync(() async {
      await env.seed();
      await env.workouts.logSet(env.weId, setNo: 2, weight: 20, reps: 8);
    });
    await _pump(tester, env);

    final reps = tester.widget<Text>(_rowText(env.weId, 2, '8 / 10'));
    expect(reps.style!.color, AppColors.danger);
    await _dispose(tester, env);
  });

  testWidgets('rest timer appears in the footer without shifting rows', (
    tester,
  ) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    final row = find.byKey(ValueKey('set-${env.weId}-1'));
    final before = tester.getTopLeft(row);
    await tester.tap(find.bySemanticsLabel('Log set 1 as prescribed'));
    await _settle(tester);

    expect(find.text('1:00'), findsOneWidget);
    expect(tester.getTopLeft(row), before);
    await _dispose(tester, env);
  });

  testWidgets('counts down from stored start, pulses at 0, then overtime', (
    tester,
  ) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await tester.tap(find.bySemanticsLabel('Log set 1 as prescribed'));
    await _settle(tester);
    env.haptics.calls.clear();

    // "Backgrounded" for 40 s: only the wall clock moves.
    env.advance(const Duration(seconds: 40));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:20'), findsOneWidget);

    env.advance(const Duration(seconds: 32));
    await tester.pump(const Duration(seconds: 60));
    await _settle(tester);
    expect(find.text('+0:12'), findsOneWidget);
    expect(env.haptics.calls.where((c) => c == 'warning'), hasLength(1));
    expect(env.sounds, 1);

    // Tapping the pill dismisses it.
    await tester.tap(find.text('+0:12'));
    await _settle(tester);
    expect(find.text('+0:12'), findsNothing);
    await _dispose(tester, env);
  });

  testWidgets('per-exercise rest time overrides the default', (tester) async {
    final env = _Env();
    await tester.runAsync(() => env.seed(restSeconds: 120));
    await _pump(tester, env);
    await tester.tap(find.bySemanticsLabel('Log set 1 as prescribed'));
    await _settle(tester);
    expect(find.text('2:00'), findsOneWidget);
    await _dispose(tester, env);
  });

  testWidgets('changed default rest time applies to the next set', (
    tester,
  ) async {
    final env = _Env();
    await tester.runAsync(() async {
      await env.seed();
      await env.settings.setDefaultRestSeconds(90);
    });
    await _pump(tester, env);
    await tester.tap(find.bySemanticsLabel('Log set 1 as prescribed'));
    await _settle(tester);
    expect(find.text('1:30'), findsOneWidget);
    await _dispose(tester, env);
  });

  group('resume at the current exercise (023 US4)', () {
    String exId(int n) =>
        '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';

    /// Live workout with five planned exercises (3 sets each); [logged]
    /// lists the set numbers logged per exercise. Returns workout exercise
    /// ids in order.
    Future<List<String>> seedFive(_Env env, List<List<int>> logged) async {
      final w = await env.workouts.startWorkout();
      env.workoutId = w.id;
      final ids = <String>[];
      for (var i = 0; i < 5; i++) {
        await env.exercises.savePlan(
          exId(i + 1),
          baseWeight: 20,
          targetReps: 10,
          targetSets: 3,
          increment: 2.5,
        );
        final we = await env.workouts.addExercise(w.id, exId(i + 1));
        ids.add(we.id);
        for (final n in i < logged.length ? logged[i] : const <int>[]) {
          await env.workouts.logSet(we.id, setNo: n, weight: 20, reps: 10);
        }
      }
      return ids;
    }

    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    double cardTop(WidgetTester tester, String weId) =>
        tester.getTopLeft(find.byKey(ValueKey(weId))).dy;

    double bodyTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(SingleChildScrollView)).dy;

    testWidgets('opens at the exercise after the completed ones', (
      tester,
    ) async {
      final env = _Env();
      final ids = await tester.runAsync(
        () => seedFive(env, [
          [1, 2, 3],
          [1, 2, 3],
          [1, 2, 3],
        ]),
      );
      await _pump(tester, env);
      expect(offset(tester), greaterThan(0));
      expect(
        cardTop(tester, ids![3]),
        moreOrLessEquals(bodyTop(tester), epsilon: 1),
      );
      await _dispose(tester, env);
    });

    testWidgets('opens at a partly logged exercise', (tester) async {
      final env = _Env();
      final ids = await tester.runAsync(
        () => seedFive(env, [
          [1, 2, 3],
          [1, 2, 3],
          [1],
        ]),
      );
      await _pump(tester, env);
      expect(
        cardTop(tester, ids![2]),
        moreOrLessEquals(bodyTop(tester), epsilon: 1),
      );
      await _dispose(tester, env);
    });

    testWidgets('nothing logged: opens at the top', (tester) async {
      final env = _Env();
      await tester.runAsync(() => seedFive(env, []));
      await _pump(tester, env);
      expect(offset(tester), 0);
      await _dispose(tester, env);
    });

    testWidgets('logging a set later does not jump the screen', (tester) async {
      final env = _Env();
      await tester.runAsync(() => seedFive(env, []));
      await _pump(tester, env);
      await tester.tap(find.bySemanticsLabel('Log set 1 as prescribed').first);
      await _settle(tester);
      expect(offset(tester), 0);
      await _dispose(tester, env);
    });

    testWidgets('a finished workout opens at the top', (tester) async {
      final env = _Env();
      await tester.runAsync(() async {
        await seedFive(env, [
          [1, 2, 3],
          [1, 2, 3],
          [1, 2, 3],
        ]);
        await env.workouts.finishWorkout(env.workoutId);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(env.db),
            clockProvider.overrideWithValue(() => env.now),
            hapticsProvider.overrideWithValue(env.haptics),
            restAlertsProvider.overrideWithValue(env.alerts),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: WorkoutScreen(workoutId: env.workoutId),
          ),
        ),
      );
      await _settle(tester);
      expect(offset(tester), 0);
      await _dispose(tester, env);
    });
  });
}
