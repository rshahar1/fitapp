import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fitapp/app/theme/app_theme.dart';
import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/data/repositories/exercise_repository.dart';
import 'package:fitapp/data/repositories/settings_repository.dart';
import 'package:fitapp/data/repositories/workout_repository.dart';
import 'package:fitapp/features/workout/rest_timer_controller.dart';
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
  int sounds = 0;

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
      restSoundProvider.overrideWithValue(() => sounds++),
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
  testWidgets('unlogged rows are dimmed and show the prescription', (
    tester,
  ) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    expect(_rowText(env.weId, 1, '20'), findsOneWidget);
    expect(_rowText(env.weId, 3, '22.5'), findsOneWidget);
    final weight = tester.widget<Text>(_rowText(env.weId, 1, '20'));
    expect(weight.style!.color, AppColors.textTertiary);
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
    expect(weight.style!.color, AppColors.textPrimary);
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
}
