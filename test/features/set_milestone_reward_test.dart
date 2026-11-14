import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/core/rest_alerts.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/workout/widgets/reward/reward_burst.dart';
import 'package:fitapp/features/workout/widgets/reward/target_hit_pill.dart';
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

  bool reduceMotion = false;

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      hapticsProvider.overrideWithValue(haptics),
      restAlertsProvider.overrideWithValue(alerts),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: const WorkoutScreen(),
    ),
  );

  void advance(Duration d) => now = now.add(d);
}

Future<void> _pump(WidgetTester tester, _Env env) async {
  await tester.pumpWidget(env.app());
  await _settle(tester);
}

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

Future<void> _logSet(WidgetTester tester, int n) async {
  await tester.tap(find.bySemanticsLabel('Log set $n as prescribed'));
  await _settle(tester);
}

Future<void> _run(WidgetTester tester, int ms) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _pillText = find.text('Target hit · sets 1–2');
final _burst = find.byType(RewardBurst);

double _pillOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(TargetHitPill),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

int _successes(_Env env) =>
    env.haptics.calls.where((c) => c == 'success').length;

void main() {
  testWidgets('logging sets 1 and 2 plays the burst then reveals the pill', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await _logSet(tester, 1);
    expect(_burst, findsNothing);
    expect(_pillText, findsNothing);
    await _logSet(tester, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_burst, findsOneWidget);
    expect(_pillText, findsOneWidget);
    expect(_pillOpacity(tester), 0);

    await _run(tester, 3400);
    expect(_burst, findsNothing);
    expect(_successes(env), 3);
    expect(_pillOpacity(tester), 1);
    expect(
      tester.getSemantics(find.byType(TargetHitPill)).label,
      contains('Target hit for sets 1 and 2'),
    );
    expect(TargetHitPill.semanticsLabel, 'Target hit for sets 1 and 2');
    await _dispose(tester, env);
    handle.dispose();
  });

  testWidgets('missed reps or only set 1 give no reward', (tester) async {
    final env = _Env();
    await tester.runAsync(() async {
      await env.seed();
      await env.workouts.logSet(env.weId, setNo: 1, weight: 20, reps: 10);
      await env.workouts.logSet(env.weId, setNo: 2, weight: 20, reps: 8);
    });
    await _pump(tester, env);
    expect(_burst, findsNothing);
    expect(_pillText, findsNothing);
    await _dispose(tester, env);

    final env2 = _Env();
    await tester.runAsync(env2.seed);
    await _pump(tester, env2);
    await _logSet(tester, 1);
    await _run(tester, 3400);
    expect(_burst, findsNothing);
    expect(_pillText, findsNothing);
    await _dispose(tester, env2);
  });

  testWidgets('already hit on open shows the pill without a burst', (
    tester,
  ) async {
    final env = _Env();
    await tester.runAsync(() async {
      await env.seed();
      await env.workouts.logSet(env.weId, setNo: 1, weight: 20, reps: 10);
      await env.workouts.logSet(env.weId, setNo: 2, weight: 20, reps: 10);
    });
    await _pump(tester, env);
    expect(_burst, findsNothing);
    expect(_pillText, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_pillOpacity(tester), 1);
    await _dispose(tester, env);
  });

  testWidgets('reduced motion skips the burst and shows the pill', (
    tester,
  ) async {
    final env = _Env()..reduceMotion = true;
    await tester.runAsync(env.seed);
    await _pump(tester, env);
    await _logSet(tester, 1);
    await _logSet(tester, 2);
    await tester.pump(const Duration(milliseconds: 50));
    expect(_burst, findsNothing);
    expect(_pillText, findsOneWidget);
    expect(_pillOpacity(tester), 1);
    await _dispose(tester, env);
  });

  testWidgets('the pill appearing does not shift the layout', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    final row = find.byKey(ValueKey('set-${env.weId}-1'));
    final add = find.text('Add Set');
    await _logSet(tester, 1);
    final rowBefore = tester.getTopLeft(row);
    final addBefore = tester.getTopLeft(add);
    await _logSet(tester, 2);
    await _run(tester, 3400);
    expect(_pillOpacity(tester), 1);
    expect(tester.getTopLeft(row), rowBefore);
    expect(tester.getTopLeft(add), addBefore);
    await _dispose(tester, env);
  });

  testWidgets('the burst overlay never blocks taps', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);
    await _logSet(tester, 1);
    await _logSet(tester, 2);
    await _run(tester, 500);
    expect(_burst, findsOneWidget);

    await _logSet(tester, 3);
    final sets = await tester.runAsync(() => env.db.select(env.db.sets).get());
    expect(sets!.length, 3);
    expect(sets.any((s) => s.setNo == 3), isTrue);
    await _run(tester, 3400);
    await _dispose(tester, env);
  });

  testWidgets('clearing set 2 removes the pill', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);
    await _logSet(tester, 1);
    await _logSet(tester, 2);
    await _run(tester, 3400);
    expect(_pillText, findsOneWidget);

    await tester.runAsync(() => env.workouts.clearSet(env.weId, 2));
    await _settle(tester);
    expect(_pillText, findsNothing);
    await _dispose(tester, env);
  });
}
