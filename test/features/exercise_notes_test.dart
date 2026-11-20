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
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory()));
  }

  late final AppDatabase db;
  late String weId;

  Future<void> seed() async {
    await ExerciseRepository(db).savePlan(
      _incline,
      baseWeight: 20,
      targetReps: 10,
      targetSets: 3,
      increment: 2.5,
    );
    final workouts = WorkoutRepository(db);
    final w = await workouts.startWorkout();
    weId = (await workouts.addExercise(w.id, _incline)).id;
  }

  Future<String?> notes() async =>
      (await db.select(db.workoutExercises).getSingle()).notes;

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      hapticsProvider.overrideWithValue(_NoHaptics()),
      restAlertsProvider.overrideWithValue(const NoopRestAlerts()),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const WorkoutScreen()),
  );
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

void main() {
  testWidgets('typing saves after the debounce', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await tester.enterText(find.byType(TextField), 'Felt strong');
    await tester.pump(const Duration(milliseconds: 700));
    await _settle(tester);

    expect(await tester.runAsync(env.notes), 'Felt strong');
    await _dispose(tester, env);
  });

  testWidgets('Done saves and leaves the field', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Tempo 3-1-1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(await tester.runAsync(env.notes), 'Tempo 3-1-1');
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isFalse,
    );
    await _dispose(tester, env);
  });

  testWidgets('clearing the text stores null', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await tester.enterText(find.byType(TextField), 'Temp');
    await tester.pump(const Duration(milliseconds: 700));
    await _settle(tester);
    expect(await tester.runAsync(env.notes), 'Temp');

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 700));
    await _settle(tester);
    expect(await tester.runAsync(env.notes), isNull);
    await _dispose(tester, env);
  });

  testWidgets('leaving the screen while typing saves the note', (tester) async {
    final env = _Env();
    await tester.runAsync(env.seed);
    await _pump(tester, env);

    await tester.enterText(find.byType(TextField), 'Seat 4');
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }

    expect(await tester.runAsync(env.notes), 'Seat 4');
    await tester.runAsync(env.db.close);
  });
}
